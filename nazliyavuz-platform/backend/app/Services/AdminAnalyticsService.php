<?php

namespace App\Services;

use App\Models\User;
use App\Models\Reservation;
use App\Models\Category;
use App\Models\AuditLog;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Cache;

class AdminAnalyticsService
{
    protected $cacheTimeout = 300; // 5 minutes

    /**
     * Get comprehensive dashboard statistics
     */
    public function getDashboardStats(): array
    {
        return Cache::remember('admin_dashboard_stats', $this->cacheTimeout, function () {
            return [
                'users' => $this->getUserStats(),
                'reservations' => $this->getReservationStats(),
                'revenue' => $this->getRevenueStats(),
                'growth' => $this->getGrowthStats(),
                'performance' => $this->getPerformanceStats(),
            ];
        });
    }

    /**
     * Get user segmentation analytics
     *
     * @param array<string, mixed> $filters
     */
    public function getUserSegmentation(array $filters = []): array
    {
        $baseQuery = User::query();

        if (!empty($filters['role'])) {
            $baseQuery->where('role', $filters['role']);
        }

        if (!empty($filters['status'])) {
            $baseQuery->where('status', $filters['status']);
        }

        $now = now();
        $date7 = $now->copy()->subDays(7);
        $date30 = $now->copy()->subDays(30);
        $date60 = $now->copy()->subDays(60);
        $date90 = $now->copy()->subDays(90);

        $totalUsers = (clone $baseQuery)->count();
        $studentsCount = (clone $baseQuery)->where('role', 'student')->count();
        $teachersCount = (clone $baseQuery)->where('role', 'teacher')->count();
        $adminsCount = (clone $baseQuery)->where('role', 'admin')->count();
        $newUsers30 = (clone $baseQuery)->where('created_at', '>=', $date30)->count();
        $activeLast7 = (clone $baseQuery)
            ->whereNotNull('last_login_at')
            ->where('last_login_at', '>=', $date7)
            ->count();

        $roleCounts = (clone $baseQuery)
            ->select('role', DB::raw('COUNT(*) as count'))
            ->groupBy('role')
            ->get();

        $roleNewCounts = (clone $baseQuery)
            ->select('role', DB::raw('COUNT(*) as count'))
            ->where('created_at', '>=', $date30)
            ->groupBy('role')
            ->pluck('count', 'role');

        $roleDistribution = $roleCounts
            ->map(function ($item) use ($totalUsers, $roleNewCounts) {
                $role = $item->role ?? 'unknown';
                $count = (int) $item->count;
                $percentage = $totalUsers > 0 ? round(($count / $totalUsers) * 100, 2) : 0;
                $growth = (float) ($roleNewCounts[$role] ?? 0);

                return [
                    'role' => $role,
                    'count' => $count,
                    'percentage' => $percentage,
                    'growth_30d' => $growth,
                ];
            })
            ->values()
            ->toArray();

        $teacherBase = User::query()->where('role', 'teacher');
        if (!empty($filters['status'])) {
            $teacherBase->where('status', $filters['status']);
        }

        $teacherStatus = (clone $teacherBase)
            ->select(DB::raw('COALESCE(teacher_status, "unknown") as status'), DB::raw('COUNT(*) as count'))
            ->groupBy('status')
            ->get()
            ->map(function ($item) use ($teachersCount) {
                $count = (int) $item->count;

                return [
                    'status' => $item->status,
                    'count' => $count,
                    'percentage' => $teachersCount > 0 ? round(($count / $teachersCount) * 100, 2) : 0,
                ];
            })
            ->values()
            ->toArray();

        $studentReservations = DB::table('reservations')
            ->select('student_id', DB::raw('COUNT(*) as total'))
            ->groupBy('student_id');

        $studentActivityBase = DB::table('users as u')
            ->leftJoinSub($studentReservations, 'sr', 'sr.student_id', '=', 'u.id')
            ->where('u.role', 'student');

        if (!empty($filters['status'])) {
            $studentActivityBase->where('u.status', $filters['status']);
        }

        $noReservationCount = (clone $studentActivityBase)->whereNull('sr.total')->count();
        $oneToThreeCount = (clone $studentActivityBase)->whereBetween('sr.total', [1, 3])->count();
        $fourToNineCount = (clone $studentActivityBase)->whereBetween('sr.total', [4, 9])->count();
        $tenPlusCount = (clone $studentActivityBase)->where('sr.total', '>=', 10)->count();

        $studentActivity = [
            [
                'segment' => 'none',
                'label' => 'Rezervasyon yapmamış',
                'count' => $noReservationCount,
                'percentage' => $studentsCount > 0 ? round(($noReservationCount / $studentsCount) * 100, 2) : 0,
            ],
            [
                'segment' => 'beginner',
                'label' => '1-3 rezervasyon',
                'count' => $oneToThreeCount,
                'percentage' => $studentsCount > 0 ? round(($oneToThreeCount / $studentsCount) * 100, 2) : 0,
            ],
            [
                'segment' => 'engaged',
                'label' => '4-9 rezervasyon',
                'count' => $fourToNineCount,
                'percentage' => $studentsCount > 0 ? round(($fourToNineCount / $studentsCount) * 100, 2) : 0,
            ],
            [
                'segment' => 'loyal',
                'label' => '10+ rezervasyon',
                'count' => $tenPlusCount,
                'percentage' => $studentsCount > 0 ? round(($tenPlusCount / $studentsCount) * 100, 2) : 0,
            ],
        ];

        $studentsBase = User::query()->where('role', 'student');
        if (!empty($filters['status'])) {
            $studentsBase->where('status', $filters['status']);
        }

        $studentsActive7 = (clone $studentsBase)
            ->whereNotNull('last_login_at')
            ->where('last_login_at', '>=', $date7)
            ->count();
        $studentsInactive30 = (clone $studentsBase)
            ->where(function ($query) use ($date30) {
                $query->whereNull('last_login_at')
                    ->orWhere('last_login_at', '<', $date30);
            })
            ->count();
        $studentsInactive60 = (clone $studentsBase)
            ->where(function ($query) use ($date60) {
                $query->whereNull('last_login_at')
                    ->orWhere('last_login_at', '<', $date60);
            })
            ->count();
        $studentsInactive90 = (clone $studentsBase)
            ->where(function ($query) use ($date90) {
                $query->whereNull('last_login_at')
                    ->orWhere('last_login_at', '<', $date90);
            })
            ->count();

        $teachersActive7 = (clone $teacherBase)
            ->whereNotNull('last_login_at')
            ->where('last_login_at', '>=', $date7)
            ->count();
        $teachersInactive30 = (clone $teacherBase)
            ->where(function ($query) use ($date30) {
                $query->whereNull('last_login_at')
                    ->orWhere('last_login_at', '<', $date30);
            })
            ->count();
        $teachersInactive90 = (clone $teacherBase)
            ->where(function ($query) use ($date90) {
                $query->whereNull('last_login_at')
                    ->orWhere('last_login_at', '<', $date90);
            })
            ->count();

        $retention = [
            'students' => [
                [
                    'segment' => 'active_7',
                    'label' => 'Son 7 gün içinde aktif',
                    'count' => $studentsActive7,
                    'percentage' => $studentsCount > 0 ? round(($studentsActive7 / $studentsCount) * 100, 2) : 0,
                ],
                [
                    'segment' => 'inactive_30',
                    'label' => '30+ gündür pasif',
                    'count' => $studentsInactive30,
                    'percentage' => $studentsCount > 0 ? round(($studentsInactive30 / $studentsCount) * 100, 2) : 0,
                ],
                [
                    'segment' => 'inactive_60',
                    'label' => '60+ gündür pasif',
                    'count' => $studentsInactive60,
                    'percentage' => $studentsCount > 0 ? round(($studentsInactive60 / $studentsCount) * 100, 2) : 0,
                ],
                [
                    'segment' => 'inactive_90',
                    'label' => '90+ gündür pasif',
                    'count' => $studentsInactive90,
                    'percentage' => $studentsCount > 0 ? round(($studentsInactive90 / $studentsCount) * 100, 2) : 0,
                ],
            ],
            'teachers' => [
                [
                    'segment' => 'active_7',
                    'label' => 'Son 7 gün içinde aktif',
                    'count' => $teachersActive7,
                    'percentage' => $teachersCount > 0 ? round(($teachersActive7 / $teachersCount) * 100, 2) : 0,
                ],
                [
                    'segment' => 'inactive_30',
                    'label' => '30+ gündür pasif',
                    'count' => $teachersInactive30,
                    'percentage' => $teachersCount > 0 ? round(($teachersInactive30 / $teachersCount) * 100, 2) : 0,
                ],
                [
                    'segment' => 'inactive_90',
                    'label' => '90+ gündür pasif',
                    'count' => $teachersInactive90,
                    'percentage' => $teachersCount > 0 ? round(($teachersInactive90 / $teachersCount) * 100, 2) : 0,
                ],
            ],
        ];

        $marketing = [];
        $emailOptIn = (clone $baseQuery)->where('email_notifications', 1)->count();
        $pushOptIn = (clone $baseQuery)->where('push_notifications', 1)->count();
        $marketingOptIn = (clone $baseQuery)->where('marketing_emails', 1)->count();

        $marketing[] = [
            'key' => 'email_notifications',
            'label' => 'E-posta bildirimleri açık',
            'count' => $emailOptIn,
            'percentage' => $totalUsers > 0 ? round(($emailOptIn / $totalUsers) * 100, 2) : 0,
        ];

        $marketing[] = [
            'key' => 'push_notifications',
            'label' => 'Push bildirimleri açık',
            'count' => $pushOptIn,
            'percentage' => $totalUsers > 0 ? round(($pushOptIn / $totalUsers) * 100, 2) : 0,
        ];

        $marketing[] = [
            'key' => 'marketing_opt_in',
            'label' => 'Pazarlama e-postalarına izin vermiş',
            'count' => $marketingOptIn,
            'percentage' => $totalUsers > 0 ? round(($marketingOptIn / $totalUsers) * 100, 2) : 0,
        ];

        $cohorts = [];
        for ($i = 5; $i >= 0; $i--) {
            $startOfWeek = Carbon::now()->startOfWeek()->subWeeks($i);
            $endOfWeek = $startOfWeek->copy()->endOfWeek();

            $cohorts[] = [
                'label' => $startOfWeek->format('d M') . ' - ' . $endOfWeek->format('d M'),
                'students' => User::where('role', 'student')
                    ->whereBetween('created_at', [$startOfWeek, $endOfWeek])
                    ->count(),
                'teachers' => User::where('role', 'teacher')
                    ->whereBetween('created_at', [$startOfWeek, $endOfWeek])
                    ->count(),
            ];
        }

        $studentResRecent = DB::table('reservations')
            ->select('student_id', DB::raw('COUNT(*) as total'))
            ->where('created_at', '>=', $date30)
            ->groupBy('student_id');

        $repeatStudents30 = DB::table('users as u')
            ->joinSub($studentResRecent, 'sr', 'sr.student_id', '=', 'u.id')
            ->where('u.role', 'student')
            ->where('sr.total', '>=', 2)
            ->count();

        $teacherReservations = DB::table('reservations')
            ->select('teacher_id', DB::raw('COUNT(*) as total'))
            ->groupBy('teacher_id');

        $highLoadTeachers = DB::table('users as u')
            ->joinSub($teacherReservations, 'tr', 'tr.teacher_id', '=', 'u.id')
            ->where('u.role', 'teacher')
            ->where('tr.total', '>=', 40)
            ->count();

        $highValueStudents = $tenPlusCount;
        $pendingTeachers = User::where('role', 'teacher')->where('teacher_status', 'pending')->count();

        $topCategories = DB::table('categories')
            ->join('reservations', 'categories.id', '=', 'reservations.category_id')
            ->select('categories.name', DB::raw('COUNT(reservations.id) as count'))
            ->groupBy('categories.id', 'categories.name')
            ->orderByDesc('count')
            ->limit(5)
            ->get()
            ->map(function ($item) {
                return [
                    'name' => $item->name,
                    'count' => (int) $item->count,
                ];
            })
            ->toArray();

        $focus = [
            [
                'key' => 'high_value_students',
                'label' => '10+ ders alan öğrenciler',
                'value' => $highValueStudents,
                'description' => 'Sadık öğrenci segmenti',
            ],
            [
                'key' => 'repeat_students_30',
                'label' => 'Son 30 günde tekrar rezervasyon yapan öğrenciler (2+)',
                'value' => $repeatStudents30,
                'description' => 'Tekrar rezervasyon yapan öğrenciler',
            ],
            [
                'key' => 'pending_teachers',
                'label' => 'Onay bekleyen öğretmenler',
                'value' => $pendingTeachers,
                'description' => 'Hızlı aksiyon gerektiren kayıtlar',
            ],
            [
                'key' => 'high_load_teachers',
                'label' => '40+ ders veren öğretmenler',
                'value' => $highLoadTeachers,
                'description' => 'Yoğun takvimli öğretmenler',
            ],
        ];

        return [
            'totals' => [
                'total_users' => $totalUsers,
                'students' => $studentsCount,
                'teachers' => $teachersCount,
                'admins' => $adminsCount,
                'new_last_30_days' => $newUsers30,
                'active_last_7_days' => $activeLast7,
            ],
            'role_distribution' => $roleDistribution,
            'teacher_status' => $teacherStatus,
            'student_activity' => $studentActivity,
            'retention' => $retention,
            'marketing' => $marketing,
            'cohorts' => $cohorts,
            'focus' => $focus,
            'top_categories' => $topCategories,
        ];
    }

