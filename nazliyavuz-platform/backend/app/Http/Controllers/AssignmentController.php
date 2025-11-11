<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Cache;
use App\Models\Assignment;
use App\Models\User;
use App\Models\Reservation;
use Carbon\Carbon;
use App\Services\NotificationService;
use App\Rules\ValidGrade;

class AssignmentController extends Controller
{
    protected NotificationService $notificationService;

    public function __construct(NotificationService $notificationService)
    {
        $this->notificationService = $notificationService;
    }

    /**
     * Get assignments for authenticated user
     */
    public function index(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            
            // Create cache key based on user and filters
            $cacheKey = 'assignments_' . $user->id . '_' . md5(json_encode($request->all()));
            
            // Try to get from cache first
            $assignments = Cache::remember($cacheKey, 300, function () use ($user, $request) {
                $query = Assignment::query();
            
            // Filter by user role
            if ($user->role === 'teacher') {
                $query->where('teacher_id', $user->id);
            } else {
                $query->where('student_id', $user->id);
            }
            
            // Apply status filter
            if ($request->has('status') && $request->status) {
                $query->where('status', $request->status);
            }
            
            // Apply date range filter
            if ($request->has('from_date') && $request->from_date) {
                $query->whereDate('due_date', '>=', $request->from_date);
            }
            
            if ($request->has('to_date') && $request->to_date) {
                $query->whereDate('due_date', '<=', $request->to_date);
            }
            
            // Load relationships
            $query->with([
                'teacher:id,name,email',
                'student:id,name,email',
                'reservation'
            ]);
            
            // Order by due date
            $query->orderBy('due_date', 'asc');
            
                return $query->paginate($request->get('per_page', 20));
            });
            
            // Format assignments data
            $formattedAssignments = $assignments->getCollection()->map(function ($assignment) {
                return [
                    'id' => $assignment->id,
                    'title' => $assignment->title,
                    'description' => $assignment->description,
                    'due_date' => $assignment->due_date->toISOString(),
                    'difficulty' => $assignment->difficulty,
                    'status' => $assignment->status,
                    'grade' => $assignment->grade,
                    'feedback' => $assignment->feedback,
                    'submission_notes' => $assignment->submission_notes,
                    'submission_file_name' => $assignment->submission_file_name,
                    'submitted_at' => $assignment->submitted_at?->toISOString(),
                    'graded_at' => $assignment->graded_at?->toISOString(),
                    'teacher_name' => $assignment->teacher?->name,
                    'student_name' => $assignment->student?->name,
                    'created_at' => $assignment->created_at->toISOString(),
                    'updated_at' => $assignment->updated_at->toISOString(),
                ];
            });
            
            return response()->json([
                'success' => true,
                'assignments' => $formattedAssignments,
                'pagination' => [
                    'current_page' => $assignments->currentPage(),
                    'last_page' => $assignments->lastPage(),
                    'per_page' => $assignments->perPage(),
                    'total' => $assignments->total(),
                ]
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error getting assignments: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'ASSIGNMENTS_FETCH_ERROR',
                    'message' => 'Ödevler yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Create new assignment (teacher only)
     */
    public function store(Request $request): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'student_id' => 'required|exists:users,id',
                'title' => 'required|string|max:255',
                'description' => 'required|string',
                'due_date' => 'required|date|after:now',
                'difficulty' => 'required|in:easy,medium,hard',
                'reservation_id' => 'nullable|exists:reservations,id',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => true,
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'Geçersiz veri',
                    'errors' => $validator->errors(),
                    'timestamp' => now()->toISOString(),
                    'path' => $request->path(),
                ], 422);
            }

            $user = Auth::user();

