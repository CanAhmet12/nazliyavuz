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

            // Mock analytics data (in production, query from database)
            $analyticsData = [
                'total_events' => 1250,
                'unique_users' => 85,
                'top_events' => [
                    ['event' => 'screen_view', 'count' => 450],
                    ['event' => 'engagement', 'count' => 320],
                    ['event' => 'performance', 'count' => 180],
                ],
                'user_activity' => [
                    'daily_active_users' => 45,
                    'weekly_active_users' => 78,
                    'monthly_active_users' => 85,
                ],
                'platform_breakdown' => [
                    'android' => 60,
                    'ios' => 25,
                    'web' => 15,
                ],
            ];

            // Apply filters if provided
            if ($userId) {
                $analyticsData['user_specific'] = [
                    'user_id' => $userId,
                    'events_count' => 45,
                    'last_activity' => now()->subHours(2)->toISOString(),
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
            // Mock user analytics summary
            $summary = [
                'user_id' => $userId,
                'total_events' => 125,
                'sessions_count' => 15,
                'avg_session_duration' => '12m 30s',
                'most_used_features' => [
                    'assignments' => 45,
                    'reservations' => 35,
                    'chat' => 25,
                    'profile' => 20,
                ],
                'last_activity' => now()->subHours(1)->toISOString(),
                'engagement_score' => 8.5,
                'preferred_platform' => 'android',
                'time_spent_by_screen' => [
                    'home' => '45m',
                    'assignments' => '30m',
                    'reservations' => '25m',
                    'profile' => '10m',
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
}