    /**
     * Get user statistics
     */
    private function getUserStats(): array
    {
        $totalUsers = User::count();
        $activeUsers = User::where('status', 'active')->count();
        $suspendedUsers = User::where('status', 'suspended')->count();
        $teachers = User::where('role', 'teacher')->count();
        $students = User::where('role', 'student')->count();
        $pendingTeachers = User::where('role', 'teacher')
            ->where('teacher_status', 'pending')
            ->count();

        return [
            'total' => $totalUsers,
            'active' => $activeUsers,
            'suspended' => $suspendedUsers,
            'teachers' => $teachers,
            'students' => $students,
            'pending_teachers' => $pendingTeachers,
            'active_percentage' => $totalUsers > 0 ? round(($activeUsers / $totalUsers) * 100, 2) : 0,
        ];
    }

    /**
     * Get reservation statistics
     */
    private function getReservationStats(): array
    {
        $totalReservations = Reservation::count();
        $pendingReservations = Reservation::where('status', 'pending')->count();
        $confirmedReservations = Reservation::where('status', 'confirmed')->count();
        $completedReservations = Reservation::where('status', 'completed')->count();
        $cancelledReservations = Reservation::where('status', 'cancelled')->count();

        return [
            'total' => $totalReservations,
            'pending' => $pendingReservations,
            'confirmed' => $confirmedReservations,
            'completed' => $completedReservations,
            'cancelled' => $cancelledReservations,
            'completion_rate' => $totalReservations > 0 ? round(($completedReservations / $totalReservations) * 100, 2) : 0,
        ];
    }

