<?php

namespace App\Services;

use App\Models\User;
use App\Models\Reservation;
use App\Models\Category;
use App\Models\AuditLog;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Cache;
use Carbon\Carbon;

class AdminReportService
{
    protected $cacheTimeout = 600; // 10 minutes

    /**
     * Generate comprehensive system report
     */
    public function generateSystemReport(array $filters = []): array
    {
        $cacheKey = 'admin_system_report_' . md5(serialize($filters));
        
        return Cache::remember($cacheKey, $this->cacheTimeout, function () use ($filters) {
            return [
                'summary' => $this->getSystemSummary($filters),
                'users' => $this->getUserReport($filters),
                'reservations' => $this->getReservationReport($filters),
                'revenue' => $this->getRevenueReport($filters),
                'performance' => $this->getPerformanceReport($filters),
                'security' => $this->getSecurityReport($filters),
                'generated_at' => now()->toISOString(),
            ];
        });
    }

    /**
     * Get system summary
     */
    private function getSystemSummary(array $filters): array
    {
        $dateFrom = $filters['date_from'] ?? now()->subMonth();
        $dateTo = $filters['date_to'] ?? now();

        return [
            'total_users' => User::count(),
            'active_users' => User::where('status', 'active')->count(),
            'new_users_period' => User::whereBetween('created_at', [$dateFrom, $dateTo])->count(),
            'total_reservations' => Reservation::count(),
            'completed_reservations' => Reservation::where('status', 'completed')->count(),
            'total_revenue' => Reservation::where('status', 'completed')->sum('price') ?? 0,
            'period_revenue' => Reservation::where('status', 'completed')
                ->whereBetween('created_at', [$dateFrom, $dateTo])
                ->sum('price') ?? 0,
            'system_uptime' => $this->getSystemUptime(),
            'last_backup' => $this->getLastBackupDate(),
        ];
    }

    /**
     * Get user report
     */
    private function getUserReport(array $filters): array
    {
        $dateFrom = $filters['date_from'] ?? now()->subMonth();
        $dateTo = $filters['date_to'] ?? now();

        $userGrowth = $this->getUserGrowthData($dateFrom, $dateTo);
        $userDistribution = $this->getUserDistribution();
        $userActivity = $this->getUserActivityData($dateFrom, $dateTo);

        return [
            'growth' => $userGrowth,
            'distribution' => $userDistribution,
            'activity' => $userActivity,
            'retention' => $this->getUserRetentionRate($dateFrom, $dateTo),
        ];
    }

    /**
     * Get reservation report
     */
    private function getReservationReport(array $filters): array
    {
        $dateFrom = $filters['date_from'] ?? now()->subMonth();
        $dateTo = $filters['date_to'] ?? now();

        return [
            'trends' => $this->getReservationTrends($dateFrom, $dateTo),
            'status_distribution' => $this->getReservationStatusDistribution($dateFrom, $dateTo),
            'category_analysis' => $this->getReservationCategoryAnalysis($dateFrom, $dateTo),
            'completion_rate' => $this->getReservationCompletionRate($dateFrom, $dateTo),
            'average_duration' => $this->getAverageReservationDuration($dateFrom, $dateTo),
        ];
    }

    /**
     * Get revenue report
     */
    private function getRevenueReport(array $filters): array
    {
        $dateFrom = $filters['date_from'] ?? now()->subMonth();
        $dateTo = $filters['date_to'] ?? now();

        return [
            'total_revenue' => $this->getTotalRevenue(),
            'period_revenue' => $this->getPeriodRevenue($dateFrom, $dateTo),
            'revenue_trends' => $this->getRevenueTrends($dateFrom, $dateTo),
            'revenue_by_category' => $this->getRevenueByCategory($dateFrom, $dateTo),
            'revenue_by_teacher' => $this->getRevenueByTeacher($dateFrom, $dateTo),
            'average_revenue_per_reservation' => $this->getAverageRevenuePerReservation($dateFrom, $dateTo),
        ];
    }

    /**
     * Get performance report
     */
    private function getPerformanceReport(array $filters): array
    {
        $dateFrom = $filters['date_from'] ?? now()->subMonth();
        $dateTo = $filters['date_to'] ?? now();

        return [
            'top_teachers' => $this->getTopTeachers($dateFrom, $dateTo),
            'top_categories' => $this->getTopCategories($dateFrom, $dateTo),
            'system_performance' => $this->getSystemPerformanceMetrics(),
            'response_times' => $this->getResponseTimeMetrics($dateFrom, $dateTo),
        ];
    }

