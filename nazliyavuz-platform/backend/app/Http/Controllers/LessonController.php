<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use App\Models\Lesson;
use App\Models\User;

class LessonController extends Controller
{
    /**
     * Get user's lessons
     */
    public function getUserLessons(Request $request): JsonResponse
    {
        Log::info('🚀 LessonController::getUserLessons STARTED', [
            'request_params' => $request->all(),
            'timestamp' => now(),
            'user_agent' => $request->userAgent()
        ]);

        try {
            $user = Auth::user();
            Log::info('👤 User authenticated', ['user_id' => $user?->id, 'role' => $user?->role]);
            
            if (!$user) {
                Log::error('❌ User not authenticated');
                return response()->json([
                    'error' => [
                        'code' => 'UNAUTHORIZED',
                        'message' => 'Kullanıcı kimlik doğrulaması gerekli'
                    ]
                ], 401);
            }
            
            Log::info('🔍 [LESSON_CONTROLLER] User authenticated successfully', [
                'user_id' => $user->id,
                'role' => $user->role
            ]);
            
            $query = Lesson::with(['student', 'teacher']);
            
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
            if ($request->has('start_date') && $request->start_date) {
                $query->where('scheduled_at', '>=', $request->start_date);
            }
            
            if ($request->has('end_date') && $request->end_date) {
                $query->where('scheduled_at', '<=', $request->end_date);
            }
            
            // Sort by scheduled date
            $query->orderBy('scheduled_at', 'desc');
            
            Log::info('🔍 [LESSON_CONTROLLER] Executing query', [
                'sql' => $query->toSql(),
                'bindings' => $query->getBindings()
            ]);
            
            $lessons = $query->paginate(20);
            
            Log::info('✅ Lessons retrieved successfully', [
                'total_lessons' => $lessons->total(),
                'current_page' => $lessons->currentPage(),
                'lessons_count' => count($lessons->items())
            ]);
            
            return response()->json([
                'data' => $lessons->items(),
                'meta' => [
                    'current_page' => $lessons->currentPage(),
                    'last_page' => $lessons->lastPage(),
                    'per_page' => $lessons->perPage(),
                    'total' => $lessons->total()
                ]
            ]);
            
        } catch (\Exception $e) {
            Log::error('❌ Error in getUserLessons', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);
            
            return response()->json([
                'error' => [
                    'code' => 'INTERNAL_ERROR',
                    'message' => 'Dersler yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Update lesson notes
     */
    public function updateNotes(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'lesson_id' => 'required|integer|exists:lessons,id',
            'notes' => 'required|string|max:1000',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        try {
            $user = Auth::user();
            $lesson = Lesson::findOrFail($request->lesson_id);

            // Check if user is the teacher of this lesson
            if ($lesson->teacher_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu ders için not ekleme yetkiniz yok'
                    ]
                ], 403);
            }

            $lesson->update([
                'notes' => $request->notes
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Ders notları başarıyla güncellendi',
                'lesson' => $lesson->fresh()
            ]);

        } catch (\Exception $e) {
            Log::error('Error updating lesson notes: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'LESSON_NOTES_ERROR',
                    'message' => 'Ders notları güncellenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Rate a lesson
     */
    public function rateLesson(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'lesson_id' => 'required|integer|exists:lessons,id',
            'rating' => 'required|integer|min:1|max:5',
            'feedback' => 'nullable|string|max:500',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        try {
            $user = Auth::user();
            $lesson = Lesson::findOrFail($request->lesson_id);

            // Check if user is the student of this lesson
            if ($lesson->student_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu dersi değerlendirme yetkiniz yok'
                    ]
                ], 403);
            }

            // Check if lesson is completed
            if ($lesson->status !== 'completed') {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_STATUS',
                        'message' => 'Sadece tamamlanan dersler değerlendirilebilir'
                    ]
                ], 400);
            }

            // Check if already rated
            if ($lesson->rating !== null) {
                return response()->json([
                    'error' => [
                        'code' => 'ALREADY_RATED',
                        'message' => 'Bu ders zaten değerlendirilmiş'
                    ]
                ], 400);
            }

            $lesson->update([
                'rating' => $request->rating,
                'feedback' => $request->feedback,
                'rated_at' => now()
            ]);

            // Update teacher's average rating
            $this->updateTeacherRating($lesson->teacher_id);

            return response()->json([
                'success' => true,
                'message' => 'Ders başarıyla değerlendirildi',
                'lesson' => $lesson->fresh()
            ]);

        } catch (\Exception $e) {
            Log::error('Error rating lesson: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'LESSON_RATING_ERROR',
                    'message' => 'Ders değerlendirilirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get lesson details
     */
    public function show(int $id): JsonResponse
    {
        try {
            $user = Auth::user();
            $lesson = Lesson::with(['student', 'teacher', 'reservation'])
                ->findOrFail($id);

            // Check if user is either the teacher or student of this lesson
            if ($lesson->teacher_id !== $user->id && $lesson->student_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu ders detaylarını görme yetkiniz yok'
                    ]
                ], 403);
            }

            return response()->json([
                'success' => true,
                'lesson' => $lesson
            ]);

        } catch (\Exception $e) {
            Log::error('Error getting lesson details: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'LESSON_NOT_FOUND',
                    'message' => 'Ders bulunamadı'
                ]
            ], 404);
        }
    }

    /**
     * Start lesson
     */
    public function startLesson(Request $request): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'reservation_id' => 'required|integer|exists:reservations,id',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => $validator->errors()
                    ]
                ], 400);
            }

            $user = Auth::user();
            $reservationId = $request->reservation_id;

            // Find the lesson by reservation
            $lesson = Lesson::where('reservation_id', $reservationId)->first();

            if (!$lesson) {
                return response()->json([
                    'error' => [
                        'code' => 'LESSON_NOT_FOUND',
                        'message' => 'Ders bulunamadı'
                    ]
                ], 404);
            }

            // Check if user is authorized to start this lesson
            if ($lesson->teacher_id !== $user->id && $lesson->student_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu dersi başlatma yetkiniz yok'
                    ]
                ], 403);
            }

            // Check if lesson is scheduled
            if ($lesson->status !== 'scheduled') {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_STATUS',
                        'message' => 'Sadece planlanan dersler başlatılabilir'
                    ]
                ], 400);
            }

            // Update lesson
            $lesson->update([
                'status' => 'in_progress',
                'started_at' => now(),
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Ders başarıyla başlatıldı',
                'lesson' => $lesson->fresh()
            ]);

        } catch (\Exception $e) {
            Log::error('Error starting lesson: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'LESSON_START_ERROR',
                    'message' => 'Ders başlatılırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * End lesson
     */
    public function endLesson(Request $request): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'reservation_id' => 'required|integer|exists:reservations,id',
                'notes' => 'nullable|string|max:1000',
                'rating' => 'nullable|integer|min:1|max:5',
                'feedback' => 'nullable|string|max:500',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => $validator->errors()
                    ]
                ], 400);
            }

            $user = Auth::user();
            $reservationId = $request->reservation_id;

            // Find the lesson by reservation
            $lesson = Lesson::where('reservation_id', $reservationId)->first();

            if (!$lesson) {
                return response()->json([
                    'error' => [
                        'code' => 'LESSON_NOT_FOUND',
                        'message' => 'Ders bulunamadı'
                    ]
                ], 404);
            }

            // Check if user is authorized to end this lesson
            if ($lesson->teacher_id !== $user->id && $lesson->student_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu dersi bitirme yetkiniz yok'
                    ]
                ], 403);
            }

            // Check if lesson is in progress
            if ($lesson->status !== 'in_progress') {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_STATUS',
                        'message' => 'Sadece devam eden dersler bitirilebilir'
                    ]
                ], 400);
            }

            // Calculate duration if started_at exists
            $durationMinutes = null;
            if ($lesson->started_at) {
                $durationMinutes = $lesson->started_at->diffInMinutes(now());
            }

            // Update lesson
            $lesson->update([
                'status' => 'completed',
                'ended_at' => now(),
                'duration_minutes' => $durationMinutes,
                'notes' => $request->notes,
                'rating' => $request->rating,
                'feedback' => $request->feedback,
                'rated_at' => $request->rating ? now() : null,
            ]);

            // Update teacher's average rating if rating provided
            if ($request->rating) {
                $this->updateTeacherRating($lesson->teacher_id);
            }

            return response()->json([
                'success' => true,
                'message' => 'Ders başarıyla tamamlandı',
                'lesson' => $lesson->fresh()
            ]);

        } catch (\Exception $e) {
            Log::error('Error ending lesson: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'LESSON_END_ERROR',
                    'message' => 'Ders bitirilirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Update teacher's average rating
     */
    private function updateTeacherRating(int $teacherId): void
    {
        try {
            $lessons = Lesson::where('teacher_id', $teacherId)
                ->whereNotNull('rating')
                ->get();

            if ($lessons->count() > 0) {
                $averageRating = $lessons->avg('rating');
                $ratingCount = $lessons->count();

                \App\Models\Teacher::where('user_id', $teacherId)
                    ->update([
                        'rating_avg' => round($averageRating, 2),
                        'rating_count' => $ratingCount
                    ]);
            }
        } catch (\Exception $e) {
            Log::error('Error updating teacher rating: ' . $e->getMessage());
        }
    }

    /**
     * Get student's lessons
     */
    public function getStudentLessons(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            
            if ($user->role !== 'student') {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Sadece öğrenciler bu endpoint\'i kullanabilir'
                    ]
                ], 403);
            }

            $query = Lesson::where('student_id', $user->id)
                ->with(['teacher.user:id,name,email,profile_photo_url', 'reservation.category:id,name,slug']);

            // Apply filters
            if ($request->has('status')) {
                $query->where('status', $request->status);
            }
            
            if ($request->has('date_from')) {
                $query->where('start_time', '>=', $request->date_from);
            }
            
            if ($request->has('date_to')) {
                $query->where('start_time', '<=', $request->date_to);
            }

            $lessons = $query->orderBy('start_time', 'desc')->get();

            $formattedLessons = $lessons->map(function ($lesson) {
                return [
                    'id' => $lesson->id,
                    'student_id' => $lesson->student_id,
                    'teacher_id' => $lesson->teacher_id,
                    'reservation_id' => $lesson->reservation_id,
                    'subject' => $lesson->subject ?? ($lesson->reservation->category->name ?? 'Ders'),
                    'start_time' => $lesson->start_time->toISOString(),
                    'end_time' => $lesson->end_time->toISOString(),
                    'status' => $lesson->status,
                    'notes' => $lesson->notes,
                    'teacher_notes' => $lesson->teacher_notes,
                    'created_at' => $lesson->created_at->toISOString(),
                    'updated_at' => $lesson->updated_at->toISOString(),
                    'teacher' => [
                        'id' => $lesson->teacher->user->id,
                        'name' => $lesson->teacher->user->name,
                        'email' => $lesson->teacher->user->email,
                        'profile_photo_url' => $lesson->teacher->user->profile_photo_url,
                    ],
                    'reservation' => $lesson->reservation ? [
                        'id' => $lesson->reservation->id,
                        'category' => [
                            'id' => $lesson->reservation->category->id,
                            'name' => $lesson->reservation->category->name,
                            'slug' => $lesson->reservation->category->slug,
                        ],
                    ] : null,
                ];
            });

            return response()->json([
                'success' => true,
                'lessons' => $formattedLessons,
                'total' => $formattedLessons->count()
            ]);

        } catch (\Exception $e) {
            Log::error('Error getting student lessons: ' . $e->getMessage());
            return response()->json([
                'error' => [
                    'code' => 'STUDENT_LESSONS_ERROR',
                    'message' => 'Öğrenci dersleri yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }
}