    /**
     * Get revenue statistics
     */
    private function getRevenueStats(): array
    {
        $totalRevenue = Reservation::where('status', 'completed')->sum('price') ?? 0;
        $monthlyRevenue = Reservation::where('status', 'completed')
            ->where('created_at', '>=', now()->subMonth())
            ->sum('price') ?? 0;
        $weeklyRevenue = Reservation::where('status', 'completed')
            ->where('created_at', '>=', now()->subWeek())
            ->sum('price') ?? 0;
        $dailyRevenue = Reservation::where('status', 'completed')
            ->whereDate('created_at', today())
            ->sum('price') ?? 0;

        return [
            'total' => $totalRevenue,
            'monthly' => $monthlyRevenue,
            'weekly' => $weeklyRevenue,
            'daily' => $dailyRevenue,
            'average_per_reservation' => $this->getAverageRevenuePerReservation(),
        ];
    }

    /**
     * Get growth statistics
     */
    private function getGrowthStats(): array
    {
        $userGrowth = $this->getUserGrowthData();
        $reservationGrowth = $this->getReservationGrowthData();
        $revenueGrowth = $this->getRevenueGrowthData();

        return [
            'users' => $userGrowth,
            'reservations' => $reservationGrowth,
            'revenue' => $revenueGrowth,
        ];
    }