    /**
     * Get security report
     */
    private function getSecurityReport(array $filters): array
    {
        $dateFrom = $filters['date_from'] ?? now()->subMonth();
        $dateTo = $filters['date_to'] ?? now();

        return [
            'login_attempts' => $this->getLoginAttempts($dateFrom, $dateTo),
            'suspicious_activities' => $this->getSuspiciousActivities($dateFrom, $dateTo),
            'security_events' => $this->getSecurityEvents($dateFrom, $dateTo),
            'user_suspensions' => $this->getUserSuspensions($dateFrom, $dateTo),
        ];
    }

    /**
     * Get user growth data
     */
    private function getUserGrowthData(Carbon $dateFrom, Carbon $dateTo): array
    {
        $data = [];
        $current = $dateFrom->copy();
        
        while ($current->lte($dateTo)) {
            $data[] = [
                'date' => $current->format('Y-m-d'),
                'new_users' => User::whereDate('created_at', $current)->count(),
                'new_teachers' => User::where('role', 'teacher')
                    ->whereDate('created_at', $current)
                    ->count(),
                'new_students' => User::where('role', 'student')
                    ->whereDate('created_at', $current)
                    ->count(),
            ];
            $current->addDay();
        }
        
        return $data;
    }

    /**
     * Get user distribution
     */
    private function getUserDistribution(): array
    {
        return [
            'by_role' => User::select('role', DB::raw('count(*) as count'))
                ->groupBy('role')
                ->pluck('count', 'role')
                ->toArray(),
            'by_status' => User::select('status', DB::raw('count(*) as count'))
                ->groupBy('status')
                ->pluck('count', 'status')
                ->toArray(),
            'by_teacher_status' => User::where('role', 'teacher')
                ->select('teacher_status', DB::raw('count(*) as count'))
                ->groupBy('teacher_status')
                ->pluck('count', 'teacher_status')
                ->toArray(),
        ];
    }

    /**
     * Get user activity data
     */
    private function getUserActivityData(Carbon $dateFrom, Carbon $dateTo): array
    {
        return [
            'active_users' => User::whereBetween('last_activity_at', [$dateFrom, $dateTo])->count(),
            'new_registrations' => User::whereBetween('created_at', [$dateFrom, $dateTo])->count(),
            'email_verifications' => User::whereNotNull('email_verified_at')
                ->whereBetween('email_verified_at', [$dateFrom, $dateTo])
                ->count(),
        ];
    }

    /**
     * Get user retention rate
     */
    private function getUserRetentionRate(Carbon $dateFrom, Carbon $dateTo): float
    {
        $totalUsers = User::where('created_at', '<=', $dateTo)->count();
        $activeUsers = User::where('last_activity_at', '>=', $dateFrom)->count();
        
        return $totalUsers > 0 ? round(($activeUsers / $totalUsers) * 100, 2) : 0;
    }

    /**
     * Get reservation trends
     */
    private function getReservationTrends(Carbon $dateFrom, Carbon $dateTo): array
    {
        $data = [];
        $current = $dateFrom->copy();
        
        while ($current->lte($dateTo)) {
            $data[] = [
                'date' => $current->format('Y-m-d'),
                'total' => Reservation::whereDate('created_at', $current)->count(),
                'completed' => Reservation::where('status', 'completed')
                    ->whereDate('created_at', $current)
                    ->count(),
                'cancelled' => Reservation::where('status', 'cancelled')
                    ->whereDate('created_at', $current)
                    ->count(),
            ];
            $current->addDay();
        }
        
        return $data;
    }

    /**
     * Get reservation status distribution
     */
    private function getReservationStatusDistribution(Carbon $dateFrom, Carbon $dateTo): array
    {
        return Reservation::whereBetween('created_at', [$dateFrom, $dateTo])
            ->select('status', DB::raw('count(*) as count'))
            ->groupBy('status')
            ->pluck('count', 'status')
            ->toArray();
    }

    /**
     * Get reservation category analysis
     */
    private function getReservationCategoryAnalysis(Carbon $dateFrom, Carbon $dateTo): array
    {
        return DB::table('reservations')
            ->join('categories', 'reservations.category_id', '=', 'categories.id')
            ->whereBetween('reservations.created_at', [$dateFrom, $dateTo])
            ->select('categories.name', DB::raw('count(*) as count'))
            ->groupBy('categories.id', 'categories.name')
            ->orderBy('count', 'desc')
            ->get()
            ->toArray();
    }