            // Check if user is a teacher
            if ($user->role !== 'teacher') {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Sadece öğretmenler ödev oluşturabilir'
                    ]
                ], 403);
            }

            // Check if student exists and is a student
            $student = User::where('id', $request->student_id)
                ->where('role', 'student')
                ->first();

            if (!$student) {
                return response()->json([
                    'error' => [
                        'code' => 'STUDENT_NOT_FOUND',
                        'message' => 'Öğrenci bulunamadı'
                    ]
                ], 404);
            }

            // If reservation_id is provided, verify the teacher has taught this student
            if ($request->reservation_id) {
                $reservation = Reservation::where('id', $request->reservation_id)
                    ->where('teacher_id', $user->id)
                    ->where('student_id', $request->student_id)
                    ->where('status', 'completed')
                    ->first();

                if (!$reservation) {
                    return response()->json([
                        'error' => [
                            'code' => 'INVALID_RESERVATION',
                            'message' => 'Bu öğrenci ile tamamlanmış bir dersiniz bulunmuyor'
                        ]
                    ], 400);
                }
            } else {
                // If no reservation_id, check if teacher has any completed lessons with this student
                $hasCompletedLesson = Reservation::where('teacher_id', $user->id)
                    ->where('student_id', $request->student_id)
                    ->where('status', 'completed')
                    ->exists();

                if (!$hasCompletedLesson) {
                    return response()->json([
                        'error' => [
                            'code' => 'NO_COMPLETED_LESSONS',
                            'message' => 'Bu öğrenci ile tamamlanmış bir dersiniz bulunmuyor. Önce ders tamamlamalısınız.'
                        ]
                    ], 400);
                }
            }

            // Create assignment
            $assignment = Assignment::create([
                'teacher_id' => $user->id,
                'student_id' => $request->student_id,
                'reservation_id' => $request->reservation_id,
                'title' => $request->title,
                'description' => $request->description,
                'due_date' => $request->due_date,
                'difficulty' => $request->difficulty,
                'status' => 'pending',
            ]);

            // Load relationships for response
            $assignment->load(['teacher:id,name', 'student:id,name']);

            // ✅ Send notification to student
            try {
                $this->notificationService->sendAssignmentCreatedNotification(
                    $student,
                    $user,
                    $assignment
                );
                Log::info('✅ Assignment created notification sent', [
                    'assignment_id' => $assignment->id,
                    'student_id' => $student->id
                ]);
            } catch (\Exception $e) {
                Log::warning('Failed to send assignment notification: ' . $e->getMessage());
            }

            return response()->json([
                'success' => true,
                'message' => 'Ödev başarıyla oluşturuldu',
                'assignment' => [
                    'id' => $assignment->id,
                    'title' => $assignment->title,
                    'description' => $assignment->description,
                    'due_date' => $assignment->due_date->toISOString(),
                    'difficulty' => $assignment->difficulty,
                    'status' => $assignment->status,
                    'teacher_name' => $assignment->teacher?->name,
                    'student_name' => $assignment->student?->name,
                ]
            ], 201);

        } catch (\Exception $e) {
            Log::error('Error creating assignment: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'ASSIGNMENT_CREATE_ERROR',
                    'message' => 'Ödev oluşturulurken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Submit assignment (student only)
     */
    public function submit(Request $request, Assignment $assignment): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'submission_notes' => 'nullable|string|max:1000',
                'file' => 'nullable|file|max:10240|mimes:pdf,doc,docx,txt,jpg,jpeg,png,zip,rar', // 10MB max, allowed types
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => true,
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'Geçersiz veri',
                    'errors' => $validator->errors(),
                    'timestamp' => now()->toISOString(),
                    'path' => $request->path(),
                ], 422);
            }

            $user = Auth::user();

            // Check if user is the student for this assignment
            if ($assignment->student_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu ödevi teslim etme yetkiniz yok'
                    ]
                ], 403);
            }

            // Check if assignment is still pending
            if ($assignment->status !== 'pending') {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_STATUS',
                        'message' => 'Bu ödev zaten teslim edilmiş'
                    ]
                ], 400);
            }

            $submissionData = [
                'status' => 'submitted',
                'submission_notes' => $request->submission_notes,
                'submitted_at' => now(),
            ];

            // Handle file upload with enhanced security
            if ($request->hasFile('file')) {
                $file = $request->file('file');
                
                // Sanitize filename
                $originalName = $file->getClientOriginalName();
                $extension = $file->getClientOriginalExtension();
                $safeFileName = preg_replace('/[^A-Za-z0-9_\-\.]/', '_', pathinfo($originalName, PATHINFO_FILENAME));
                $safeFileName = substr($safeFileName, 0, 100); // Limit length
                
                // Generate unique filename
                $fileName = time() . '_' . uniqid() . '_' . $safeFileName . '.' . $extension;
                
                // Store file
                $filePath = $file->storeAs('assignments', $fileName, 'public');
                
                // Additional security: Check actual MIME type
                $mimeType = $file->getMimeType();
                $allowedMimes = [
                    'application/pdf',
                    'application/msword',
                    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                    'text/plain',
                    'image/jpeg',
                    'image/png',
                    'application/zip',
                    'application/x-rar-compressed',
                ];
                
                if (!in_array($mimeType, $allowedMimes)) {
                    return response()->json([
                        'error' => [
                            'code' => 'INVALID_FILE_TYPE',
                            'message' => 'Geçersiz dosya tipi. İzin verilen: PDF, DOC, DOCX, TXT, JPG, PNG, ZIP, RAR'
                        ]
                    ], 400);
                }
                
                $submissionData['submission_file_path'] = $filePath;
                $submissionData['submission_file_name'] = $originalName;
                
                Log::info('Assignment file uploaded', [
                    'assignment_id' => $assignment->id,
                    'file_name' => $originalName,
                    'file_size' => $file->getSize(),
                    'mime_type' => $mimeType,
                ]);
            }

            $assignment->update($submissionData);

            // ✅ Send notification to teacher
            try {
                $teacher = User::find($assignment->teacher_id);
                if ($teacher) {
                    $this->notificationService->sendAssignmentSubmittedNotification(
                        $teacher,
                        $user,  // student
                        $assignment
                    );
                    Log::info('✅ Assignment submitted notification sent to teacher', [
                        'assignment_id' => $assignment->id,
                        'teacher_id' => $teacher->id,
                        'student_id' => $user->id
                    ]);
                }
            } catch (\Exception $e) {
                Log::warning('Failed to send assignment submission notification: ' . $e->getMessage());
            }

            return response()->json([
                'success' => true,
                'message' => 'Ödev başarıyla teslim edildi'
            ]);

        } catch (\Exception $e) {
            Log::error('Error submitting assignment: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'ASSIGNMENT_SUBMIT_ERROR',
                    'message' => 'Ödev teslim edilirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Grade assignment (teacher only)
     */
    public function grade(Request $request, Assignment $assignment): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'grade' => ['required', 'string', new ValidGrade()],
                'feedback' => 'nullable|string|max:1000',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => true,
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'Geçersiz veri',
                    'errors' => $validator->errors(),
                    'timestamp' => now()->toISOString(),
                    'path' => $request->path(),
                ], 422);
            }

            $user = Auth::user();

            // Check if user is the teacher for this assignment
            if ($assignment->teacher_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu ödevi notlandırma yetkiniz yok'
                    ]
                ], 403);
            }

            // Check if assignment is submitted
            if ($assignment->status !== 'submitted') {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_STATUS',
                        'message' => 'Sadece teslim edilmiş ödevler notlandırılabilir'
                    ]
                ], 400);
            }

            $assignment->update([
                'status' => 'graded',
                'grade' => $request->grade,
                'feedback' => $request->feedback,
                'graded_at' => now(),
            ]);

            // ✅ Send notification to student
            try {
                $student = User::find($assignment->student_id);
                if ($student) {
                    $this->notificationService->sendAssignmentGradedNotification(
                        $student,
                        $assignment,
                        $request->grade,
                        $request->feedback
                    );
                    Log::info('✅ Assignment graded notification sent', [
                        'assignment_id' => $assignment->id,
                        'student_id' => $student->id,
                        'grade' => $request->grade
                    ]);
                }
            } catch (\Exception $e) {
                Log::warning('Failed to send assignment graded notification: ' . $e->getMessage());
            }

            return response()->json([
                'success' => true,
                'message' => 'Ödev başarıyla notlandırıldı'
            ]);

        } catch (\Exception $e) {
            Log::error('Error grading assignment: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'ASSIGNMENT_GRADE_ERROR',
                    'message' => 'Ödev notlandırılırken bir hata oluştu'
                ]
            ], 500);
        }
    }


    /**
     * Get teacher assignments
     */
    public function getTeacherAssignments(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();

            if ($user->role !== 'teacher') {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Sadece öğretmenler bu endpoint\'i kullanabilir'
                    ]
                ], 403);
            }

            $assignments = Assignment::where('teacher_id', $user->id)
                ->with(['student:id,name', 'reservation'])
                ->orderBy('due_date', 'asc')
                ->get();

            return response()->json([
                'success' => true,
                'assignments' => $assignments
            ]);

        } catch (\Exception $e) {
            Log::error('Error getting teacher assignments: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'TEACHER_ASSIGNMENTS_ERROR',
                    'message' => 'Öğretmen ödevleri yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get assignments for a specific student
     */
    public function getStudentAssignments(Request $request): JsonResponse
    {
        try {
            $studentId = Auth::id();
            $status = $request->query('status');
            
            $query = Assignment::where('student_id', $studentId)
                ->with(['teacher:id,name,email,profile_photo_url', 'student:id,name,email,profile_photo_url']);
            
            if ($status) {
                $query->where('status', $status);
            }
            
            $assignments = $query->orderBy('created_at', 'desc')->get();
            
            // Format assignments data
            $formattedAssignments = $assignments->map(function ($assignment) {
                return [
                    'id' => $assignment->id,
                    'title' => $assignment->title,
                    'description' => $assignment->description,
                    'due_date' => $assignment->due_date->toISOString(),
                    'difficulty' => $assignment->difficulty,
                    'status' => $assignment->status,
                    'grade' => $assignment->grade,
                    'feedback' => $assignment->feedback,
                    'submission_notes' => $assignment->submission_notes,
                    'submission_file_name' => $assignment->submission_file_name,
                    'submitted_at' => $assignment->submitted_at?->toISOString(),
                    'graded_at' => $assignment->graded_at?->toISOString(),
                    'teacher_name' => $assignment->teacher?->name,
                    'student_name' => $assignment->student?->name,
                    'created_at' => $assignment->created_at->toISOString(),
                    'updated_at' => $assignment->updated_at->toISOString(),
                ];
            });
            
            return response()->json([
                'success' => true,
                'assignments' => $formattedAssignments,
                'total' => $formattedAssignments->count()
            ]);
        } catch (\Exception $e) {
            Log::error('Error getting student assignments: ' . $e->getMessage());
            
            return response()->json([
                'success' => false,
                'message' => 'Ödevler yüklenirken hata oluştu',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    /**
     * Update assignment (teacher only)
     */
    public function update(Request $request, Assignment $assignment): JsonResponse
    {
        try {
            $user = Auth::user();

            // Check if user is the teacher for this assignment
            if ($assignment->teacher_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu ödevi düzenleme yetkiniz yok'
                    ]
                ], 403);
            }

            // Check if assignment can be updated (only pending assignments)
            if ($assignment->status !== 'pending') {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_STATUS',
                        'message' => 'Sadece henüz teslim edilmemiş ödevler düzenlenebilir'
                    ]
                ], 400);
            }

            $validator = Validator::make($request->all(), [
                'title' => 'sometimes|string|max:255',
                'description' => 'sometimes|string',
                'due_date' => 'sometimes|date|after:now',
                'difficulty' => 'sometimes|in:easy,medium,hard',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => true,
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'Geçersiz veri',
                    'errors' => $validator->errors(),
                ], 422);
            }

            // Update only provided fields
            $assignment->update($request->only([
                'title',
                'description',
                'due_date',
                'difficulty',
            ]));

            // If due date is extended and assignment was overdue, reset to pending
            if ($request->has('due_date') && $assignment->status === 'overdue') {
                $newDueDate = Carbon::parse($request->due_date);
                if ($newDueDate->isFuture()) {
                    $assignment->update(['status' => 'pending']);
                }
            }

            // Send notification to student about changes
            try {
                $student = User::find($assignment->student_id);
                if ($student) {
                    $this->notificationService->sendCompleteNotification(
                        $student,
                        'assignment',
                        '📝 Ödev Güncellendi',
                        "'{$assignment->title}' ödevi güncellendi. Detayları kontrol edin.",
                        ['assignment_id' => $assignment->id],
                        "/assignments/{$assignment->id}",
                        "Ödevi Görüntüle"
                    );
                }
            } catch (\Exception $e) {
                Log::warning('Failed to send assignment update notification: ' . $e->getMessage());
            }

            return response()->json([
                'success' => true,
                'message' => 'Ödev başarıyla güncellendi',
                'assignment' => [
                    'id' => $assignment->id,
                    'title' => $assignment->title,
                    'description' => $assignment->description,
                    'due_date' => $assignment->due_date->toISOString(),
                    'difficulty' => $assignment->difficulty,
                    'status' => $assignment->status,
                ]
            ]);

        } catch (\Exception $e) {
            Log::error('Error updating assignment: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'ASSIGNMENT_UPDATE_ERROR',
                    'message' => 'Ödev güncellenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Delete assignment (teacher only)
     */
    public function destroy(Assignment $assignment): JsonResponse
    {
        try {
            $user = Auth::user();

            // Check if user is the teacher for this assignment
            if ($assignment->teacher_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu ödevi silme yetkiniz yok'
                    ]
                ], 403);
            }

            // Check if assignment can be deleted (only pending assignments)
            if ($assignment->status !== 'pending') {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_STATUS',
                        'message' => 'Sadece henüz teslim edilmemiş ödevler silinebilir'
                    ]
                ], 400);
            }

            $student = User::find($assignment->student_id);
            $assignmentTitle = $assignment->title;
            $assignmentId = $assignment->id;

            // Delete the assignment
            $assignment->delete();

            // Send notification to student
            try {
                if ($student) {
                    $this->notificationService->sendCompleteNotification(
                        $student,
                        'assignment',
                        '🗑️ Ödev İptal Edildi',
                        "'{$assignmentTitle}' ödevi iptal edildi.",
                        ['assignment_id' => $assignmentId],
                        "/assignments",
                        "Ödevleri Görüntüle"
                    );
                }
            } catch (\Exception $e) {
                Log::warning('Failed to send assignment deletion notification: ' . $e->getMessage());
            }

            Log::info('Assignment deleted', [
                'assignment_id' => $assignmentId,
                'teacher_id' => $user->id,
                'student_id' => $student->id ?? null,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Ödev başarıyla silindi'
            ]);

        } catch (\Exception $e) {
            Log::error('Error deleting assignment: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'ASSIGNMENT_DELETE_ERROR',
                    'message' => 'Ödev silinirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Download assignment submission file
     */
    public function downloadSubmission(Assignment $assignment): mixed
    {
        try {
            $user = Auth::user();

            // Check authorization (teacher or student)
            if ($assignment->teacher_id !== $user->id && $assignment->student_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu dosyayı indirme yetkiniz yok'
                    ]
                ], 403);
            }

            // Check if file exists
            if (!$assignment->submission_file_path) {
                return response()->json([
                    'error' => [
                        'code' => 'FILE_NOT_FOUND',
                        'message' => 'Ödev dosyası bulunamadı'
                    ]
                ], 404);
            }

            // Check if file exists in storage
            if (!Storage::disk('public')->exists($assignment->submission_file_path)) {
                Log::error('Assignment file not found in storage', [
                    'assignment_id' => $assignment->id,
                    'file_path' => $assignment->submission_file_path,
                ]);

                return response()->json([
                    'error' => [
                        'code' => 'FILE_NOT_FOUND',
                        'message' => 'Dosya sistemde bulunamadı'
                    ]
                ], 404);
            }

            Log::info('Assignment file downloaded', [
                'assignment_id' => $assignment->id,
                'user_id' => $user->id,
                'file_name' => $assignment->submission_file_name,
            ]);

            // Return file download
            return Storage::disk('public')->download(
                $assignment->submission_file_path,
                $assignment->submission_file_name
            );

        } catch (\Exception $e) {
            Log::error('Error downloading assignment file: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'DOWNLOAD_ERROR',
                    'message' => 'Dosya indirilirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Request resubmission (teacher only)
     */
    public function requestResubmission(Request $request, Assignment $assignment): JsonResponse
    {
        try {
            $user = Auth::user();

            // Check if user is the teacher for this assignment
            if ($assignment->teacher_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu işlemi yapma yetkiniz yok'
                    ]
                ], 403);
            }

            // Check if assignment is submitted or graded
            if (!in_array($assignment->status, ['submitted', 'graded'])) {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_STATUS',
                        'message' => 'Sadece teslim edilmiş veya notlandırılmış ödevler için tekrar teslim isteyebilirsiniz'
                    ]
                ], 400);
            }

            $validator = Validator::make($request->all(), [
                'feedback' => 'required|string|max:1000',
                'new_due_date' => 'nullable|date|after:now',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => true,
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'Geçersiz veri',
                    'errors' => $validator->errors(),
                ], 422);
            }

            $oldFeedback = $assignment->feedback;
            $newFeedback = $request->feedback . "\n\n[Tekrar Teslim İstendi: " . now()->format('d.m.Y H:i') . "]";
            
            if ($oldFeedback) {
                $newFeedback = $oldFeedback . "\n\n---\n\n" . $newFeedback;
            }

            // Reset assignment to pending
            $updateData = [
                'status' => 'pending',
                'grade' => null,
                'feedback' => $newFeedback,
                'graded_at' => null,
            ];

            // Update due date if provided
            if ($request->has('new_due_date')) {
                $updateData['due_date'] = $request->new_due_date;
            }

            $assignment->update($updateData);

            // Send notification to student
            try {
                $student = User::find($assignment->student_id);
                if ($student) {
                    $this->notificationService->sendCompleteNotification(
                        $student,
                        'assignment',
                        '🔄 Tekrar Teslim İstendi',
                        "'{$assignment->title}' ödevi için tekrar teslim istendi. Geri bildirimi kontrol edin.",
                        [
                            'assignment_id' => $assignment->id,
                            'feedback' => $request->feedback,
                        ],
                        "/assignments/{$assignment->id}",
                        "Ödevi Görüntüle",
                        true // Force push
                    );
                }
            } catch (\Exception $e) {
                Log::warning('Failed to send resubmission notification: ' . $e->getMessage());
            }

            Log::info('Resubmission requested', [
                'assignment_id' => $assignment->id,
                'teacher_id' => $user->id,
                'student_id' => $assignment->student_id,
                'new_due_date' => $request->new_due_date ?? 'unchanged',
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Tekrar teslim istendi. Öğrenciye bildirim gönderildi.'
            ]);

        } catch (\Exception $e) {
            Log::error('Error requesting resubmission: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'RESUBMISSION_REQUEST_ERROR',
                    'message' => 'İşlem sırasında bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Extend deadline (teacher only)
     */
    public function extendDeadline(Request $request, Assignment $assignment): JsonResponse
    {
        try {
            $user = Auth::user();

            // Check if user is the teacher for this assignment
            if ($assignment->teacher_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu işlemi yapma yetkiniz yok'
                    ]
                ], 403);
            }

            $validator = Validator::make($request->all(), [
                'new_due_date' => 'required|date|after:now',
                'reason' => 'nullable|string|max:500',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => true,
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'Geçersiz veri',
                    'errors' => $validator->errors(),
                ], 422);
            }

            $oldDueDate = $assignment->due_date->copy();
            $newDueDate = Carbon::parse($request->new_due_date);

            // Update due date
            $assignment->update([
                'due_date' => $newDueDate,
                // If assignment was overdue, reset to pending
                'status' => $assignment->status === 'overdue' ? 'pending' : $assignment->status,
            ]);

            // Add note to feedback
            $extensionNote = "\n\n[Son Tarih Uzatıldı: " . $oldDueDate->format('d.m.Y H:i') 
                           . " → " . $newDueDate->format('d.m.Y H:i') . "]";
            
            if ($request->reason) {
                $extensionNote .= "\nSebep: " . $request->reason;
            }

            $assignment->update([
                'feedback' => ($assignment->feedback ?? '') . $extensionNote
            ]);

            // Send notification to student
            try {
                $student = User::find($assignment->student_id);
                if ($student) {
                    $this->notificationService->sendCompleteNotification(
                        $student,
                        'assignment',
                        '⏰ Son Tarih Uzatıldı',
                        "'{$assignment->title}' ödevi için son tarih uzatıldı. Yeni son tarih: " . $newDueDate->format('d.m.Y H:i'),
                        [
                            'assignment_id' => $assignment->id,
                            'old_due_date' => $oldDueDate->toISOString(),
                            'new_due_date' => $newDueDate->toISOString(),
                        ],
                        "/assignments/{$assignment->id}",
                        "Ödevi Görüntüle"
                    );
                }
            } catch (\Exception $e) {
                Log::warning('Failed to send deadline extension notification: ' . $e->getMessage());
            }

            Log::info('Deadline extended', [
                'assignment_id' => $assignment->id,
                'teacher_id' => $user->id,
                'old_due_date' => $oldDueDate->toDateTimeString(),
                'new_due_date' => $newDueDate->toDateTimeString(),
                'reason' => $request->reason,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Son tarih başarıyla uzatıldı',
                'assignment' => [
                    'id' => $assignment->id,
                    'old_due_date' => $oldDueDate->toISOString(),
                    'new_due_date' => $newDueDate->toISOString(),
                ]
            ]);

        } catch (\Exception $e) {
            Log::error('Error extending deadline: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'DEADLINE_EXTENSION_ERROR',
                    'message' => 'İşlem sırasında bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get assignment statistics for student
     */
    public function getStudentAssignmentStatistics(): JsonResponse
    {
        try {
            $studentId = Auth::id();
            
            $assignments = Assignment::where('student_id', $studentId)->get();
            
            $total = $assignments->count();
            $pending = $assignments->where('status', 'pending')->count();
            $submitted = $assignments->where('status', 'submitted')->count();
            $graded = $assignments->where('status', 'graded')->count();
            $overdue = $assignments->where('status', 'overdue')->count();
            
            // Calculate completion rate
            $completionRate = $total > 0 
                ? round((($submitted + $graded) / $total) * 100, 1) 
                : 0;
            
            // Calculate on-time submission rate
            $submittedAssignments = $assignments->whereIn('status', ['submitted', 'graded']);
            $onTimeSubmissions = $submittedAssignments->filter(function ($assignment) {
                return $assignment->submitted_at && $assignment->submitted_at->lte($assignment->due_date);
            })->count();
            
            $onTimeRate = $submittedAssignments->count() > 0
                ? round(($onTimeSubmissions / $submittedAssignments->count()) * 100, 1)
                : 0;
            
            // Calculate average grade (numeric)
            $gradedAssignments = $assignments->where('status', 'graded')->whereNotNull('grade');
            $averageGradeNumeric = null;
            $averageGradeLetter = null;
            
            if ($gradedAssignments->count() > 0) {
                $gradeSum = 0;
                $gradeCount = 0;
                
                foreach ($gradedAssignments as $assignment) {
                    $numericGrade = \App\Rules\ValidGrade::gradeToNumeric($assignment->grade);
                    if ($numericGrade !== null) {
                        $gradeSum += $numericGrade;
                        $gradeCount++;
                    }
                }
                
                if ($gradeCount > 0) {
                    $averageGradeNumeric = round($gradeSum / $gradeCount, 2);
                    $averageGradeLetter = \App\Rules\ValidGrade::numericToGrade($averageGradeNumeric);
                }
            }
            
            // Difficulty breakdown
            $difficultyBreakdown = [
                'easy' => [
                    'total' => $assignments->where('difficulty', 'easy')->count(),
                    'completed' => $assignments->where('difficulty', 'easy')->whereIn('status', ['submitted', 'graded'])->count(),
                    'average_grade' => $this->calculateAverageGradeForDifficulty($assignments, 'easy'),
                ],
                'medium' => [
                    'total' => $assignments->where('difficulty', 'medium')->count(),
                    'completed' => $assignments->where('difficulty', 'medium')->whereIn('status', ['submitted', 'graded'])->count(),
                    'average_grade' => $this->calculateAverageGradeForDifficulty($assignments, 'medium'),
                ],
                'hard' => [
                    'total' => $assignments->where('difficulty', 'hard')->count(),
                    'completed' => $assignments->where('difficulty', 'hard')->whereIn('status', ['submitted', 'graded'])->count(),
                    'average_grade' => $this->calculateAverageGradeForDifficulty($assignments, 'hard'),
                ],
            ];
            
            // Monthly trend (last 6 months)
            $monthlyTrend = [];
            for ($i = 5; $i >= 0; $i--) {
                $month = now()->subMonths($i);
                $monthKey = $month->format('Y-m');
                
                $monthAssignments = $assignments->filter(function ($assignment) use ($month) {
                    return $assignment->created_at->format('Y-m') === $month->format('Y-m');
                });
                
                $monthGraded = $monthAssignments->where('status', 'graded');
                
                $monthlyTrend[$monthKey] = [
                    'month' => $month->format('F Y'),
                    'total' => $monthAssignments->count(),
                    'completed' => $monthAssignments->whereIn('status', ['submitted', 'graded'])->count(),
                    'average_grade' => $this->calculateAverageGrade($monthGraded),
                ];
            }
            
            return response()->json([
                'success' => true,
                'statistics' => [
                    'total' => $total,
                    'pending' => $pending,
                    'submitted' => $submitted,
                    'graded' => $graded,
                    'overdue' => $overdue,
                    'completion_rate' => $completionRate,
                    'on_time_submission_rate' => $onTimeRate,
                    'average_grade_numeric' => $averageGradeNumeric,
                    'average_grade_letter' => $averageGradeLetter,
                    'difficulty_breakdown' => $difficultyBreakdown,
                    'monthly_trend' => $monthlyTrend,
                ]
            ]);
        } catch (\Exception $e) {
            Log::error('Error getting student assignment statistics: ' . $e->getMessage());
            
            return response()->json([
                'success' => false,
                'message' => 'İstatistikler yüklenirken hata oluştu',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    /**
     * Calculate average grade for specific difficulty
     */
    private function calculateAverageGradeForDifficulty($assignments, string $difficulty): ?string
    {
        $filtered = $assignments->where('difficulty', $difficulty)
                                ->where('status', 'graded')
                                ->whereNotNull('grade');
        
        return $this->calculateAverageGrade($filtered);
    }

    /**
     * Calculate average grade from collection
     */
    private function calculateAverageGrade($gradedAssignments): ?string
    {
        if ($gradedAssignments->count() === 0) {
            return null;
        }
        
        $gradeSum = 0;
        $gradeCount = 0;
        
        foreach ($gradedAssignments as $assignment) {
            $numericGrade = \App\Rules\ValidGrade::gradeToNumeric($assignment->grade);
            if ($numericGrade !== null) {
                $gradeSum += $numericGrade;
                $gradeCount++;
            }
        }
        
        if ($gradeCount === 0) {
            return null;
        }
        
        $average = $gradeSum / $gradeCount;
        return \App\Rules\ValidGrade::numericToGrade($average);
    }
}