    /**
     * Get performance statistics
     */
    private function getPerformanceStats(): array
    {
        $topTeachers = $this->getTopTeachers();
        $categoryStats = $this->getCategoryStats();
        $recentActivities = $this->getRecentActivities();

        return [
            'top_teachers' => $topTeachers,
            'categories' => $categoryStats,
            'recent_activities' => $recentActivities,
        ];
    }

    /**
     * Get user growth data for the last 12 months
     */
    private function getUserGrowthData(): array
    {
        $data = [];
        for ($i = 11; $i >= 0; $i--) {
            $date = now()->subMonths($i);
            $data[] = [
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
        return $data;
    }

    /**
     * Get reservation growth data for the last 30 days
     */
    private function getReservationGrowthData(): array
    {
        $data = [];
        for ($i = 29; $i >= 0; $i--) {
            $date = now()->subDays($i);
            $data[] = [
                'date' => $date->format('Y-m-d'),
                'reservations' => Reservation::whereDate('created_at', $date)->count(),
                'completed' => Reservation::where('status', 'completed')
                    ->whereDate('created_at', $date)
                    ->count(),
            ];
        }
        return $data;
    }

    /**
     * Get revenue growth data for the last 30 days
     */
    private function getRevenueGrowthData(): array
    {
        $data = [];
        for ($i = 29; $i >= 0; $i--) {
            $date = now()->subDays($i);
            $data[] = [
                'date' => $date->format('Y-m-d'),
                'revenue' => Reservation::where('status', 'completed')
                    ->whereDate('created_at', $date)
                    ->sum('price') ?? 0,
            ];
        }
        return $data;
    }

    /**
     * Get top performing teachers
     */
    private function getTopTeachers(): array
    {
        $baseQuery = DB::table('users')
            ->join('teachers', 'users.id', '=', 'teachers.user_id')
            ->leftJoin('reservations', function ($join) {
                $join->on('users.id', '=', 'reservations.teacher_id')
                    ->where('reservations.status', '=', 'completed');
            })
            ->leftJoin('lessons', function ($join) {
                $join->on('reservations.id', '=', 'lessons.reservation_id');
            })
            ->selectRaw('
                users.id,
                users.name,
                users.email,
                teachers.rating_avg,
                teachers.rating_count,
                COUNT(DISTINCT reservations.id) as total_lessons,
                COUNT(DISTINCT reservations.student_id) as unique_students,
                COALESCE(SUM(reservations.price), 0) as total_revenue,
                MIN(reservations.created_at) as first_reservation_at,
                MAX(reservations.created_at) as last_reservation_at,
                SUM(CASE WHEN reservations.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY) THEN 1 ELSE 0 END) as lessons_last_30_days,
                SUM(CASE WHEN reservations.created_at >= DATE_SUB(NOW(), INTERVAL 90 DAY) THEN 1 ELSE 0 END) as lessons_last_90_days,
                COUNT(DISTINCT CASE WHEN lessons.status = \'cancelled\' THEN lessons.id END) as cancellations,
                SUM(CASE WHEN reservations.rating IS NOT NULL THEN 1 ELSE 0 END) as rated_lessons,
                AVG(reservations.rating) as average_lesson_rating
            ')
            ->where('users.role', 'teacher')
            ->where('users.teacher_status', 'approved')
            ->groupBy('users.id', 'users.name', 'users.email', 'teachers.rating_avg', 'teachers.rating_count')
            ->havingRaw('total_lessons > 0');

        $topTeachersRaw = $baseQuery
            ->orderByDesc('total_revenue')
            ->orderByDesc('total_lessons')
            ->limit(50)
            ->get();

        return $topTeachersRaw->map(function ($row) {
            $firstReservation = $row->first_reservation_at ? Carbon::parse($row->first_reservation_at) : null;
            $lastReservation = $row->last_reservation_at ? Carbon::parse($row->last_reservation_at) : null;
            $activeDays = ($firstReservation && $lastReservation)
                ? max($firstReservation->diffInDays($lastReservation) + 1, 1)
                : null;

            $totalLessons = (int) $row->total_lessons;
            $lessonsLast30 = (int) $row->lessons_last_30_days;
            $lessonsLast90 = (int) $row->lessons_last_90_days;
            $cancellations = (int) $row->cancellations;

            $activityTrend = $lessonsLast90 > 0
                ? round((($lessonsLast30 / max($lessonsLast90, 1 / 3)) * 3 - 1) * 100, 2)
                : null;

            $loadFactor = $activeDays && $activeDays > 0
                ? round($totalLessons / $activeDays, 3)
                : 0;

            $cancellationRate = $totalLessons > 0
                ? round(($cancellations / $totalLessons) * 100, 2)
                : 0;

            $ratedLessons = (int) ($row->rated_lessons ?? 0);
            $averageLessonRating = $ratedLessons > 0
                ? round((float) ($row->average_lesson_rating ?? 0), 2)
                : null;

            return [
                'id' => $row->id,
                'name' => $row->name,
                'email' => $row->email,
                'rating_avg' => round((float) ($row->rating_avg ?? 0), 2),
                'rating_count' => (int) ($row->rating_count ?? 0),
                'average_rating_per_lesson' => $averageLessonRating,
                'rated_lessons' => $ratedLessons,
                'total_lessons' => $totalLessons,
                'lessons_last_30_days' => $lessonsLast30,
                'lessons_last_90_days' => $lessonsLast90,
                'activity_trend_30_vs_90' => $activityTrend,
                'unique_students' => (int) $row->unique_students,
                'total_revenue' => round((float) $row->total_revenue, 2),
                'average_revenue_per_lesson' => $totalLessons > 0
                    ? round((float) $row->total_revenue / $totalLessons, 2)
                    : 0,
                'first_reservation_at' => $firstReservation?->toIso8601String(),
                'last_reservation_at' => $lastReservation?->toIso8601String(),
                'active_days' => $activeDays,
                'lessons_per_active_day' => $loadFactor,
                'cancellations' => $cancellations,
                'cancellation_rate' => $cancellationRate,
                'ranking_score' => $this->calculateTeacherScore($row),
            ];
        })
            ->sortByDesc('ranking_score')
            ->take(15)
            ->values()
            ->toArray();
    }

    public function getTeacherBenchmark(): array
    {
        $approvedTeachers = User::query()
            ->where('role', 'teacher')
            ->where('teacher_status', 'approved');

        $totalTeachers = (clone $approvedTeachers)->count();
        $active7 = (clone $approvedTeachers)
            ->whereNotNull('last_login_at')
            ->where('last_login_at', '>=', now()->subDays(7))
            ->count();
        $active30 = (clone $approvedTeachers)
            ->whereNotNull('last_login_at')
            ->where('last_login_at', '>=', now()->subDays(30))
            ->count();

        $totalLessons = Reservation::where('status', 'completed')->count();
        $totalRevenue = (float) (Reservation::where('status', 'completed')->sum('price') ?? 0);
        $avgRating = (float) DB::table('teachers')->whereNotNull('rating_avg')->avg('rating_avg');

        $topTeachers = $this->getTopTeachers();

        $ratingDistribution = DB::table('teachers')
            ->selectRaw('ROUND(COALESCE(rating_avg, 0)) as bucket, COUNT(*) as count')
            ->groupBy('bucket')
            ->orderBy('bucket')
            ->get()
            ->map(function ($item) use ($totalTeachers) {
                $bucket = (int) $item->bucket;
                $count = (int) $item->count;

                return [
                    'bucket' => $bucket,
                    'count' => $count,
                    'percentage' => $totalTeachers > 0 ? round(($count / $totalTeachers) * 100, 2) : 0,
                    'label' => "{$bucket}★",
                ];
            })
            ->values()
            ->toArray();

        $lessonCounts = DB::table('reservations')
            ->select('teacher_id', DB::raw('COUNT(*) as total'))
            ->where('status', 'completed')
            ->groupBy('teacher_id');

        $workloadDistribution = DB::query()
            ->fromSub($lessonCounts, 'lc')
            ->selectRaw('
                CASE
                    WHEN total >= 60 THEN "60+"
                    WHEN total >= 40 THEN "40-59"
                    WHEN total >= 20 THEN "20-39"
                    WHEN total >= 10 THEN "10-19"
                    WHEN total >= 1 THEN "1-9"
                    ELSE "0"
                END as bucket,
                COUNT(*) as count
            ')
            ->groupBy('bucket')
            ->orderByRaw('MIN(total) DESC')
            ->get()
            ->map(function ($item) use ($totalTeachers) {
                return [
                    'bucket' => $item->bucket,
                    'count' => (int) $item->count,
                    'percentage' => $totalTeachers > 0 ? round(((int) $item->count / $totalTeachers) * 100, 2) : 0,
                ];
            })
            ->values()
            ->toArray();

        $recentLessons = Reservation::query()
            ->select('teacher_id', DB::raw('COUNT(*) as total'))
            ->where('status', 'completed')
            ->where('created_at', '>=', now()->subDays(30))
            ->groupBy('teacher_id');

        $activityDistribution = DB::query()
            ->fromSub($recentLessons, 'rl')
            ->selectRaw('
                CASE
                    WHEN total >= 15 THEN "15+"
                    WHEN total >= 8 THEN "8-14"
                    WHEN total >= 4 THEN "4-7"
                    WHEN total >= 1 THEN "1-3"
                    ELSE "0"
                END as bucket,
                COUNT(*) as count
            ')
            ->groupBy('bucket')
            ->orderByRaw('MIN(total) DESC')
            ->get()
            ->map(function ($item) use ($totalTeachers) {
                return [
                    'bucket' => $item->bucket,
                    'count' => (int) $item->count,
                    'percentage' => $totalTeachers > 0 ? round(((int) $item->count / $totalTeachers) * 100, 2) : 0,
                ];
            })
            ->values()
            ->toArray();

        $emergingTeachers = collect($topTeachers)
            ->filter(function ($teacher) {
                return ($teacher['lessons_last_90_days'] ?? 0) >= 6
                    && ($teacher['activity_trend_30_vs_90'] ?? 0) >= 20;
            })
            ->sortByDesc('activity_trend_30_vs_90')
            ->take(5)
            ->values()
            ->toArray();

        $attentionTeachers = collect($topTeachers)
            ->filter(function ($teacher) {
                return ($teacher['total_lessons'] ?? 0) >= 10
                    && ($teacher['cancellation_rate'] ?? 0) >= 10;
            })
            ->sortByDesc('cancellation_rate')
            ->take(5)
            ->values()
            ->toArray();

        return [
            'summary' => [
                'total_teachers' => $totalTeachers,
                'active_7_days' => $active7,
                'active_30_days' => $active30,
                'average_rating' => round($avgRating, 2),
                'average_lessons_per_teacher' => $totalTeachers > 0 ? round($totalLessons / $totalTeachers, 2) : 0,
                'average_revenue_per_teacher' => $totalTeachers > 0 ? round($totalRevenue / $totalTeachers, 2) : 0,
                'total_revenue' => round($totalRevenue, 2),
            ],
            'leaders' => [
                'top_performers' => array_slice($topTeachers, 0, 5),
                'emerging' => $emergingTeachers,
                'attention' => $attentionTeachers,
            ],
            'distribution' => [
                'ratings' => $ratingDistribution,
                'workload' => $workloadDistribution,
                'activity' => $activityDistribution,
            ],
        ];
    }

    private function calculateTeacherScore($row): float
    {
        $totalLessons = (int) $row->total_lessons;
        $uniqueStudents = (int) $row->unique_students;
        $totalRevenue = (float) $row->total_revenue;
        $ratingAvg = (float) ($row->rating_avg ?? 0);
        $ratingCount = (int) ($row->rating_count ?? 0);
        $lessonsLast30 = (int) $row->lessons_last_30_days;
        $lessonsLast90 = (int) $row->lessons_last_90_days;
        $cancellations = (int) $row->cancellations;

        $revenueScore = $totalRevenue / 1000;
        $lessonScore = $totalLessons * 2;
        $engagementScore = $uniqueStudents * 1.5;
        $ratingWeight = min($ratingCount / 10, 1);
        $ratingScore = ($ratingAvg / 5) * 150 * $ratingWeight;
        $cancellationPenalty = $totalLessons > 0 ? ($cancellations / $totalLessons) * 120 : 0;
        $trendScore = $lessonsLast90 > 0
            ? (($lessonsLast30 - ($lessonsLast90 / 3)) / max($lessonsLast90 / 3, 1)) * 50
            : 0;

        return round(
            max(
                $revenueScore + $lessonScore + $engagementScore + $ratingScore + $trendScore - $cancellationPenalty,
                0
            ),
            2
        );
    }

    /**
     * Get category statistics
     */
    private function getCategoryStats(): array
    {
        return Category::withCount('reservations')
            ->orderBy('reservations_count', 'desc')
            ->limit(10)
            ->get()
            ->map(function ($category) {
                return [
                    'id' => $category->id,
                    'name' => $category->name,
                    'reservations_count' => $category->reservations_count ?? 0,
                ];
            })
            ->toArray();
    }

    /**
     * Get recent activities
     */
    private function getRecentActivities(): array
    {
        return AuditLog::with('user')
            ->orderBy('created_at', 'desc')
            ->limit(20)
            ->get()
            ->map(function ($log) {
                return [
                    'id' => $log->id,
                    'action' => $log->action,
                    'description' => $log->description,
                    'user_name' => $log->user->name ?? 'Sistem',
                    'created_at' => $log->created_at,
                ];
            })
            ->toArray();
    }

    /**
     * Get average revenue per reservation
     */
    private function getAverageRevenuePerReservation(): float
    {
        $completedReservations = Reservation::where('status', 'completed')->count();
        $totalRevenue = Reservation::where('status', 'completed')->sum('price') ?? 0;
        
        return $completedReservations > 0 ? round($totalRevenue / $completedReservations, 2) : 0;
    }

    /**
     * Clear analytics cache
     */
    public function clearCache(): void
    {
        Cache::forget('admin_dashboard_stats');
    }

    /**
     * Get real-time statistics (not cached)
     */
    public function getRealTimeStats(): array
    {
        return [
            'online_users' => $this->getOnlineUsersCount(),
            'pending_approvals' => $this->getPendingApprovalsCount(),
            'system_health' => $this->getSystemHealthStatus(),
        ];
    }

    /**
     * Get online users count (simplified implementation)
     */
    private function getOnlineUsersCount(): int
    {
        // This would typically check a sessions table or cache
        // For now, return a placeholder
        return User::where('last_activity_at', '>=', now()->subMinutes(15))->count();
    }

    /**
     * Get pending approvals count
     */
    private function getPendingApprovalsCount(): int
    {
        return User::where('role', 'teacher')
            ->where('teacher_status', 'pending')
            ->count();
    }

    /**
     * Get system health status
     */
    private function getSystemHealthStatus(): array
    {
        return [
            'database' => $this->checkDatabaseHealth(),
            'cache' => $this->checkCacheHealth(),
            'storage' => $this->checkStorageHealth(),
        ];
    }

    /**
     * Check database health
     */
    private function checkDatabaseHealth(): bool
    {
        try {
            DB::connection()->getPdo();
            return true;
        } catch (\Exception $e) {
            return false;
        }
    }

    /**
     * Check cache health
     */
    private function checkCacheHealth(): bool
    {
        try {
            Cache::put('health_check', 'ok', 1);
            return Cache::get('health_check') === 'ok';
        } catch (\Exception $e) {
            return false;
        }
    }

    /**
     * Check storage health
     */
    private function checkStorageHealth(): bool
    {
        try {
            return is_writable(storage_path());
        } catch (\Exception $e) {
            return false;
        }
    }
}