    /**
     * Get reservation completion rate
     */
    private function getReservationCompletionRate(Carbon $dateFrom, Carbon $dateTo): float
    {
        $totalReservations = Reservation::whereBetween('created_at', [$dateFrom, $dateTo])->count();
        $completedReservations = Reservation::where('status', 'completed')
            ->whereBetween('created_at', [$dateFrom, $dateTo])
            ->count();
        
        return $totalReservations > 0 ? round(($completedReservations / $totalReservations) * 100, 2) : 0;
    }

    /**
     * Get average reservation duration
     */
    private function getAverageReservationDuration(Carbon $dateFrom, Carbon $dateTo): float
    {
        $avgDuration = Reservation::where('status', 'completed')
            ->whereBetween('created_at', [$dateFrom, $dateTo])
            ->avg('duration_minutes');
        
        return round($avgDuration ?? 0, 2);
    }

    /**
     * Get total revenue
     */
    private function getTotalRevenue(): float
    {
        return Reservation::where('status', 'completed')->sum('price') ?? 0;
    }

    /**
     * Get period revenue
     */
    private function getPeriodRevenue(Carbon $dateFrom, Carbon $dateTo): float
    {
        return Reservation::where('status', 'completed')
            ->whereBetween('created_at', [$dateFrom, $dateTo])
            ->sum('price') ?? 0;
    }

    /**
     * Get revenue trends
     */
    private function getRevenueTrends(Carbon $dateFrom, Carbon $dateTo): array
    {
        $data = [];
        $current = $dateFrom->copy();
        
        while ($current->lte($dateTo)) {
            $data[] = [
                'date' => $current->format('Y-m-d'),
                'revenue' => Reservation::where('status', 'completed')
                    ->whereDate('created_at', $current)
                    ->sum('price') ?? 0,
            ];
            $current->addDay();
        }
        
        return $data;
    }

    /**
     * Get revenue by category
     */
    private function getRevenueByCategory(Carbon $dateFrom, Carbon $dateTo): array
    {
        return DB::table('reservations')
            ->join('categories', 'reservations.category_id', '=', 'categories.id')
            ->where('reservations.status', 'completed')
            ->whereBetween('reservations.created_at', [$dateFrom, $dateTo])
            ->select('categories.name', DB::raw('SUM(reservations.price) as revenue'))
            ->groupBy('categories.id', 'categories.name')
            ->orderBy('revenue', 'desc')
            ->get()
            ->toArray();
    }

    /**
     * Get revenue by teacher
     */
    private function getRevenueByTeacher(Carbon $dateFrom, Carbon $dateTo): array
    {
        return DB::table('reservations')
            ->join('users', 'reservations.teacher_id', '=', 'users.id')
            ->where('reservations.status', 'completed')
            ->whereBetween('reservations.created_at', [$dateFrom, $dateTo])
            ->select('users.name', DB::raw('SUM(reservations.price) as revenue'))
            ->groupBy('users.id', 'users.name')
            ->orderBy('revenue', 'desc')
            ->limit(10)
            ->get()
            ->toArray();
    }

    /**
     * Get average revenue per reservation
     */
    private function getAverageRevenuePerReservation(Carbon $dateFrom, Carbon $dateTo): float
    {
        $totalRevenue = $this->getPeriodRevenue($dateFrom, $dateTo);
        $totalReservations = Reservation::where('status', 'completed')
            ->whereBetween('created_at', [$dateFrom, $dateTo])
            ->count();
        
        return $totalReservations > 0 ? round($totalRevenue / $totalReservations, 2) : 0;
    }

    /**
     * Get top teachers
     */
    private function getTopTeachers(Carbon $dateFrom, Carbon $dateTo): array
    {
        return DB::table('users')
            ->join('teachers', 'users.id', '=', 'teachers.user_id')
            ->leftJoin('reservations', function ($join) use ($dateFrom, $dateTo) {
                $join->on('users.id', '=', 'reservations.teacher_id')
                     ->where('reservations.status', '=', 'completed')
                     ->whereBetween('reservations.created_at', [$dateFrom, $dateTo]);
            })
            ->select(
                'users.id',
                'users.name',
                'teachers.rating_avg',
                'teachers.rating_count',
                DB::raw('COUNT(reservations.id) as total_lessons'),
                DB::raw('SUM(reservations.price) as total_revenue')
            )
            ->where('users.role', 'teacher')
            ->where('users.teacher_status', 'approved')
            ->groupBy('users.id', 'users.name', 'teachers.rating_avg', 'teachers.rating_count')
            ->orderBy('total_lessons', 'desc')
            ->limit(10)
            ->get()
            ->toArray();
    }

