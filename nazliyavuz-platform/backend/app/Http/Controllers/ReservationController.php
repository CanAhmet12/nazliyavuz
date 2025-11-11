<?php

namespace App\Http\Controllers;

use App\Services\MailService;
use App\Services\CacheService;
use App\Services\NotificationService;
use App\Services\ReservationConflictService;
use App\Models\Teacher;
use App\Models\Category;
use App\Models\Reservation;
use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Carbon\Carbon;

class ReservationController extends Controller
{
    protected MailService $mailService;
    protected CacheService $cacheService;
    protected NotificationService $notificationService;
    protected ReservationConflictService $conflictService;

    public function __construct(
        MailService $mailService, 
        CacheService $cacheService,
        NotificationService $notificationService,
        ReservationConflictService $conflictService
    ) {
        $this->mailService = $mailService;
        $this->cacheService = $cacheService;
        $this->notificationService = $notificationService;
        $this->conflictService = $conflictService;
    }

    /**
     * Get user's reservations
     */
    public function index(Request $request): JsonResponse
    {
        Log::info('🚀 ReservationController::index STARTED', [
            'request_params' => $request->all(),
            'timestamp' => now(),
            'user_agent' => $request->userAgent()
        ]);

        try {
            $user = Auth::user();
            Log::info('👤 User authenticated', ['user_id' => $user?->id, 'role' => $user?->role]);
            
            // Prepare cache filters
            $filters = [
                'status' => $request->get('status'),
                'from_date' => $request->get('from_date'),
                'to_date' => $request->get('to_date'),
            ];
            
            // Try to get from cache first
            $cacheKey = 'reservations:' . $user->role . ':' . $user->id . ':' . md5(serialize($filters));
            $cachedReservations = cache()->get($cacheKey);
            
            if ($cachedReservations) {
                Log::info('📦 Cache HIT for reservations', ['user_id' => $user->id, 'role' => $user->role]);
                return response()->json([
                    'success' => true,
                    'reservations' => $cachedReservations,
                    'cached' => true
                ]);
            }
            
            $query = Reservation::query();
            
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
                $query->whereDate('proposed_datetime', '>=', $request->from_date);
            }
            
            if ($request->has('to_date') && $request->to_date) {
                $query->whereDate('proposed_datetime', '<=', $request->to_date);
            }
            
            // Load relationships
            $query->with([
                'teacher:id,name,email,profile_photo_url',
                'student:id,name,email,profile_photo_url',
                'category:id,name,slug'
            ]);
            
            // Order by most recent first
            $query->orderBy('proposed_datetime', 'desc');
            
            // Get all reservations without pagination
            $allReservations = $query->get();
            
            Log::info('🔍 [RESERVATION_CONTROLLER] Query results', [
                'total_reservations' => $allReservations->count()
            ]);
            
            // Remove duplicates using collection unique method (more efficient)
            $uniqueReservations = $allReservations->unique('id');
            
            Log::info('🔍 [RESERVATION_CONTROLLER] After duplicate removal', [
                'original_count' => $allReservations->count(),
                'unique_count' => $uniqueReservations->count(),
                'removed_duplicates' => $allReservations->count() - $uniqueReservations->count()
            ]);
            
            // Format reservations data
            $formattedReservations = collect($uniqueReservations)->map(function ($reservation) use ($user) {
                return [
                    'id' => $reservation->id,
                    'subject' => $reservation->subject,
                    'proposed_datetime' => $reservation->proposed_datetime->toISOString(),
                    'duration_minutes' => $reservation->duration_minutes,
                    'price' => $reservation->price,
                    'status' => $reservation->status,
                    'notes' => $reservation->notes,
                    'teacher_notes' => $reservation->teacher_notes,
                    'teacher' => [
                        'id' => $reservation->teacher?->id,
                        'name' => $reservation->teacher?->name,
                        'email' => $reservation->teacher?->email,
                        'profile_photo_url' => $reservation->teacher?->profile_photo_url,
                    ],
                    'student' => [
                        'id' => $reservation->student?->id,
                        'name' => $reservation->student?->name,
                        'email' => $reservation->student?->email,
                        'profile_photo_url' => $reservation->student?->profile_photo_url,
                    ],
                    'category' => [
                        'id' => $reservation->category?->id,
                        'name' => $reservation->category?->name,
                        'slug' => $reservation->category?->slug,
                    ],
                    'created_at' => $reservation->created_at->toISOString(),
                    'updated_at' => $reservation->updated_at->toISOString(),
                ];
            });

            // Cache the formatted reservations for 5 minutes
            cache()->put($cacheKey, $formattedReservations->toArray(), 300);
            Log::info('📦 Cache SET for reservations', ['user_id' => $user->id, 'role' => $user->role, 'count' => $formattedReservations->count()]);
            
            return response()->json([
                'success' => true,
                'reservations' => $formattedReservations,
                'total' => count($uniqueReservations)
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error getting reservations: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'RESERVATIONS_FETCH_ERROR',
                    'message' => 'Rezervasyonlar yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Create a new reservation
     */
    public function store(Request $request): JsonResponse
    {
        Log::info('🚀 ReservationController::store STARTED', [
            'request_data' => $request->all(),
            'timestamp' => now(),
        ]);
        
        try {
            $validator = Validator::make($request->all(), [
                'teacher_id' => 'required|exists:users,id',
                'category_id' => 'required|exists:categories,id',
                'subject' => 'required|string|max:255',
                'proposed_datetime' => 'required|date|after:now',
                'duration_minutes' => 'required|integer|min:15|max:480', // 15 minutes to 8 hours
                'notes' => 'nullable|string|max:500',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Geçersiz veri',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $user = Auth::user();
            Log::info('👤 User authenticated', ['user_id' => $user->id, 'role' => $user->role]);

            // Check if user is a student
            if ($user->role !== 'student') {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Sadece öğrenciler rezervasyon oluşturabilir'
                    ]
                ], 403);
            }

            // Check if teacher exists and is approved
            $teacher = User::where('id', $request->teacher_id)
                ->where('role', 'teacher')
                ->first();

            if (!$teacher) {
                return response()->json([
                    'error' => [
                        'code' => 'TEACHER_NOT_FOUND',
                        'message' => 'Öğretmen bulunamadı'
                    ]
                ], 404);
            }

            // ✅ Check teacher availability first
            $proposedStart = Carbon::parse($request->proposed_datetime);
            $dayOfWeek = strtolower($proposedStart->format('l'));
            
            // Check if teacher has availability for this day
            $teacherProfile = Teacher::where('user_id', $request->teacher_id)->first();
            if (!$teacherProfile) {
                return response()->json([
                    'error' => [
                        'code' => 'TEACHER_PROFILE_NOT_FOUND',
                        'message' => 'Öğretmen profili bulunamadı'
                    ]
                ], 404);
            }
            
            // Check for exceptions (unavailable days)
            $exception = $teacherProfile->exceptions()
                ->where('exception_date', $proposedStart->format('Y-m-d'))
                ->where('is_active', true)
                ->first();
                
            if ($exception && $exception->type === 'unavailable') {
                return response()->json([
                    'error' => [
                        'code' => 'TEACHER_UNAVAILABLE',
                        'message' => 'Öğretmen bu tarihte müsait değil: ' . ($exception->reason ?? 'İzinli')
                    ]
                ], 409);
            }
            
            // Check if teacher has availability for this day of week
            $hasAvailability = $teacherProfile->availabilities()
                ->where('day_of_week', $dayOfWeek)
                ->where('is_available', true)
                ->exists();
                
            if (!$hasAvailability) {
                return response()->json([
                    'error' => [
                        'code' => 'NO_AVAILABILITY',
                        'message' => 'Öğretmen bu gün müsait değil'
                    ]
                ], 409);
            }
            
            // Note: Frontend already shows only available slots, so we don't need to double-check here
            // The getAvailableSlots API already handles availability validation

            // ✅ Check for conflicts with existing reservations
            if ($this->conflictService->hasConflict(
                $request->teacher_id,
                $proposedStart,
                $request->duration_minutes
            )) {
                return response()->json([
                    'error' => [
                        'code' => 'RESERVATION_CONFLICT',
                        'message' => 'Bu saatte öğretmen başka bir derse sahip. Lütfen farklı bir saat seçin.'
                    ]
                ], 409); // 409 Conflict
            }

            // ✅ Check daily limit (prevent spam)
            if ($this->conflictService->exceedsDailyLimit($user->id)) {
                return response()->json([
                    'error' => [
                        'code' => 'DAILY_LIMIT_EXCEEDED',
                        'message' => 'Günlük maksimum rezervasyon limitine ulaştınız. Lütfen yarın tekrar deneyin.'
                    ]
                ], 429); // 429 Too Many Requests
            }

            // ✅ Check minimum notice period (2 hours)
            if ($this->conflictService->isTooClose($proposedStart, 2)) {
                return response()->json([
                    'error' => [
                        'code' => 'TOO_CLOSE',
                        'message' => 'Rezervasyon en az 2 saat önceden yapılmalıdır.'
                    ]
                ], 400);
            }

            // Get teacher's price
            $teacherProfile = Teacher::where('user_id', $teacher->id)->first();
            $pricePerHour = $teacherProfile?->price_hour ?? 0;
            $totalPrice = ($pricePerHour / 60) * $request->duration_minutes;

            // Create reservation
            Log::info('💾 Creating reservation', [
                'student_id' => $user->id,
                'teacher_id' => $request->teacher_id,
                'category_id' => $request->category_id,
                'subject' => $request->subject,
                'proposed_datetime' => $request->proposed_datetime,
                'duration_minutes' => $request->duration_minutes,
                'price' => $totalPrice,
                'notes' => $request->notes,
            ]);
            
            $reservation = Reservation::create([
                'student_id' => $user->id,
                'teacher_id' => $request->teacher_id, // This is the user_id, not teacher_id
                'category_id' => $request->category_id,
                'subject' => $request->subject,
                'proposed_datetime' => $request->proposed_datetime,
                'duration_minutes' => $request->duration_minutes,
                'price' => $totalPrice,
                'notes' => $request->notes,
                'status' => 'pending',
            ]);
            
            Log::info('✅ Reservation created successfully', ['reservation_id' => $reservation->id]);

            // Invalidate cache for both student and teacher
            $this->cacheService->invalidateUserCache($user->id);
            $this->cacheService->invalidateUserCache($request->teacher_id);
            Log::info('🗑️ Cache invalidated for reservation creation', ['student_id' => $user->id, 'teacher_id' => $request->teacher_id]);

            // Load relationships for response
            $reservation->load(['teacher', 'student', 'category']);

            // ✅ Send notifications (in-app + push + email)
            try {
                $this->notificationService->sendReservationCreatedNotification(
                    $teacher,
                    $user,
                    $reservation
                );
                Log::info('✅ Reservation notification sent to teacher', [
                    'teacher_id' => $teacher->id,
                    'reservation_id' => $reservation->id
                ]);
            } catch (\Exception $e) {
                Log::warning('Failed to send reservation notification: ' . $e->getMessage());
            }

            return response()->json([
                'success' => true,
                'message' => 'Rezervasyon başarıyla oluşturuldu',
                'reservation' => [
                    'id' => $reservation->id,
                    'subject' => $reservation->subject,
                    'proposed_datetime' => $reservation->proposed_datetime->toISOString(),
                    'duration_minutes' => $reservation->duration_minutes,
                    'price' => $reservation->price,
                    'status' => $reservation->status,
                    'teacher' => [
                        'name' => $reservation->teacher?->name,
                        'email' => $reservation->teacher?->email,
                    ],
                    'category' => [
                        'name' => $reservation->category?->name,
                    ],
                ]
            ], 201);

        } catch (\Exception $e) {
            Log::error('❌ Error creating reservation', [
                'error_message' => $e->getMessage(),
                'error_file' => $e->getFile(),
                'error_line' => $e->getLine(),
                'error_trace' => $e->getTraceAsString(),
                'request_data' => $request->all()
            ]);

            return response()->json([
                'error' => [
                    'code' => 'RESERVATION_CREATE_ERROR',
                    'message' => 'Rezervasyon oluşturulurken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Update reservation status
     */
    public function updateStatus(Request $request, Reservation $reservation): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'status' => 'required|in:accepted,rejected,cancelled,completed',
                'teacher_notes' => 'nullable|string|max:500',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Geçersiz veri',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $user = Auth::user();

            // Check permissions
            if ($user->role === 'teacher' && $reservation->teacher_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu rezervasyonu güncelleme yetkiniz yok'
                    ]
                ], 403);
            }

            if ($user->role === 'student' && $reservation->student_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu rezervasyonu güncelleme yetkiniz yok'
                    ]
                ], 403);
            }

            // Store old status for notification logic
            $oldStatus = $reservation->status;
            
            // Update reservation
            $reservation->update([
                'status' => $request->status,
                'teacher_notes' => $request->teacher_notes,
            ]);

            // ✅ Send notifications based on status change
            try {
                $reservation->load(['teacher', 'student']);
                
                if ($request->status === 'accepted' && $oldStatus !== 'accepted') {
                    // Öğrenciye: "Rezervasyonunuz onaylandı!"
                    $this->notificationService->sendReservationAcceptedNotification(
                        $reservation->student,
                        $reservation->teacher,
                        $reservation
                    );
                } elseif ($request->status === 'rejected') {
                    // Öğrenciye: "Rezervasyonunuz reddedildi"
                    $this->notificationService->sendReservationRejectedNotification(
                        $reservation->student,
                        $reservation->teacher,
                        $reservation
                    );
                }
                
                Log::info('✅ Reservation status notification sent', [
                    'reservation_id' => $reservation->id,
                    'status' => $request->status,
                    'old_status' => $oldStatus
                ]);
            } catch (\Exception $e) {
                Log::warning('Failed to send status update notification: ' . $e->getMessage());
            }

            return response()->json([
                'success' => true,
                'message' => 'Rezervasyon durumu güncellendi',
                'reservation' => [
                    'id' => $reservation->id,
                    'status' => $reservation->status,
                    'teacher_notes' => $reservation->teacher_notes,
                ]
            ]);

        } catch (\Exception $e) {
            Log::error('Error updating reservation status: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'RESERVATION_UPDATE_ERROR',
                    'message' => 'Rezervasyon güncellenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Cancel a reservation
     */
    public function destroy(Reservation $reservation): JsonResponse
    {
        try {
            $user = Auth::user();

            // Check if user can cancel this reservation
            if ($reservation->student_id !== $user->id && $reservation->teacher_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu rezervasyonu iptal etme yetkiniz yok'
                    ]
                ], 403);
            }

            // Check if reservation can be cancelled
            if ($reservation->status === 'completed') {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_STATUS',
                        'message' => 'Tamamlanmış rezervasyonlar iptal edilemez'
                    ]
                ], 400);
            }

            // Cancel reservation
            $reservation->update(['status' => 'cancelled']);

            // ✅ Send complete notification (in-app + push + email)
            try {
                $reservation->load(['student', 'teacher']);
                
                // Determine who to notify (the other party)
                $canceller = $user;
                $recipient = ($user->id === $reservation->student_id) 
                    ? $reservation->teacher 
                    : $reservation->student;

                if ($recipient) {
                    $this->notificationService->sendReservationCancelledNotification(
                        $recipient,
                        $canceller,
                        $reservation
                    );

                    Log::info('✅ Reservation cancellation notification sent', [
                        'reservation_id' => $reservation->id,
                        'cancelled_by' => $canceller->id,
                        'notified_user' => $recipient->id
                    ]);
                }

                // Also send email (backward compatibility)
                $this->mailService->sendReservationCancellation($reservation);

            } catch (\Exception $e) {
                Log::warning('Failed to send cancellation notification: ' . $e->getMessage());
            }

            return response()->json([
                'success' => true,
                'message' => 'Rezervasyon iptal edildi'
            ]);

        } catch (\Exception $e) {
            Log::error('Error cancelling reservation: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'RESERVATION_CANCEL_ERROR',
                    'message' => 'Rezervasyon iptal edilirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Update reservation details (student only, pending only)
     */
    public function update(Request $request, Reservation $reservation): JsonResponse
    {
        try {
            $user = Auth::user();

            // Check if user is the student
            if ($reservation->student_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu rezervasyonu düzenleme yetkiniz yok'
                    ]
                ], 403);
            }

            // Only pending reservations can be updated
            if ($reservation->status !== 'pending') {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_STATUS',
                        'message' => 'Sadece bekleyen rezervasyonlar düzenlenebilir'
                    ]
                ], 400);
            }

            $validator = Validator::make($request->all(), [
                'subject' => 'sometimes|string|max:255',
                'proposed_datetime' => 'sometimes|date|after:now',
                'duration_minutes' => 'sometimes|integer|min:15|max:480',
                'notes' => 'nullable|string|max:500',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Geçersiz veri',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            // If datetime or duration changed, check conflicts
            if ($request->has('proposed_datetime') || $request->has('duration_minutes')) {
                $newDatetime = $request->has('proposed_datetime') 
                    ? Carbon::parse($request->proposed_datetime)
                    : $reservation->proposed_datetime;
                
                $newDuration = $request->duration_minutes ?? $reservation->duration_minutes;

                // Check conflicts (exclude current reservation)
                if ($this->conflictService->hasConflict(
                    $reservation->teacher_id,
                    $newDatetime,
                    $newDuration,
                    $reservation->id
                )) {
                    return response()->json([
                        'error' => [
                            'code' => 'RESERVATION_CONFLICT',
                            'message' => 'Yeni tarihte öğretmen başka bir derse sahip'
                        ]
                    ], 409);
                }

                // Check minimum notice
                if ($this->conflictService->isTooClose($newDatetime, 2)) {
                    return response()->json([
                        'error' => [
                            'code' => 'TOO_CLOSE',
                            'message' => 'Rezervasyon en az 2 saat önceden yapılmalıdır'
                        ]
                    ], 400);
                }

                // Recalculate price if duration changed
                if ($request->has('duration_minutes')) {
                    $teacherProfile = Teacher::where('user_id', $reservation->teacher_id)->first();
                    $pricePerHour = $teacherProfile?->price_hour ?? 0;
                    $reservation->price = ($pricePerHour / 60) * $newDuration;
                }
            }

            // Update reservation
            $reservation->update($request->only([
                'subject',
                'proposed_datetime',
                'duration_minutes',
                'notes',
            ]));

            // Notify teacher about changes
            try {
                $teacher = User::find($reservation->teacher_id);
                if ($teacher) {
                    $this->notificationService->sendCompleteNotification(
                        $teacher,
                        'reservation',
                        '📝 Rezervasyon Güncellendi',
                        "{$user->name}, '{$reservation->subject}' rezervasyonunu güncelledi",
                        ['reservation_id' => $reservation->id],
                        "/reservations/{$reservation->id}",
                        "Detay Gör"
                    );
                }
            } catch (\Exception $e) {
                Log::warning('Failed to send reservation update notification: ' . $e->getMessage());
            }

            return response()->json([
                'success' => true,
                'message' => 'Rezervasyon başarıyla güncellendi',
                'reservation' => [
                    'id' => $reservation->id,
                    'subject' => $reservation->subject,
                    'proposed_datetime' => $reservation->proposed_datetime->toISOString(),
                    'duration_minutes' => $reservation->duration_minutes,
                    'price' => $reservation->price,
                ]
            ]);

        } catch (\Exception $e) {
            Log::error('Error updating reservation: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'RESERVATION_UPDATE_ERROR',
                    'message' => 'Rezervasyon güncellenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Manually complete a reservation (teacher only)
     */
    public function complete(Reservation $reservation): JsonResponse
    {
        try {
            $user = Auth::user();

            // Check if user is the teacher
            if ($reservation->teacher_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu işlemi yapma yetkiniz yok'
                    ]
                ], 403);
            }

            // Only accepted reservations can be completed
            if ($reservation->status !== 'accepted') {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_STATUS',
                        'message' => 'Sadece onaylanmış rezervasyonlar tamamlanabilir'
                    ]
                ], 400);
            }

            // Update to completed
            $reservation->update(['status' => 'completed']);

            // Send notifications
            try {
                $reservation->load(['student', 'teacher']);

                // Notify student
                if ($reservation->student) {
                    $this->notificationService->sendReservationCompletedNotification(
                        $reservation->student,
                        $reservation->teacher,
                        $reservation,
                        'student'
                    );

                    // Send rating request
                    $this->notificationService->sendRatingRequestNotification(
                        $reservation->student,
                        $reservation->teacher,
                        $reservation
                    );
                }

                // Notify teacher
                if ($reservation->teacher) {
                    $this->notificationService->sendReservationCompletedNotification(
                        $reservation->teacher,
                        $reservation->student,
                        $reservation,
                        'teacher'
                    );
                }

            } catch (\Exception $e) {
                Log::warning('Failed to send completion notifications: ' . $e->getMessage());
            }

            Log::info('Reservation manually completed', [
                'reservation_id' => $reservation->id,
                'completed_by' => $user->id,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Ders başarıyla tamamlandı'
            ]);

        } catch (\Exception $e) {
            Log::error('Error completing reservation: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'RESERVATION_COMPLETE_ERROR',
                    'message' => 'İşlem sırasında bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Request reschedule (student only)
     */
    public function requestReschedule(Request $request, Reservation $reservation): JsonResponse
    {
        try {
            $user = Auth::user();

            // Check if user is the student
            if ($reservation->student_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu işlemi yapma yetkiniz yok'
                    ]
                ], 403);
            }

            // Only accepted reservations can be rescheduled
            if ($reservation->status !== 'accepted') {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_STATUS',
                        'message' => 'Sadece onaylanmış rezervasyonlar yeniden planlanabilir'
                    ]
                ], 400);
            }

            $validator = Validator::make($request->all(), [
                'new_datetime' => 'required|date|after:now',
                'reason' => 'required|string|max:500',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Geçersiz veri',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $newDatetime = Carbon::parse($request->new_datetime);

            // Check conflicts
            if ($this->conflictService->hasConflict(
                $reservation->teacher_id,
                $newDatetime,
                $reservation->duration_minutes,
                $reservation->id
            )) {
                return response()->json([
                    'error' => [
                        'code' => 'RESERVATION_CONFLICT',
                        'message' => 'Yeni tarihte öğretmen başka bir derse sahip'
                    ]
                ], 409);
            }

            // Check minimum notice
            if ($this->conflictService->isTooClose($newDatetime, 2)) {
                return response()->json([
                    'error' => [
                        'code' => 'TOO_CLOSE',
                        'message' => 'Yeni tarih en az 2 saat sonra olmalıdır'
                    ]
                ], 400);
            }

            // Store reschedule request in teacher_notes
            $rescheduleData = [
                'type' => 'reschedule_request',
                'requested_by' => $user->id,
                'requested_at' => now()->toISOString(),
                'old_datetime' => $reservation->proposed_datetime->toISOString(),
                'new_datetime' => $newDatetime->toISOString(),
                'reason' => $request->reason,
                'status' => 'pending'
            ];

            $currentNotes = $reservation->teacher_notes ? json_decode($reservation->teacher_notes, true) : [];
            if (!is_array($currentNotes)) {
                $currentNotes = ['old_note' => $currentNotes];
            }
            $currentNotes['reschedule_request'] = $rescheduleData;

            $reservation->update([
                'teacher_notes' => json_encode($currentNotes, JSON_UNESCAPED_UNICODE)
            ]);

            // Notify teacher
            try {
                $teacher = User::find($reservation->teacher_id);
                if ($teacher) {
                    $this->notificationService->sendCompleteNotification(
                        $teacher,
                        'reservation',
                        '🔄 Yeniden Planlama Talebi',
                        "{$user->name}, '{$reservation->subject}' dersini yeniden planlamak istiyor\nNeden: {$request->reason}",
                        ['reservation_id' => $reservation->id, 'new_datetime' => $newDatetime->toISOString()],
                        "/reservations/{$reservation->id}",
                        "Talebi İncele"
                    );
                }
            } catch (\Exception $e) {
                Log::warning('Failed to send reschedule notification: ' . $e->getMessage());
            }

            Log::info('Reschedule requested', [
                'reservation_id' => $reservation->id,
                'old_datetime' => $reservation->proposed_datetime->toDateTimeString(),
                'new_datetime' => $newDatetime->toDateTimeString(),
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Yeniden planlama talebi gönderildi',
                'reschedule_request' => [
                    'old_datetime' => $reservation->proposed_datetime->toISOString(),
                    'new_datetime' => $newDatetime->toISOString(),
                    'reason' => $request->reason,
                ]
            ]);

        } catch (\Exception $e) {
            Log::error('Error requesting reschedule: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'RESCHEDULE_REQUEST_ERROR',
                    'message' => 'Talep gönderilirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Approve/Reject reschedule request (teacher only)
     */
    public function handleRescheduleRequest(Request $request, Reservation $reservation): JsonResponse
    {
        try {
            $user = Auth::user();

            // Check if user is the teacher
            if ($reservation->teacher_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu işlemi yapma yetkiniz yok'
                    ]
                ], 403);
            }

            $validator = Validator::make($request->all(), [
                'action' => 'required|in:approve,reject',
                'rejection_reason' => 'required_if:action,reject|string|max:500',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Geçersiz veri',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            // Get reschedule request from notes
            $currentNotes = $reservation->teacher_notes ? json_decode($reservation->teacher_notes, true) : [];
            
            if (!isset($currentNotes['reschedule_request'])) {
                return response()->json([
                    'error' => [
                        'code' => 'NO_RESCHEDULE_REQUEST',
                        'message' => 'Yeniden planlama talebi bulunamadı'
                    ]
                ], 404);
            }

            $rescheduleData = $currentNotes['reschedule_request'];

            if ($rescheduleData['status'] !== 'pending') {
                return response()->json([
                    'error' => [
                        'code' => 'ALREADY_HANDLED',
                        'message' => 'Bu talep zaten işleme alınmış'
                    ]
                ], 400);
            }

            if ($request->action === 'approve') {
                // Update reservation datetime
                $newDatetime = Carbon::parse($rescheduleData['new_datetime']);
                
                $reservation->update([
                    'proposed_datetime' => $newDatetime
                ]);

                $rescheduleData['status'] = 'approved';
                $rescheduleData['handled_by'] = $user->id;
                $rescheduleData['handled_at'] = now()->toISOString();

                // Notify student
                try {
                    $student = User::find($reservation->student_id);
                    if ($student) {
                        $this->notificationService->sendCompleteNotification(
                            $student,
                            'reservation',
                            '✅ Yeniden Planlama Onaylandı',
                            "'{$reservation->subject}' dersinizin yeniden planlama talebi onaylandı\nYeni Tarih: " . $newDatetime->locale('tr')->isoFormat('D MMMM YYYY, HH:mm'),
                            ['reservation_id' => $reservation->id],
                            "/reservations/{$reservation->id}",
                            "Detay Gör"
                        );
                    }
                } catch (\Exception $e) {
                    Log::warning('Failed to send approval notification: ' . $e->getMessage());
                }

                $message = 'Yeniden planlama talebi onaylandı';

            } else {
                // Reject
                $rescheduleData['status'] = 'rejected';
                $rescheduleData['handled_by'] = $user->id;
                $rescheduleData['handled_at'] = now()->toISOString();
                $rescheduleData['rejection_reason'] = $request->rejection_reason;

                // Notify student
                try {
                    $student = User::find($reservation->student_id);
                    if ($student) {
                        $this->notificationService->sendCompleteNotification(
                            $student,
                            'reservation',
                            '❌ Yeniden Planlama Reddedildi',
                            "'{$reservation->subject}' dersinizin yeniden planlama talebi reddedildi\nNeden: {$request->rejection_reason}",
                            ['reservation_id' => $reservation->id],
                            "/reservations/{$reservation->id}",
                            "Detay Gör"
                        );
                    }
                } catch (\Exception $e) {
                    Log::warning('Failed to send rejection notification: ' . $e->getMessage());
                }

                $message = 'Yeniden planlama talebi reddedildi';
            }

            // Update notes
            $currentNotes['reschedule_request'] = $rescheduleData;
            $reservation->update([
                'teacher_notes' => json_encode($currentNotes, JSON_UNESCAPED_UNICODE)
            ]);

            Log::info('Reschedule request handled', [
                'reservation_id' => $reservation->id,
                'action' => $request->action,
                'handled_by' => $user->id,
            ]);

            return response()->json([
                'success' => true,
                'message' => $message
            ]);

        } catch (\Exception $e) {
            Log::error('Error handling reschedule request: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'RESCHEDULE_HANDLE_ERROR',
                    'message' => 'İşlem sırasında bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get reservation statistics
     */
    public function getStatistics(): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $query = Reservation::query();
            
            // Filter by user role
            if ($user->role === 'teacher') {
                $query->where('teacher_id', $user->id);
            } else {
                $query->where('student_id', $user->id);
            }
            
            // Basic counts
            $baseQuery = clone $query;
            $totalReservations = $baseQuery->count();
            
            $pendingReservations = (clone $query)->where('status', 'pending')->count();
            $confirmedReservations = (clone $query)->where('status', 'accepted')->count();
            $completedReservations = (clone $query)->where('status', 'completed')->count();
            $cancelledReservations = (clone $query)->where('status', 'cancelled')->count();
            $rejectedReservations = (clone $query)->where('status', 'rejected')->count();
            
            // This month reservations
            $thisMonthReservations = (clone $query)->whereMonth('created_at', now()->month)
                ->whereYear('created_at', now()->year)->count();
            
            // Total spent/earned (completed only)
            $totalRevenue = (clone $query)->where('status', 'completed')->sum('price');
            
            // Monthly earnings (this month completed only)
            // Use updated_at for when the reservation was completed
            $monthlyEarnings = (clone $query)
                ->where('status', 'completed')
                ->whereMonth('updated_at', now()->month)
                ->whereYear('updated_at', now()->year)
                ->sum('price');
            
            // Potential revenue (accepted but not completed)
            $potentialRevenue = (clone $query)->where('status', 'accepted')->sum('price');
            
            // Lost revenue (cancelled/rejected)
            $lostRevenue = (clone $query)->whereIn('status', ['cancelled', 'rejected'])->sum('price');
            
            // Acceptance Rate (teacher only)
            $acceptanceRate = 0;
            $cancellationRate = 0;
            $averageResponseTime = null;
            
            if ($user->role === 'teacher') {
                $totalRequests = $pendingReservations + $confirmedReservations + $rejectedReservations;
                if ($totalRequests > 0) {
                    $acceptanceRate = round(($confirmedReservations / $totalRequests) * 100, 2);
                }
                
                // Average response time for teacher (pending -> accepted/rejected)
                $respondedReservations = (clone $query)
                    ->whereIn('status', ['accepted', 'rejected'])
                    ->whereNotNull('updated_at')
                    ->get();
                
                if ($respondedReservations->count() > 0) {
                    $totalMinutes = 0;
                    foreach ($respondedReservations as $res) {
                        $totalMinutes += $res->created_at->diffInMinutes($res->updated_at);
                    }
                    $averageResponseTime = round($totalMinutes / $respondedReservations->count());
                }
            }
            
            // Cancellation Rate (both roles)
            if ($totalReservations > 0) {
                $cancellationRate = round(($cancelledReservations / $totalReservations) * 100, 2);
            }
            
            // Completion Rate
            $completionRate = 0;
            $totalCompleted = $completedReservations + $cancelledReservations;
            if ($totalCompleted > 0) {
                $completionRate = round(($completedReservations / $totalCompleted) * 100, 2);
            }
            
            // Monthly Trends (last 6 months)
            $monthlyTrends = [];
            for ($i = 5; $i >= 0; $i--) {
                $date = now()->subMonths($i);
                $monthData = (clone $query)
                    ->whereMonth('created_at', $date->month)
                    ->whereYear('created_at', $date->year);
                
                $monthlyTrends[] = [
                    'month' => $date->format('Y-m'),
                    'month_name' => $date->locale('tr')->isoFormat('MMMM YYYY'),
                    'total' => $monthData->count(),
                    'completed' => (clone $monthData)->where('status', 'completed')->count(),
                    'cancelled' => (clone $monthData)->where('status', 'cancelled')->count(),
                    'revenue' => (clone $monthData)->where('status', 'completed')->sum('price'),
                ];
            }
            
            // Average lesson duration
            $avgDuration = (clone $query)->where('status', 'completed')->avg('duration_minutes');
            
            // Most booked time slots (teacher only)
            $popularTimeSlots = [];
            if ($user->role === 'teacher') {
                $timeSlots = (clone $query)
                    ->whereIn('status', ['accepted', 'completed'])
                    ->get()
                    ->groupBy(function ($item) {
                        return $item->proposed_datetime->format('H');
                    })
                    ->map(function ($group) {
                        return $group->count();
                    })
                    ->sortDesc()
                    ->take(3);
                
                foreach ($timeSlots as $hour => $count) {
                    $popularTimeSlots[] = [
                        'time' => sprintf('%02d:00', $hour),
                        'count' => $count,
                    ];
                }
            }
            
            // Rating statistics (if reservation has ratings)
            $ratedCount = (clone $query)->where('status', 'completed')->whereNotNull('rating_id')->count();
            $ratingRate = $completedReservations > 0 ? round(($ratedCount / $completedReservations) * 100, 2) : 0;
            
            return response()->json([
                'success' => true,
                'statistics' => [
                    // Basic counts
                    'total_reservations' => $totalReservations,
                    'pending_reservations' => $pendingReservations,
                    'confirmed_reservations' => $confirmedReservations,
                    'completed_reservations' => $completedReservations,
                    'cancelled_reservations' => $cancelledReservations,
                    'rejected_reservations' => $rejectedReservations,
                    'this_month' => $thisMonthReservations,
                    
                    // Frontend compatible fields
                    'completed_lessons' => $completedReservations,
                    'active_lessons' => $confirmedReservations,
                    'total_hours' => round($avgDuration * $completedReservations / 60, 1), // Convert minutes to hours
                    'success_rate' => $completedReservations > 0 ? round(($completedReservations / ($completedReservations + $cancelledReservations + $rejectedReservations)) * 100, 1) : 0,
                    
                    // Revenue
                    'total_revenue' => round($totalRevenue, 2),
                    'total_earnings' => round($totalRevenue, 2), // Alias for frontend
                    'monthly_earnings' => round($monthlyEarnings, 2),
                    'potential_revenue' => round($potentialRevenue, 2),
                    'lost_revenue' => round($lostRevenue, 2),
                    
                    // Rates
                    'acceptance_rate' => $acceptanceRate,
                    'cancellation_rate' => $cancellationRate,
                    'completion_rate' => $completionRate,
                    'rating_rate' => $ratingRate,
                    
                    // Performance
                    'average_response_time_minutes' => $averageResponseTime,
                    'average_lesson_duration_minutes' => $avgDuration ? round($avgDuration) : null,
                    
                    // Trends
                    'monthly_trends' => $monthlyTrends,
                    'popular_time_slots' => $popularTimeSlots,
                ]
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error getting reservation statistics: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'STATISTICS_ERROR',
                    'message' => 'İstatistikler yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Submit rating for completed reservation (student only)
     */
    public function submitRating(Request $request, Reservation $reservation): JsonResponse
    {
        try {
            $user = Auth::user();

            // Check if user is the student
            if ($reservation->student_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu işlemi yapma yetkiniz yok'
                    ]
                ], 403);
            }

            // Only completed reservations can be rated
            if ($reservation->status !== 'completed') {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_STATUS',
                        'message' => 'Sadece tamamlanmış dersler değerlendirilebilir'
                    ]
                ], 400);
            }

            // Check if already rated
            if ($reservation->rating_id) {
                return response()->json([
                    'error' => [
                        'code' => 'ALREADY_RATED',
                        'message' => 'Bu ders zaten değerlendirilmiş'
                    ]
                ], 400);
            }

            $validator = Validator::make($request->all(), [
                'rating' => 'required|integer|min:1|max:5',
                'review' => 'nullable|string|max:1000',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Geçersiz veri',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            // Create rating
            $rating = \App\Models\Rating::create([
                'student_id' => $user->id,
                'teacher_id' => $reservation->teacher_id,
                'reservation_id' => $reservation->id,
                'rating' => $request->rating,
                'review' => $request->review,
            ]);

            // Update reservation
            $reservation->update([
                'rating_id' => $rating->id,
                'rated_at' => now(),
            ]);

            // Notify teacher
            try {
                $teacher = User::find($reservation->teacher_id);
                if ($teacher) {
                    $stars = str_repeat('⭐', $request->rating);
                    $this->notificationService->sendCompleteNotification(
                        $teacher,
                        'rating',
                        '⭐ Yeni Değerlendirme',
                        "{$user->name}, '{$reservation->subject}' dersinizi değerlendirdi\n{$stars}",
                        ['rating_id' => $rating->id, 'reservation_id' => $reservation->id],
                        "/ratings/{$rating->id}",
                        "Değerlendirmeyi Gör"
                    );
                }
            } catch (\Exception $e) {
                Log::warning('Failed to send rating notification: ' . $e->getMessage());
            }

            Log::info('Rating submitted', [
                'rating_id' => $rating->id,
                'reservation_id' => $reservation->id,
                'rating' => $request->rating,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Değerlendirme başarıyla gönderildi',
                'rating' => [
                    'id' => $rating->id,
                    'rating' => $rating->rating,
                    'review' => $rating->review,
                ]
            ]);

        } catch (\Exception $e) {
            Log::error('Error submitting rating: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'RATING_SUBMIT_ERROR',
                    'message' => 'Değerlendirme gönderilirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get student's reservations
     */
    public function studentReservations(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            
            if ($user->role !== 'student') {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Sadece öğrenciler rezervasyon görüntüleyebilir'
                    ]
                ], 403);
            }

            $query = Reservation::where('student_id', $user->id)
                ->with([
                    'teacher:id,name,email,profile_photo_url',
                    'category:id,name,slug'
                ]);

            // Status filter
            if ($request->has('status')) {
                $query->where('status', $request->status);
            }

            // Date filter
            if ($request->has('date_from')) {
                $query->where('proposed_datetime', '>=', $request->date_from);
            }
            if ($request->has('date_to')) {
                $query->where('proposed_datetime', '<=', $request->date_to);
            }

            $reservations = $query->orderBy('proposed_datetime', 'desc')->get();

            return response()->json([
                'success' => true,
                'data' => $reservations,
                'total' => $reservations->count()
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error getting student reservations: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'STUDENT_RESERVATIONS_ERROR',
                    'message' => 'Öğrenci rezervasyonları yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get teacher's reservations
     */
    public function teacherReservations(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            
            if ($user->role !== 'teacher') {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Sadece öğretmenler rezervasyon görüntüleyebilir'
                    ]
                ], 403);
            }

            $query = Reservation::where('teacher_id', $user->id)
                ->with([
                    'student:id,name,email,profile_photo_url',
                    'category:id,name,slug'
                ]);

            // Status filter
            if ($request->has('status')) {
                $query->where('status', $request->status);
            }

            // Date filter
            if ($request->has('date_from')) {
                $query->where('proposed_datetime', '>=', $request->date_from);
            }
            if ($request->has('date_to')) {
                $query->where('proposed_datetime', '<=', $request->date_to);
            }

            $reservations = $query->orderBy('proposed_datetime', 'desc')->get();

            // Format reservations for frontend
            $formattedReservations = $reservations->map(function ($reservation) {
                return [
                    'id' => $reservation->id,
                    'student_id' => $reservation->student_id,
                    'teacher_id' => $reservation->teacher_id,
                    'category_id' => $reservation->category_id,
                    'subject' => $reservation->subject ?? ($reservation->category->name ?? 'Ders'),
                    'proposed_datetime' => $reservation->proposed_datetime->toISOString(),
                    'status' => $reservation->status,
                    'notes' => $reservation->notes,
                    'teacher_notes' => $reservation->teacher_notes,
                    'price' => $reservation->price ?? 0,
                    'duration_minutes' => $reservation->duration_minutes,
                    'created_at' => $reservation->created_at->toISOString(),
                    'updated_at' => $reservation->updated_at->toISOString(),
                    'student' => [
                        'id' => $reservation->student->id,
                        'name' => $reservation->student->name,
                        'email' => $reservation->student->email,
                        'profile_photo_url' => $reservation->student->profile_photo_url,
                    ],
                    'category' => [
                        'id' => $reservation->category->id,
                        'name' => $reservation->category->name,
                        'slug' => $reservation->category->slug,
                    ],
                ];
            });

            return response()->json([
                'success' => true,
                'reservations' => $formattedReservations,
                'total' => $formattedReservations->count()
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error getting teacher reservations: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'TEACHER_RESERVATIONS_ERROR',
                    'message' => 'Öğretmen rezervasyonları yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }
}