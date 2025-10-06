<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Validator;
use App\Models\User;
use App\Models\Teacher;
use App\Models\Reservation;
use App\Models\Category;
use App\Models\AuditLog;
use App\Services\CacheService;

/**
 * @OA\Tag(
 *     name="Admin",
 *     description="Admin paneli ve moderasyon işlemleri"
 * )
 */
class AdminController extends Controller
{
    protected CacheService $cacheService;

    public function __construct()
    {
        // Rate limiting for admin operations will be handled in routes
        
        // Cache service temporarily disabled for deployment
    }

    /**
     * @OA\Get(
     *     path="/admin/dashboard",
     *     tags={"Admin"},
     *     summary="Admin dashboard istatistikleri",
     *     description="Admin paneli için genel istatistikleri getirir",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="Dashboard verileri başarıyla getirildi",
     *         @OA\JsonContent(
     *             @OA\Property(property="stats", type="object"),
     *             @OA\Property(property="recent_activities", type="array", @OA\Items(type="object"))
     *         )
     *     )
     * )
     */
    public function dashboard(): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        $stats = [
            'total_users' => User::count(),
            'total_teachers' => User::where('role', 'teacher')->count(),
            'total_students' => User::where('role', 'student')->count(),
            'total_reservations' => Reservation::count(),
            'pending_teachers' => User::where('role', 'teacher')
                ->where('teacher_status', 'pending')
                ->count(),
            'active_reservations' => Reservation::whereIn('status', ['confirmed', 'in_progress'])
                ->count(),
            'completed_lessons' => Reservation::where('status', 'completed')->count(),
            'total_revenue' => Reservation::where('status', 'completed')->sum('price'),
            'average_rating' => \DB::table('ratings')->avg('rating') ?? 0,
            'monthly_new_users' => User::where('created_at', '>=', now()->subMonth())->count(),
            'monthly_revenue' => Reservation::where('status', 'completed')
                ->where('created_at', '>=', now()->subMonth())
                ->sum('price'),
            'total_categories' => Category::count(),
            'active_categories' => Category::where('is_active', true)->count(),
        ];

        // Son 7 günlük aktivite grafiği
        $weeklyStats = [];
        for ($i = 6; $i >= 0; $i--) {
            $date = now()->subDays($i)->format('Y-m-d');
            $weeklyStats[] = [
                'date' => $date,
                'users' => User::whereDate('created_at', $date)->count(),
                'reservations' => Reservation::whereDate('created_at', $date)->count(),
                'revenue' => Reservation::where('status', 'completed')
                    ->whereDate('created_at', $date)
                    ->sum('price'),
            ];
        }

        $recentActivities = AuditLog::with('user')
            ->orderBy('created_at', 'desc')
            ->limit(10)
            ->get();

        // Kategori dağılımı
        $categoryStats = \DB::table('categories')
            ->leftJoin('reservations', 'categories.id', '=', 'reservations.category_id')
            ->select('categories.name', \DB::raw('COUNT(reservations.id) as reservation_count'))
            ->groupBy('categories.id', 'categories.name')
            ->orderBy('reservation_count', 'desc')
            ->limit(5)
            ->get();