    /**
     * Get top categories
     */
    private function getTopCategories(Carbon $dateFrom, Carbon $dateTo): array
    {
        return DB::table('categories')
            ->leftJoin('reservations', function ($join) use ($dateFrom, $dateTo) {
                $join->on('categories.id', '=', 'reservations.category_id')
                     ->whereBetween('reservations.created_at', [$dateFrom, $dateTo]);
            })
            ->select(
                'categories.id',
                'categories.name',
                DB::raw('COUNT(reservations.id) as reservation_count'),
                DB::raw('SUM(reservations.price) as total_revenue')
            )
            ->groupBy('categories.id', 'categories.name')
            ->orderBy('reservation_count', 'desc')
            ->limit(10)
            ->get()
            ->toArray();
    }

    /**
     * Get system performance metrics
     */
    private function getSystemPerformanceMetrics(): array
    {
        return [
            'database_connections' => DB::select('SHOW STATUS LIKE "Threads_connected"')[0]->Value ?? 0,
            'cache_hit_rate' => $this->getCacheHitRate(),
            'memory_usage' => memory_get_usage(true),
            'peak_memory_usage' => memory_get_peak_usage(true),
        ];
    }

    /**
     * Get response time metrics
     */
    private function getResponseTimeMetrics(Carbon $dateFrom, Carbon $dateTo): array
    {
        // This would typically come from application monitoring
        return [
            'average_response_time' => 150, // milliseconds
            'p95_response_time' => 300,
            'p99_response_time' => 500,
        ];
    }

    /**
     * Get login attempts
     */
    private function getLoginAttempts(Carbon $dateFrom, Carbon $dateTo): array
    {
        return AuditLog::where('action', 'login_attempt')
            ->whereBetween('created_at', [$dateFrom, $dateTo])
            ->select(DB::raw('DATE(created_at) as date'), DB::raw('count(*) as count'))
            ->groupBy('date')
            ->orderBy('date')
            ->get()
            ->toArray();
    }

    /**
     * Get suspicious activities
     */
    private function getSuspiciousActivities(Carbon $dateFrom, Carbon $dateTo): array
    {
        return AuditLog::whereIn('action', ['failed_login', 'suspicious_activity', 'security_violation'])
            ->whereBetween('created_at', [$dateFrom, $dateTo])
            ->orderBy('created_at', 'desc')
            ->limit(50)
            ->get()
            ->toArray();
    }

    /**
     * Get security events
     */
    private function getSecurityEvents(Carbon $dateFrom, Carbon $dateTo): array
    {
        return AuditLog::whereIn('action', [
                'user_suspended',
                'user_unsuspended',
                'admin_action',
                'security_alert'
            ])
            ->whereBetween('created_at', [$dateFrom, $dateTo])
            ->orderBy('created_at', 'desc')
            ->get()
            ->toArray();
    }

    /**
     * Get user suspensions
     */
    private function getUserSuspensions(Carbon $dateFrom, Carbon $dateTo): array
    {
        return User::whereNotNull('suspended_at')
            ->whereBetween('suspended_at', [$dateFrom, $dateTo])
            ->select('id', 'name', 'email', 'suspended_at', 'suspension_reason')
            ->get()
            ->toArray();
    }

    /**
     * Get system uptime
     */
    private function getSystemUptime(): string
    {
        // This would typically come from system monitoring
        return '99.9%';
    }

    /**
     * Get last backup date
     */
    private function getLastBackupDate(): ?string
    {
        // This would typically come from backup system
        return now()->subDay()->toISOString();
    }

    /**
     * Get cache hit rate
     */
    private function getCacheHitRate(): float
    {
        // This would typically come from cache monitoring
        return 95.5;
    }

    /**
     * Clear report cache
     */
    public function clearCache(): void
    {
        Cache::flush();
    }

    /**
     * Export report to CSV
     */
    public function exportToCsv(array $report, string $filename = null): string
    {
        $filename = $filename ?? 'admin_report_' . now()->format('Y-m-d_H-i-s') . '.csv';
        $filepath = storage_path('app/reports/' . $filename);
        
        // Ensure directory exists
        if (!is_dir(dirname($filepath))) {
            mkdir(dirname($filepath), 0755, true);
        }
        
        $csv = fopen($filepath, 'w');
        
        // Write headers
        fputcsv($csv, ['Report Type', 'Metric', 'Value', 'Date']);
        
        // Write data
        foreach ($report as $section => $data) {
            if (is_array($data)) {
                foreach ($data as $key => $value) {
                    if (is_array($value)) {
                        $value = json_encode($value);
                    }
                    fputcsv($csv, [$section, $key, $value, now()->toISOString()]);
                }
            }
        }
        
        fclose($csv);
        
        return $filepath;
    }
}
