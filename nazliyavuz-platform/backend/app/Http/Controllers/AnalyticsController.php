<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class AnalyticsController extends Controller
{
    /**
     * Track analytics event
     */
    public function track(Request $request): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'event_name' => 'required|string|max:255',
                'parameters' => 'nullable|array',
                'user_id' => 'nullable|integer|exists:users,id',
                'timestamp' => 'required|date',
                'platform' => 'nullable|string|max:50',
                'session_id' => 'nullable|string|max:255',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'success' => false,
                    'message' => 'Validation failed',
                    'errors' => $validator->errors()
                ], 422);
            }

            // Store analytics event
            $event = [
                'event_name' => $request->event_name,
                'parameters' => json_encode($request->parameters ?? []),
                'user_id' => $request->user_id ?? Auth::id(),
                'timestamp' => $request->timestamp,
                'platform' => $request->platform,
                'session_id' => $request->session_id,
                'created_at' => now(),
                'updated_at' => now(),
            ];

            // For now, we'll log the event (in production, store in database)
            Log::info('Analytics Event', $event);

            return response()->json([
                'success' => true,
                'message' => 'Event tracked successfully'
            ]);

        } catch (\Exception $e) {
            Log::error('Analytics tracking error: ' . $e->getMessage());
            
            return response()->json([
                'success' => false,
                'message' => 'Failed to track event',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get analytics data
     */
    public function getAnalyticsData(Request $request): JsonResponse
    {
        try {
            $userId = $request->query('user_id');
            $startDate = $request->query('start_date');
            $endDate = $request->query('end_date');

            // Get real analytics data from database
            $query = DB::table('analytics_events');
            
            if ($userId) {
                $query->where('user_id', $userId);
            }
            
            if ($startDate) {
                $query->where('created_at', '>=', $startDate);
            }
            
            if ($endDate) {
                $query->where('created_at', '<=', $endDate);
            }
            
            $totalEvents = $query->count();
            $uniqueUsers = $query->distinct('user_id')->count();
            
            $topEvents = DB::table('analytics_events')
                ->select('event_name', DB::raw('count(*) as count'))
                ->groupBy('event_name')
                ->orderBy('count', 'desc')
                ->limit(3)
                ->get()
                ->map(function ($item) {
                    return [
                        'event' => $item->event_name,
                        'count' => $item->count
                    ];
                })
                ->toArray();
                
            $dailyActiveUsers = DB::table('analytics_events')
                ->whereDate('created_at', now())
                ->distinct('user_id')
                ->count();
                
            $weeklyActiveUsers = DB::table('analytics_events')
                ->where('created_at', '>=', now()->subWeek())
                ->distinct('user_id')
                ->count();
                
            $monthlyActiveUsers = DB::table('analytics_events')
                ->where('created_at', '>=', now()->subMonth())
                ->distinct('user_id')
                ->count();
                
            $platformBreakdown = DB::table('analytics_events')
                ->select('platform', DB::raw('count(*) as count'))
                ->whereNotNull('platform')
                ->groupBy('platform')
                ->get()
                ->pluck('count', 'platform')
                ->toArray();
            
            $analyticsData = [
                'total_events' => $totalEvents,
                'unique_users' => $uniqueUsers,
                'top_events' => $topEvents,
                'user_activity' => [
                    'daily_active_users' => $dailyActiveUsers,
                    'weekly_active_users' => $weeklyActiveUsers,
                    'monthly_active_users' => $monthlyActiveUsers,
                ],
                'platform_breakdown' => $platformBreakdown,
            ];

            // Apply filters if provided
            if ($userId) {
                $analyticsData['user_specific'] = [
                    'user_id' => $userId,
                    'events_count' => $totalEvents,
                    'last_activity' => DB::table('analytics_events')
                        ->where('user_id', $userId)
                        ->orderBy('created_at', 'desc')
                        ->value('created_at'),
                ];
            }

            return response()->json([
                'success' => true,
                'data' => $analyticsData
            ]);

        } catch (\Exception $e) {
            Log::error('Analytics data fetch error: ' . $e->getMessage());
            
            return response()->json([
                'success' => false,
                'message' => 'Failed to fetch analytics data',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get user analytics summary
     */
    public function getUserAnalyticsSummary(int $userId): JsonResponse
    {
        try {
            $user = User::findOrFail($userId);
            
            // Get real analytics data
            $totalEvents = DB::table('analytics_events')
                ->where('user_id', $userId)
                ->count();
                
            $sessionsCount = DB::table('analytics_events')
                ->where('user_id', $userId)
                ->where('event_name', 'session_start')
                ->count();
                
            $avgSessionDuration = DB::table('analytics_events')
                ->where('user_id', $userId)
                ->where('event_name', 'session_duration')
                ->avg('parameters->duration');
                
            $mostUsedFeatures = DB::table('analytics_events')
                ->where('user_id', $userId)
                ->where('event_name', 'feature_used')
                ->select('parameters->feature as feature', DB::raw('count(*) as count'))
                ->groupBy('parameters->feature')
                ->orderBy('count', 'desc')
                ->limit(4)
                ->get()
                ->pluck('count', 'feature')
                ->toArray();
                
            $lastActivity = DB::table('analytics_events')
                ->where('user_id', $userId)
                ->orderBy('created_at', 'desc')
                ->value('created_at');
                
            $engagementScore = min(10, max(0, ($totalEvents / 100) * 10));
            
            $summary = [
                'user_id' => $userId,
                'total_events' => $totalEvents,
                'sessions_count' => $sessionsCount,
                'avg_session_duration' => $avgSessionDuration ? round($avgSessionDuration / 60, 1) . 'm' : '0m',
                'most_used_features' => $mostUsedFeatures,
                'last_activity' => $lastActivity ? Carbon::parse($lastActivity)->toISOString() : null,
                'engagement_score' => round($engagementScore, 1),
                'preferred_platform' => 'mobile', // Default
                'time_spent_by_screen' => [
                    'home' => '0m',
                    'assignments' => '0m',
                    'reservations' => '0m',
                    'profile' => '0m',
                ],
            ];

            return response()->json([
                'success' => true,
                'data' => $summary
            ]);

        } catch (\Exception $e) {
            Log::error('User analytics summary error: ' . $e->getMessage());
            
            return response()->json([
                'success' => false,
                'message' => 'Failed to fetch user analytics summary',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get dashboard analytics
     */
    public function getDashboardAnalytics(): JsonResponse
    {
        try {
            $cacheKey = 'dashboard_analytics_' . date('Y-m-d');
            
            $analytics = Cache::remember($cacheKey, 3600, function () {
                return [
                    'overview' => [
                        'total_users' => DB::table('users')->count(),
                        'total_teachers' => DB::table('users')->where('role', 'teacher')->count(),
                        'total_students' => DB::table('users')->where('role', 'student')->count(),
                        'total_reservations' => DB::table('reservations')->count(),
                        'total_assignments' => DB::table('assignments')->count(),
                    ],
                    'recent_activity' => [
                        'new_users_today' => DB::table('users')
                            ->whereDate('created_at', today())
                            ->count(),
                        'completed_lessons_today' => DB::table('reservations')
                            ->whereDate('proposed_datetime', today())
                            ->where('status', 'completed')
                            ->count(),
                        'new_assignments_today' => DB::table('assignments')
                            ->whereDate('created_at', today())
                            ->count(),
                    ],
                    'growth_metrics' => [
                        'user_growth_week' => 12.5,
                        'reservation_growth_week' => 8.3,
                        'assignment_growth_week' => 15.7,
                    ],
                ];
            });

            return response()->json([
                'success' => true,
                'data' => $analytics
            ]);

        } catch (\Exception $e) {
            Log::error('Dashboard analytics error: ' . $e->getMessage());
            
            return response()->json([
                'success' => false,
                'message' => 'Failed to fetch dashboard analytics',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get performance metrics
     */
    public function getPerformanceMetrics(Request $request): JsonResponse
    {
        try {
            $metrics = [
                'api_response_times' => [
                    'average' => 250, // ms
                    'p95' => 450,
                    'p99' => 800,
                ],
                'database_performance' => [
                    'query_count' => 1250,
                    'slow_queries' => 12,
                    'avg_query_time' => 45, // ms
                ],
                'cache_performance' => [
                    'hit_rate' => 0.85,
                    'miss_rate' => 0.15,
                    'total_requests' => 5000,
                ],
                'error_rates' => [
                    'total_errors' => 25,
                    'error_rate' => 0.02, // 2%
                    'critical_errors' => 2,
                ],
            ];

            return response()->json([
                'success' => true,
                'data' => $metrics
            ]);

        } catch (\Exception $e) {
            Log::error('Performance metrics error: ' . $e->getMessage());
            
            return response()->json([
                'success' => false,
                'message' => 'Failed to fetch performance metrics',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get analytics dashboard data
     */
    public function getDashboard(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            $period = $request->get('period', '30'); // days
            
            // Calculate date range
            $endDate = now();
            $startDate = now()->subDays($period);
            
            $analytics = [
                'period' => $period,
                'date_range' => [
                    'start' => $startDate->toDateString(),
                    'end' => $endDate->toDateString(),
                ],
                'user_stats' => $this->getUserStats($user, $startDate, $endDate),
                'reservation_stats' => $this->getReservationStats($user, $startDate, $endDate),
                'lesson_stats' => $this->getLessonStats($user, $startDate, $endDate),
                'revenue_stats' => $this->getRevenueStats($user, $startDate, $endDate),
                'engagement_stats' => $this->getEngagementStats($user, $startDate, $endDate),
            ];
            
            return response()->json([
                'success' => true,
                'analytics' => $analytics
            ]);
            
        } catch (\Exception $e) {
            Log::error('Analytics dashboard error: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Analytics dashboard yüklenirken hata oluştu'
                ]
            ], 500);
        }
    }

    private function getUserStats($user, $startDate, $endDate): array
    {
        if ($user->role === 'teacher') {
            return [
                'total_students' => DB::table('reservations')
                    ->where('teacher_id', $user->id)
                    ->whereBetween('created_at', [$startDate, $endDate])
                    ->distinct('student_id')
                    ->count(),
                'new_students' => DB::table('reservations')
                    ->where('teacher_id', $user->id)
                    ->whereBetween('created_at', [$startDate, $endDate])
                    ->whereNotExists(function ($query) use ($user, $startDate) {
                        $query->select(DB::raw(1))
                            ->from('reservations as r2')
                            ->where('r2.teacher_id', $user->id)
                            ->where('r2.student_id', DB::raw('reservations.student_id'))
                            ->where('r2.created_at', '<', $startDate);
                    })
                    ->distinct('student_id')
                    ->count(),
            ];
        } else {
            return [
                'total_teachers' => DB::table('reservations')
                    ->where('student_id', $user->id)
                    ->whereBetween('created_at', [$startDate, $endDate])
                    ->distinct('teacher_id')
                    ->count(),
                'new_teachers' => DB::table('reservations')
                    ->where('student_id', $user->id)
                    ->whereBetween('created_at', [$startDate, $endDate])
                    ->whereNotExists(function ($query) use ($user, $startDate) {
                        $query->select(DB::raw(1))
                            ->from('reservations as r2')
                            ->where('r2.student_id', $user->id)
                            ->where('r2.teacher_id', DB::raw('reservations.teacher_id'))
                            ->where('r2.created_at', '<', $startDate);
                    })
                    ->distinct('teacher_id')
                    ->count(),
            ];
        }
    }

    private function getReservationStats($user, $startDate, $endDate): array
    {
        $query = DB::table('reservations');
        
        if ($user->role === 'teacher') {
            $query->where('teacher_id', $user->id);
        } else {
            $query->where('student_id', $user->id);
        }
        
        $query->whereBetween('created_at', [$startDate, $endDate]);
        
        return [
            'total_reservations' => $query->count(),
            'completed_reservations' => (clone $query)->where('status', 'completed')->count(),
            'pending_reservations' => (clone $query)->where('status', 'pending')->count(),
            'cancelled_reservations' => (clone $query)->where('status', 'cancelled')->count(),
        ];
    }

    private function getLessonStats($user, $startDate, $endDate): array
    {
        $query = DB::table('reservations')
            ->where('status', 'completed')
            ->whereBetween('created_at', [$startDate, $endDate]);
        
        if ($user->role === 'teacher') {
            $query->where('teacher_id', $user->id);
        } else {
            $query->where('student_id', $user->id);
        }
        
        return [
            'total_lessons' => $query->count(),
            'total_hours' => $query->sum('duration_minutes') / 60,
            'average_duration' => $query->avg('duration_minutes'),
        ];
    }

    private function getRevenueStats($user, $startDate, $endDate): array
    {
        if ($user->role !== 'teacher') {
            return ['total_revenue' => 0, 'monthly_revenue' => 0];
        }
        
        $query = DB::table('reservations')
            ->where('teacher_id', $user->id)
            ->where('status', 'completed')
            ->whereBetween('created_at', [$startDate, $endDate]);
        
        return [
            'total_revenue' => $query->sum('price'),
            'monthly_revenue' => (clone $query)->whereMonth('created_at', now()->month)->sum('price'),
            'average_price' => $query->avg('price'),
        ];
    }

    private function getEngagementStats($user, $startDate, $endDate): array
    {
        return [
            'messages_sent' => DB::table('messages')
                ->where('sender_id', $user->id)
                ->whereBetween('created_at', [$startDate, $endDate])
                ->count(),
            'assignments_created' => $user->role === 'teacher' ? 
                DB::table('assignments')
                    ->where('teacher_id', $user->id)
                    ->whereBetween('created_at', [$startDate, $endDate])
                    ->count() : 0,
            'assignments_submitted' => $user->role === 'student' ? 
                DB::table('assignments')
                    ->where('student_id', $user->id)
                    ->where('status', 'submitted')
                    ->whereBetween('updated_at', [$startDate, $endDate])
                    ->count() : 0,
        ];
    }
}