        return response()->json([
            'success' => true,
            'stats' => $stats,
            'recent_activities' => $recentActivities,
            'analytics' => [
                'weekly_stats' => $weeklyStats,
                'category_distribution' => $categoryStats,
                'top_teachers' => $this->getTopTeachers(),
                'user_growth' => $this->getUserGrowthStats(),
            ],
        ]);
    }

    /**
     * En iyi öğretmenleri getir
     */
    private function getTopTeachers(): array
    {
        return \DB::table('users')
            ->join('teachers', 'users.id', '=', 'teachers.user_id')
            ->select(
                'users.id',
                'users.name',
                'users.email',
                'teachers.rating_avg',
                'teachers.rating_count',
                \DB::raw('COUNT(reservations.id) as total_lessons')
            )
            ->leftJoin('reservations', function ($join) {
                $join->on('users.id', '=', 'reservations.teacher_id')
                     ->where('reservations.status', '=', 'completed');
            })
            ->where('users.role', 'teacher')
            ->where('users.teacher_status', 'approved')
            ->groupBy('users.id', 'users.name', 'users.email', 'teachers.rating_avg', 'teachers.rating_count')
            ->orderBy('teachers.rating_avg', 'desc')
            ->orderBy('total_lessons', 'desc')
            ->limit(10)
            ->get()
            ->toArray();
    }

    /**
     * Kullanıcı büyüme istatistikleri
     */
    private function getUserGrowthStats(): array
    {
        $months = [];
        for ($i = 11; $i >= 0; $i--) {
            $date = now()->subMonths($i);
            $months[] = [
                'month' => $date->format('M Y'),
                'users' => User::whereYear('created_at', $date->year)
                    ->whereMonth('created_at', $date->month)
                    ->count(),
                'teachers' => User::where('role', 'teacher')
                    ->whereYear('created_at', $date->year)
                    ->whereMonth('created_at', $date->month)
                    ->count(),
                'students' => User::where('role', 'student')
                    ->whereYear('created_at', $date->year)
                    ->whereMonth('created_at', $date->month)
                    ->count(),
            ];
        }
        
        return $months;
    }

    /**
     * @OA\Get(
     *     path="/admin/analytics",
     *     tags={"Admin"},
     *     summary="Detaylı analitik veriler",
     *     description="Admin paneli için detaylı analitik verileri getirir",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="Analitik veriler başarıyla getirildi"
     *     )
     * )
     */
    public function getAnalytics(): JsonResponse
    {
        $analytics = [
            'user_growth' => $this->getUserGrowthData(),
            'reservation_trends' => $this->getReservationTrends(),
            'category_popularity' => $this->getCategoryPopularity(),
            'teacher_performance' => $this->getTeacherPerformance(),
        ];

        return response()->json([
            'success' => true,
            'analytics' => $analytics,
        ]);
    }

    /**
     * @OA\Put(
     *     path="/admin/users/{user}/status",
     *     tags={"Admin"},
     *     summary="Kullanıcı durumunu güncelle",
     *     description="Kullanıcının aktif/pasif durumunu günceller",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="user",
     *         in="path",
     *         required=true,
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             @OA\Property(property="status", type="string", enum={"active", "suspended"}),
     *             @OA\Property(property="reason", type="string")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Kullanıcı durumu başarıyla güncellendi"
     *     )
     * )
     */
    public function updateUserStatus(Request $request, User $user): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'status' => 'required|in:active,suspended',
            'reason' => 'nullable|string|max:500',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $status = $request->status;
        $reason = $request->reason;

        if ($status === 'suspended') {
            $user->update([
                'suspended_at' => now(),
                'suspension_reason' => $reason,
            ]);
        } else {
            $user->update([
                'suspended_at' => null,
                'suspended_until' => null,
                'suspension_reason' => null,
            ]);
        }

        // Log the action
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'user_status_updated',
            'description' => "User {$user->name} status updated to {$status}",
            'metadata' => [
                'target_user_id' => $user->id,
                'status' => $status,
                'reason' => $reason,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Kullanıcı durumu başarıyla güncellendi',
            'user' => $user->fresh(),
        ]);
    }

    // getReservations method moved to later in file to avoid duplicates

    /**
     * @OA\Get(
     *     path="/admin/categories",
     *     tags={"Admin"},
     *     summary="Kategorileri listele",
     *     description="Admin paneli için kategorileri getirir",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="Kategoriler başarıyla getirildi"
     *     )
     * )
     */
    public function getCategories(): JsonResponse
    {
        $categories = Category::with('children')
            ->orderBy('sort_order')
            ->get();

        return response()->json([
            'success' => true,
            'categories' => $categories,
        ]);
    }

    /**
     * @OA\Post(
     *     path="/admin/categories",
     *     tags={"Admin"},
     *     summary="Yeni kategori oluştur",
     *     description="Admin paneli için yeni kategori oluşturur",
     *     security={{"bearerAuth":{}}},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             @OA\Property(property="name", type="string"),
     *             @OA\Property(property="description", type="string"),
     *             @OA\Property(property="parent_id", type="integer"),
     *             @OA\Property(property="icon", type="string"),
     *             @OA\Property(property="sort_order", type="integer")
     *         )
     *     ),
     *     @OA\Response(
     *         response=201,
     *         description="Kategori başarıyla oluşturuldu"
     *     )
     * )
     */
    public function createCategory(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'description' => 'nullable|string',
            'parent_id' => 'nullable|exists:categories,id',
            'icon' => 'nullable|string|max:255',
            'sort_order' => 'nullable|integer|min:0',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $category = Category::create([
            'name' => $request->name,
            'description' => $request->description,
            'parent_id' => $request->parent_id,
            'icon' => $request->icon,
            'sort_order' => $request->sort_order ?? 0,
            'slug' => \Str::slug($request->name),
        ]);

        // Log the action
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'category_created',
            'description' => "Category '{$category->name}' created",
            'metadata' => [
                'category_id' => $category->id,
                'category_name' => $category->name,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Kategori başarıyla oluşturuldu',
            'category' => $category,
        ], 201);
    }

    /**
     * @OA\Get(
     *     path="/admin/audit-logs",
     *     tags={"Admin"},
     *     summary="Audit loglarını listele",
     *     description="Admin paneli için audit loglarını getirir",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="action",
     *         in="query",
     *         @OA\Schema(type="string")
     *     ),
     *     @OA\Parameter(
     *         name="user_id",
     *         in="query",
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Audit logları başarıyla getirildi"
     *     )
     * )
     */
    public function getAuditLogs(Request $request): JsonResponse
    {
        $query = AuditLog::with('user');

        if ($request->has('action') && $request->action) {
            $query->where('action', $request->action);
        }

        if ($request->has('user_id') && $request->user_id) {
            $query->where('user_id', $request->user_id);
        }

        $logs = $query->orderBy('created_at', 'desc')
            ->paginate($request->get('per_page', 20));

        return response()->json([
            'success' => true,
            'logs' => $logs->items(),
            'pagination' => [
                'current_page' => $logs->currentPage(),
                'last_page' => $logs->lastPage(),
                'per_page' => $logs->perPage(),
                'total' => $logs->total(),
            ],
        ]);
    }

    // User management methods
    public function listUsers(Request $request): JsonResponse
    {
        $query = User::query();

        if ($request->has('role') && $request->role) {
            $query->where('role', $request->role);
        }

        if ($request->has('status') && $request->status) {
            if ($request->status === 'active') {
                $query->whereNull('suspended_at');
            } elseif ($request->status === 'suspended') {
                $query->whereNotNull('suspended_at');
            }
        }

        $users = $query->orderBy('created_at', 'desc')
            ->paginate($request->get('per_page', 20));

        return response()->json([
            'success' => true,
            'users' => $users->items(),
            'pagination' => [
                'current_page' => $users->currentPage(),
                'last_page' => $users->lastPage(),
                'per_page' => $users->perPage(),
                'total' => $users->total(),
            ],
        ]);
    }

    public function searchUsers(Request $request): JsonResponse
    {
        $query = $request->get('q', '');
        
        if (strlen($query) < 2) {
            return response()->json([
                'success' => true,
                'users' => [],
            ]);
        }

        $users = User::where('name', 'like', "%{$query}%")
            ->orWhere('email', 'like', "%{$query}%")
            ->limit(20)
            ->get();

        return response()->json([
            'success' => true,
            'users' => $users,
        ]);
    }

    public function deleteUser(int $id): JsonResponse
    {
        $user = User::findOrFail($id);
        
        // Prevent admin from deleting themselves
        if ($user->id === Auth::id()) {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Kendi hesabınızı silemezsiniz'
                ]
            ], 403);
        }

        $userName = $user->name;
        $user->delete();

        // Log the action
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'user_deleted',
            'description' => "User '{$userName}' deleted",
            'metadata' => [
                'deleted_user_id' => $id,
                'deleted_user_name' => $userName,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Kullanıcı başarıyla silindi',
        ]);
    }

    public function deleteMultipleUsers(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'user_ids' => 'required|array|min:1',
            'user_ids.*' => 'integer|exists:users,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $userIds = $request->user_ids;
        $deletedCount = 0;

        foreach ($userIds as $userId) {
            if ($userId !== Auth::id()) {
                $user = User::find($userId);
                if ($user) {
                    $user->delete();
                    $deletedCount++;
                }
            }
        }

        // Log the action
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'multiple_users_deleted',
            'description' => "{$deletedCount} users deleted",
            'metadata' => [
                'deleted_user_ids' => $userIds,
                'deleted_count' => $deletedCount,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => "{$deletedCount} kullanıcı başarıyla silindi",
            'deleted_count' => $deletedCount,
        ]);
    }

    public function deleteUsersByName(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|min:2',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $name = $request->name;
        $users = User::where('name', 'like', "%{$name}%")->get();
        $deletedCount = 0;

        foreach ($users as $user) {
            if ($user->id !== Auth::id()) {
                $user->delete();
                $deletedCount++;
            }
        }

        // Log the action
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'users_deleted_by_name',
            'description' => "Users with name '{$name}' deleted",
            'metadata' => [
                'search_name' => $name,
                'deleted_count' => $deletedCount,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => "İsimde '{$name}' geçen {$deletedCount} kullanıcı silindi",
            'deleted_count' => $deletedCount,
        ]);
    }

    // Teacher approval methods (moved to later in file to avoid duplicates)

    // Helper methods for analytics
    private function getUserGrowthData(): array
    {
        $data = [];
        for ($i = 11; $i >= 0; $i--) {
            $date = now()->subMonths($i);
            $count = User::whereYear('created_at', $date->year)
                ->whereMonth('created_at', $date->month)
                ->count();
            $data[] = [
                'month' => $date->format('Y-m'),
                'count' => $count,
            ];
        }
        return $data;
    }

    private function getReservationTrends(): array
    {
        $data = [];
        for ($i = 6; $i >= 0; $i--) {
            $date = now()->subDays($i);
            $count = Reservation::whereDate('created_at', $date)->count();
            $data[] = [
                'date' => $date->format('Y-m-d'),
                'count' => $count,
            ];
        }
        return $data;
    }

    private function getCategoryPopularity(): array
    {
        return Category::withCount('reservations')
            ->orderBy('reservations_count', 'desc')
            ->limit(10)
            ->get()
            ->map(function ($category) {
                return [
                    'name' => $category->name,
                    'count' => $category->reservations_count,
                ];
            })
            ->toArray();
    }

    private function getTeacherPerformance(): array
    {
        return Teacher::with('user')
            ->withCount('reservations')
            ->orderBy('reservations_count', 'desc')
            ->limit(10)
            ->get()
            ->map(function ($teacher) {
                return [
                    'name' => $teacher->user->name,
                    'reservations_count' => $teacher->reservations_count,
                    'average_rating' => $teacher->average_rating,
                ];
            })
            ->toArray();
    }

    /**
     * Suspend a user
     */
    public function suspendUser(Request $request, int $userId): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'reason' => 'required|string|max:255',
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

            $user = User::findOrFail($userId);
            
            // Update user status
            $user->update([
                'status' => 'suspended',
                'suspended_reason' => $request->reason,
                'suspended_at' => now(),
                'suspended_by' => Auth::id(),
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Kullanıcı başarıyla askıya alındı',
                'user' => $user->fresh()
            ]);

        } catch (\Exception $e) {
            \Log::error('Error suspending user: ' . $e->getMessage());
            return response()->json([
                'error' => [
                    'code' => 'SUSPEND_USER_ERROR',
                    'message' => 'Kullanıcı askıya alınırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Unsuspend a user
     */
    public function unsuspendUser(Request $request, int $userId): JsonResponse
    {
        try {
            $user = User::findOrFail($userId);
            
            // Update user status
            $user->update([
                'status' => 'active',
                'suspended_reason' => null,
                'suspended_at' => null,
                'suspended_by' => null,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Kullanıcı askıdan kaldırıldı',
                'user' => $user->fresh()
            ]);

        } catch (\Exception $e) {
            \Log::error('Error unsuspending user: ' . $e->getMessage());
            return response()->json([
                'error' => [
                    'code' => 'UNSUSPEND_USER_ERROR',
                    'message' => 'Kullanıcı askıdan kaldırılırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * @OA\Get(
     *     path="/admin/users",
     *     tags={"Admin"},
     *     summary="Tüm kullanıcıları listele",
     *     description="Admin paneli için kullanıcı listesini getirir",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="role",
     *         in="query",
     *         @OA\Schema(type="string", enum={"student", "teacher", "admin"})
     *     ),
     *     @OA\Parameter(
     *         name="status",
     *         in="query",
     *         @OA\Schema(type="string", enum={"active", "suspended"})
     *     ),
     *     @OA\Parameter(
     *         name="search",
     *         in="query",
     *         @OA\Schema(type="string")
     *     ),
     *     @OA\Parameter(
     *         name="page",
     *         in="query",
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Kullanıcı listesi başarıyla getirildi"
     *     )
     * )
     */
    public function getUsers(Request $request): JsonResponse
    {
        $query = User::query();

        // Filtreleme
        if ($request->filled('role')) {
            $query->where('role', $request->role);
        }

        if ($request->filled('status')) {
            if ($request->status === 'active') {
                $query->where('status', 'active');
            } elseif ($request->status === 'suspended') {
                $query->where('status', 'suspended');
            }
        }

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('email', 'like', "%{$search}%");
            });
        }

        // Sayfalama
        $perPage = $request->get('per_page', 20);
        $users = $query->with(['teacher'])
            ->orderBy('created_at', 'desc')
            ->paginate($perPage);

        return response()->json([
            'success' => true,
            'users' => $users->items(),
            'pagination' => [
                'current_page' => $users->currentPage(),
                'last_page' => $users->lastPage(),
                'per_page' => $users->perPage(),
                'total' => $users->total(),
            ],
        ]);
    }

    /**
     * @OA\Get(
     *     path="/admin/teachers/pending",
     *     tags={"Admin"},
     *     summary="Onay bekleyen öğretmenleri listele",
     *     description="Admin onayı bekleyen öğretmenleri getirir",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="Onay bekleyen öğretmenler başarıyla getirildi"
     *     )
     * )
     */
    public function getPendingTeachers(): JsonResponse
    {
        $pendingTeachers = User::with(['teacher'])
            ->where('role', 'teacher')
            ->where('teacher_status', 'pending')
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json([
            'success' => true,
            'pending_teachers' => $pendingTeachers,
        ]);
    }

    /**
     * @OA\Post(
     *     path="/admin/teachers/{user}/approve",
     *     tags={"Admin"},
     *     summary="Öğretmeni onayla",
     *     description="Bekleyen öğretmen başvurusunu onaylar",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="user",
     *         in="path",
     *         required=true,
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             @OA\Property(property="notes", type="string")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Öğretmen başarıyla onaylandı"
     *     )
     * )
     */
    public function approveTeacher(Request $request, User $user): JsonResponse
    {
        if ($user->role !== 'teacher') {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_USER',
                    'message' => 'Bu kullanıcı bir öğretmen değil'
                ]
            ], 400);
        }

        if ($user->teacher_status !== 'pending') {
            return response()->json([
                'error' => [
                    'code' => 'ALREADY_PROCESSED',
                    'message' => 'Bu öğretmen başvurusu zaten işlenmiş'
                ]
            ], 400);
        }

        $adminId = Auth::id();
        $notes = $request->input('notes');

        $user->approveTeacher($adminId, $notes);

        // Audit log
        AuditLog::create([
            'user_id' => $adminId,
            'action' => 'teacher_approved',
            'target_type' => 'user',
            'target_id' => $user->id,
            'details' => [
                'teacher_name' => $user->name,
                'notes' => $notes,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Öğretmen başarıyla onaylandı',
            'teacher' => $user->fresh()->load('teacher'),
        ]);
    }

    /**
     * @OA\Post(
     *     path="/admin/teachers/{user}/reject",
     *     tags={"Admin"},
     *     summary="Öğretmeni reddet",
     *     description="Bekleyen öğretmen başvurusunu reddeder",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="user",
     *         in="path",
     *         required=true,
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             @OA\Property(property="reason", type="string")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Öğretmen başvurusu reddedildi"
     *     )
     * )
     */
    public function rejectTeacher(Request $request, User $user): JsonResponse
    {
        if ($user->role !== 'teacher') {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_USER',
                    'message' => 'Bu kullanıcı bir öğretmen değil'
                ]
            ], 400);
        }

        if ($user->teacher_status !== 'pending') {
            return response()->json([
                'error' => [
                    'code' => 'ALREADY_PROCESSED',
                    'message' => 'Bu öğretmen başvurusu zaten işlenmiş'
                ]
            ], 400);
        }

        $validator = Validator::make($request->all(), [
            'reason' => 'required|string|max:500',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $adminId = Auth::id();
        $reason = $request->input('reason');

        $user->update([
            'teacher_status' => 'rejected',
            'rejected_by' => $adminId,
            'rejected_at' => now(),
            'rejection_reason' => $reason,
        ]);

        // Audit log
        AuditLog::create([
            'user_id' => $adminId,
            'action' => 'teacher_rejected',
            'target_type' => 'user',
            'target_id' => $user->id,
            'details' => [
                'teacher_name' => $user->name,
                'reason' => $reason,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Öğretmen başvurusu reddedildi',
            'teacher' => $user->fresh()->load('teacher'),
        ]);
    }

    /**
     * @OA\Get(
     *     path="/admin/reservations",
     *     tags={"Admin"},
     *     summary="Tüm rezervasyonları listele",
     *     description="Admin paneli için rezervasyon listesini getirir",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="status",
     *         in="query",
     *         @OA\Schema(type="string", enum={"pending", "confirmed", "in_progress", "completed", "cancelled"})
     *     ),
     *     @OA\Parameter(
     *         name="page",
     *         in="query",
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Rezervasyon listesi başarıyla getirildi"
     *     )
     * )
     */
    public function getReservations(Request $request): JsonResponse
    {
        $query = Reservation::with(['student', 'teacher', 'category']);

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        $perPage = $request->get('per_page', 20);
        $reservations = $query->orderBy('created_at', 'desc')
            ->paginate($perPage);

        return response()->json([
            'success' => true,
            'reservations' => $reservations->items(),
            'pagination' => [
                'current_page' => $reservations->currentPage(),
                'last_page' => $reservations->lastPage(),
                'per_page' => $reservations->perPage(),
                'total' => $reservations->total(),
            ],
        ]);
    }

    /**
     * @OA\Post(
     *     path="/admin/notifications/send",
     *     tags={"Admin"},
     *     summary="Toplu bildirim gönder",
     *     description="Admin paneli için toplu bildirim gönderir",
     *     security={{"bearerAuth":{}}},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             @OA\Property(property="title", type="string"),
     *             @OA\Property(property="message", type="string"),
     *             @OA\Property(property="target_users", type="array", @OA\Items(type="string", enum={"all", "students", "teachers"})),
     *             @OA\Property(property="type", type="string", enum={"info", "warning", "success", "error"})
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Bildirim başarıyla gönderildi"
     *     )
     * )
     */
    public function sendNotification(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'title' => 'required|string|max:255',
            'message' => 'required|string|max:1000',
            'target_users' => 'required|array',
            'target_users.*' => 'in:all,students,teachers',
            'type' => 'required|in:info,warning,success,error',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $targetUsers = $request->target_users;
        $userQuery = User::query();

        if (!in_array('all', $targetUsers)) {
            $userQuery->whereIn('role', $targetUsers);
        }

        $users = $userQuery->get();

        $notifications = [];
        foreach ($users as $user) {
            $notifications[] = [
                'user_id' => $user->id,
                'title' => $request->title,
                'message' => $request->message,
                'type' => $request->type,
                'data' => json_encode(['admin_notification' => true]),
                'created_at' => now(),
                'updated_at' => now(),
            ];
        }

        \DB::table('notifications')->insert($notifications);

        // Audit log
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'bulk_notification_sent',
            'target_type' => 'notification',
            'target_id' => null,
            'details' => [
                'title' => $request->title,
                'target_users' => $targetUsers,
                'user_count' => count($users),
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Bildirim başarıyla gönderildi',
            'sent_count' => count($users),
        ]);
    }
}
