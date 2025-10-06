<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\Teacher;
use App\Models\Reservation;
use App\Models\Lesson;
use App\Models\Rating;
use App\Models\AuditLog;
use App\Services\CacheService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;

class UserController extends Controller
{
    protected CacheService $cacheService;

    public function __construct()
    {
        // Cache service temporarily disabled for deployment
    }

    /**
     * Get user profile
     */
    public function profile(): JsonResponse
    {
        Log::info('🚀 UserController::profile STARTED');
        try {
            $user = Auth::user();
            $user->load(['teacher', 'socialAccounts']);

            // Get additional profile data based on role
            $profileData = [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => $user->role,
                'profile_photo_url' => $user->profile_photo_url,
                'email_verified_at' => $user->email_verified_at,
                'created_at' => $user->created_at,
                'social_accounts' => $user->socialAccounts ?? [],
            ];

            if ($user->role === 'teacher' && $user->teacher) {
                $profileData['teacher_profile'] = [
                    'bio' => $user->teacher->bio,
                    'specialization' => $user->teacher->specialization,
                    'education' => $user->teacher->education,
                    'certifications' => $user->teacher->certifications,
                    'price_hour' => $user->teacher->price_hour,
                    'languages' => $user->teacher->languages,
                    'online_available' => $user->teacher->online_available,
                    'rating_avg' => $user->teacher->rating_avg,
                    'total_students' => $user->teacher->total_students,
                    'categories' => $user->teacher->categories,
                ];
            }

            Log::info('✅ UserController::profile COMPLETED');
            return response()->json([
                'user' => $profileData
            ]);

        } catch (\Exception $e) {
            Log::error('💥 ERROR in UserController::profile', [
                'error_message' => $e->getMessage(),
                'error_file' => $e->getFile(),
                'error_line' => $e->getLine(),
                'stack_trace' => $e->getTraceAsString()
            ]);
            return response()->json([
                'error' => [
                    'code' => 'PROFILE_ERROR',
                    'message' => 'Profil bilgileri alınırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Update user profile
     */
    public function update(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();

            $validator = Validator::make($request->all(), [
                'name' => 'sometimes|string|max:255',
                'email' => 'sometimes|email|max:255|unique:users,email,' . $user->id,
                'phone' => 'sometimes|string|max:20',
                'bio' => 'sometimes|string|max:1000',
                'location' => 'sometimes|string|max:255',
                'profile_photo' => 'sometimes|image|mimes:jpeg,png,jpg,gif|max:2048',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => $validator->errors()
                    ]
                ], 400);
            }

            $updateData = $request->only(['name', 'email', 'phone', 'bio', 'location']);

            // Handle profile photo upload
            if ($request->hasFile('profile_photo')) {
                $file = $request->file('profile_photo');
                $filename = 'profile_' . $user->id . '_' . time() . '.' . $file->getClientOriginalExtension();
                $path = $file->storeAs('profiles', $filename, 'public');
                $updateData['profile_photo_url'] = Storage::url($path);
            }

            $user->update($updateData);

            // Audit log
            AuditLog::createLog(
                userId: $user->id,
                action: 'update_profile',
                targetType: 'User',
                targetId: $user->id,
                meta: [
                    'updated_fields' => array_keys($updateData),
                    'ip_address' => $request->ip(),
                ],
                ipAddress: $request->ip(),
                userAgent: $request->userAgent(),
            );

            return response()->json([
                'message' => 'Profil başarıyla güncellendi',
                'user' => $user->fresh()
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'error' => [
                    'code' => 'UPDATE_PROFILE_ERROR',
                    'message' => 'Profil güncellenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Change password
     */
    public function changePassword(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();

            $validator = Validator::make($request->all(), [
                'current_password' => 'required|string',
                'new_password' => 'required|string|min:8|confirmed',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => $validator->errors()
                    ]
                ], 400);
            }

            // Check current password
            if (!Hash::check($request->current_password, $user->password)) {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_PASSWORD',
                        'message' => 'Mevcut şifre yanlış'
                    ]
                ], 400);
            }

            $user->update([
                'password' => Hash::make($request->new_password)
            ]);

            // Audit log
            AuditLog::createLog(
                userId: $user->id,
                action: 'change_password',
                targetType: 'User',
                targetId: $user->id,
                meta: [
                    'ip_address' => $request->ip(),
                ],
                ipAddress: $request->ip(),
                userAgent: $request->userAgent(),
            );

            return response()->json([
                'message' => 'Şifre başarıyla değiştirildi'
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'error' => [
                    'code' => 'CHANGE_PASSWORD_ERROR',
                    'message' => 'Şifre değiştirilirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get user statistics
     */
    public function getStatistics(): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $stats = [
                'total_reservations' => Reservation::where('student_id', $user->id)
                    ->orWhere('teacher_id', $user->id)
                    ->count(),
                
                'completed_lessons' => Lesson::where(function ($q) use ($user) {
                    $q->where('student_id', $user->id)
                      ->orWhere('teacher_id', $user->id);
                })->where('status', 'completed')->count(),
                
                'total_duration' => Lesson::where(function ($q) use ($user) {
                    $q->where('student_id', $user->id)
                      ->orWhere('teacher_id', $user->id);
                })->where('status', 'completed')->sum('duration_minutes'),
                
                'average_rating' => $user->role === 'teacher' 
                    ? Rating::where('teacher_id', $user->id)->avg('rating')
                    : Lesson::where('student_id', $user->id)
                        ->where('status', 'completed')
                        ->whereNotNull('rating')
                        ->avg('rating'),
                
                'this_month_activity' => Lesson::where(function ($q) use ($user) {
                    $q->where('student_id', $user->id)
                      ->orWhere('teacher_id', $user->id);
                })->whereMonth('created_at', now()->month)
                  ->whereYear('created_at', now()->year)
                  ->count(),
            ];

            if ($user->role === 'teacher') {
                $stats['total_students'] = Reservation::where('teacher_id', $user->id)
                    ->distinct('student_id')
                    ->count('student_id');
                
                $stats['pending_reservations'] = Reservation::where('teacher_id', $user->id)
                    ->where('status', 'pending')
                    ->count();
            } else {
                $stats['favorite_teachers'] = $user->favoriteTeachers()->count();
                $stats['upcoming_lessons'] = Reservation::where('student_id', $user->id)
                    ->where('status', 'accepted')
                    ->where('scheduled_at', '>=', now())
                    ->count();
            }

            return response()->json([
                'data' => $stats,
                'message' => 'Kullanıcı istatistikleri'
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'error' => [
                    'code' => 'GET_STATISTICS_ERROR',
                    'message' => 'İstatistikler alınırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get user activity history
     */
    public function getActivityHistory(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $query = AuditLog::where('user_id', $user->id)
                ->orderBy('created_at', 'desc');

            // Filter by action type
            if ($request->has('action')) {
                $query->where('action', $request->action);
            }

            // Filter by date range
            if ($request->has('date_from')) {
                $query->whereDate('created_at', '>=', $request->date_from);
            }
            if ($request->has('date_to')) {
                $query->whereDate('created_at', '<=', $request->date_to);
            }

            // Pagination
            $perPage = $request->get('per_page', 20);
            $activities = $query->paginate($perPage);

            return response()->json([
                'data' => $activities->items(),
                'meta' => [
                    'current_page' => $activities->currentPage(),
                    'last_page' => $activities->lastPage(),
                    'per_page' => $activities->perPage(),
                    'total' => $activities->total(),
                ]
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'error' => [
                    'code' => 'GET_ACTIVITY_ERROR',
                    'message' => 'Aktivite geçmişi alınırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Delete user account
     */
    public function deleteAccount(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();

            $validator = Validator::make($request->all(), [
                'password' => 'required|string',
                'confirmation' => 'required|string|in:DELETE',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => $validator->errors()
                    ]
                ], 400);
            }

            // Verify password
            if (!Hash::check($request->password, $user->password)) {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_PASSWORD',
                        'message' => 'Şifre yanlış'
                    ]
                ], 400);
            }

            // Soft delete user
            $user->update(['deleted_at' => now()]);

            // Logout user
            auth()->logout();

            // Audit log
            AuditLog::createLog(
                userId: $user->id,
                action: 'delete_account',
                targetType: 'User',
                targetId: $user->id,
                meta: [
                    'ip_address' => $request->ip(),
                ],
                ipAddress: $request->ip(),
                userAgent: $request->userAgent(),
            );

            return response()->json([
                'message' => 'Hesap başarıyla silindi'
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'error' => [
                    'code' => 'DELETE_ACCOUNT_ERROR',
                    'message' => 'Hesap silinirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Export user data
     */
    public function exportData(): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $userData = [
                'profile' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'role' => $user->role,
                    'created_at' => $user->created_at,
                ],
                'reservations' => Reservation::where('student_id', $user->id)
                    ->orWhere('teacher_id', $user->id)
                    ->with(['teacher.user', 'student.user', 'category'])
                    ->get(),
                'lessons' => Lesson::where('student_id', $user->id)
                    ->orWhere('teacher_id', $user->id)
                    ->with(['teacher.user', 'student.user'])
                    ->get(),
                'ratings' => Rating::where('student_id', $user->id)
                    ->orWhere('teacher_id', $user->id)
                    ->with(['teacher.user', 'student.user'])
                    ->get(),
                'activity_logs' => AuditLog::where('user_id', $user->id)->get(),
            ];

            if ($user->role === 'teacher' && $user->teacher) {
                $userData['teacher_profile'] = $user->teacher->toArray();
            }

            return response()->json([
                'data' => $userData,
                'message' => 'Kullanıcı verileri'
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'error' => [
                    'code' => 'EXPORT_DATA_ERROR',
                    'message' => 'Veri dışa aktarılırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Update notification preferences
     */
    public function updateNotificationPreferences(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();

            $validator = Validator::make($request->all(), [
                'email_notifications' => 'sometimes|boolean',
                'push_notifications' => 'sometimes|boolean',
                'lesson_reminders' => 'sometimes|boolean',
                'marketing_emails' => 'sometimes|boolean',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => $validator->errors()
                    ]
                ], 400);
            }

            $user->update($request->only([
                'email_notifications',
                'push_notifications',
                'lesson_reminders',
                'marketing_emails',
            ]));

            return response()->json([
                'message' => 'Bildirim tercihleri güncellendi',
                'preferences' => $request->all()
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'error' => [
                    'code' => 'UPDATE_PREFERENCES_ERROR',
                    'message' => 'Bildirim tercihleri güncellenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get notification preferences
     */
    public function getNotificationPreferences(): JsonResponse
    {
        try {
            $user = Auth::user();

            $preferences = [
                'email_notifications' => $user->email_notifications ?? true,
                'push_notifications' => $user->push_notifications ?? true,
                'lesson_reminders' => $user->lesson_reminders ?? true,
                'marketing_emails' => $user->marketing_emails ?? false,
            ];

            return response()->json([
                'data' => $preferences,
                'message' => 'Bildirim tercihleri'
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'error' => [
                    'code' => 'GET_PREFERENCES_ERROR',
                    'message' => 'Bildirim tercihleri alınırken bir hata oluştu'
                ]
            ], 500);
        }
    }
}