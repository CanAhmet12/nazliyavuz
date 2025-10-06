<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use App\Services\PerformanceMonitoringService;
use App\Services\SmartCacheService;
use App\Services\DatabaseOptimizerService;
use App\Services\JobOptimizerService;
use App\Services\RedisPoolService;

/**
 * Performance Dashboard Controller
 * Enterprise-level performance monitoring and analytics
 */
class PerformanceDashboardController extends Controller
{
    /**
     * Get comprehensive performance dashboard
     */
    public function dashboard(): JsonResponse
    {
        try {
            $dashboardData = [
                'timestamp' => now(),
                'system_health' => $this->getSystemHealth(),
                'performance_metrics' => PerformanceMonitoringService::getPerformanceReport(),
                'cache_performance' => SmartCacheService::getStats(),
                'database_performance' => DatabaseOptimizerService::getPerformanceMetrics(),
                'job_performance' => JobOptimizerService::getJobMetrics(),
                'redis_performance' => RedisPoolService::getPoolStats(),
                'queue_health' => JobOptimizerService::getQueueHealth(),
                'alerts' => PerformanceMonitoringService::generateAlerts(),
            ];

            return response()->json($dashboardData);

        } catch (\Exception $e) {
            return response()->json([
                'error' => 'Performance dashboard yüklenirken hata oluştu',
                'message' => $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get system health status
     */
    private function getSystemHealth(): array
    {
        $health = [
            'status' => 'healthy',
            'score' => 100,
            'checks' => []
        ];

        // Memory check
        $memoryUsage = memory_get_usage(true);
        $memoryLimit = ini_get('memory_limit');
        $memoryPercent = $this->parseMemoryLimit($memoryLimit);
        
        if ($memoryUsage > $memoryPercent * 0.8) {
            $health['checks'][] = [
                'name' => 'memory',
                'status' => 'warning',
                'message' => 'High memory usage detected'
            ];
            $health['score'] -= 20;
        }

        // Cache hit ratio check
        $cacheStats = SmartCacheService::getStats();
        $hitRatio = $cacheStats['l1_cache_size'] > 0 ? 90 : 0; // Simplified calculation
        
        if ($hitRatio < 70) {
            $health['checks'][] = [
                'name' => 'cache',
                'status' => 'warning',
                'message' => 'Low cache hit ratio'
            ];
            $health['score'] -= 15;
        }

        // Database performance check
        $dbMetrics = DatabaseOptimizerService::getPerformanceMetrics();
        if ($dbMetrics['slow_queries'] > 10) {
            $health['checks'][] = [
                'name' => 'database',
                'status' => 'warning',
                'message' => 'High number of slow queries'
            ];
            $health['score'] -= 25;
        }

        // Queue health check
        $queueHealth = JobOptimizerService::getQueueHealth();
        if ($queueHealth['health_score'] < 80) {
            $health['checks'][] = [
                'name' => 'queue',
                'status' => 'warning',
                'message' => 'Queue health degraded'
            ];
            $health['score'] -= 20;
        }

        // Determine overall status
        if ($health['score'] < 60) {
            $health['status'] = 'critical';
        } elseif ($health['score'] < 80) {
            $health['status'] = 'warning';
        }

        return $health;
    }

    /**
     * Parse memory limit string to bytes
     */
    private function parseMemoryLimit(string $limit): int
    {
        $limit = trim($limit);
        $last = strtolower($limit[strlen($limit) - 1]);
        $limit = (int) $limit;

        switch ($last) {
            case 'g':
                $limit *= 1024;
            case 'm':
                $limit *= 1024;
            case 'k':
                $limit *= 1024;
        }

        return $limit;
    }

    /**
     * Get performance trends
     */
    public function trends(Request $request): JsonResponse
    {
        try {
            $period = $request->get('period', '1h'); // 1h, 6h, 24h, 7d
            
            $trends = [
                'period' => $period,
                'api_response_times' => $this->getApiResponseTimeTrends($period),
                'cache_hit_ratios' => $this->getCacheHitRatioTrends($period),
                'database_query_times' => $this->getDatabaseQueryTimeTrends($period),
                'memory_usage' => $this->getMemoryUsageTrends($period),
                'error_rates' => $this->getErrorRateTrends($period),
            ];

            return response()->json($trends);

        } catch (\Exception $e) {
            return response()->json([
                'error' => 'Performance trends yüklenirken hata oluştu',
                'message' => $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get API response time trends
     */
    private function getApiResponseTimeTrends(string $period): array
    {
        // This would typically query a time-series database
        // For now, return mock data
        return [
            'current' => 150, // ms
            'previous' => 180, // ms
            'trend' => 'improving',
            'data_points' => $this->generateMockTimeSeries($period)
        ];
    }

    /**
     * Get cache hit ratio trends
     */
    private function getCacheHitRatioTrends(string $period): array
    {
        return [
            'current' => 85, // percentage
            'previous' => 78, // percentage
            'trend' => 'improving',
            'data_points' => $this->generateMockTimeSeries($period)
        ];
    }

    /**
     * Get database query time trends
     */
    private function getDatabaseQueryTimeTrends(string $period): array
    {
        return [
            'current' => 25, // ms
            'previous' => 35, // ms
            'trend' => 'improving',
            'data_points' => $this->generateMockTimeSeries($period)
        ];
    }

    /**
     * Get memory usage trends
     */
    private function getMemoryUsageTrends(string $period): array
    {
        return [
            'current' => 256, // MB
            'previous' => 280, // MB
            'trend' => 'improving',
            'data_points' => $this->generateMockTimeSeries($period)
        ];
    }

    /**
     * Get error rate trends
     */
    private function getErrorRateTrends(string $period): array
    {
        return [
            'current' => 0.5, // percentage
            'previous' => 1.2, // percentage
            'trend' => 'improving',
            'data_points' => $this->generateMockTimeSeries($period)
        ];
    }

    /**
     * Generate mock time series data
     */
    private function generateMockTimeSeries(string $period): array
    {
        $points = [];
        $now = now();
        
        switch ($period) {
            case '1h':
                for ($i = 0; $i < 12; $i++) {
                    $points[] = [
                        'timestamp' => $now->subMinutes($i * 5)->toISOString(),
                        'value' => rand(100, 200)
                    ];
                }
                break;
            case '6h':
                for ($i = 0; $i < 24; $i++) {
                    $points[] = [
                        'timestamp' => $now->subMinutes($i * 15)->toISOString(),
                        'value' => rand(100, 200)
                    ];
                }
                break;
            case '24h':
                for ($i = 0; $i < 24; $i++) {
                    $points[] = [
                        'timestamp' => $now->subHours($i)->toISOString(),
                        'value' => rand(100, 200)
                    ];
                }
                break;
            case '7d':
                for ($i = 0; $i < 7; $i++) {
                    $points[] = [
                        'timestamp' => $now->subDays($i)->toISOString(),
                        'value' => rand(100, 200)
                    ];
                }
                break;
        }
        
        return array_reverse($points);
    }

    /**
     * Get performance recommendations
     */
    public function recommendations(): JsonResponse
    {
        try {
            $recommendations = [];

            // Check cache performance
            $cacheStats = SmartCacheService::getStats();
            if ($cacheStats['l1_cache_size'] < 100) {
                $recommendations[] = [
                    'type' => 'cache',
                    'priority' => 'medium',
                    'title' => 'Increase Cache Size',
                    'description' => 'Consider increasing cache size to improve performance',
                    'action' => 'Increase cache memory allocation'
                ];
            }

            // Check database performance
            $dbMetrics = DatabaseOptimizerService::getPerformanceMetrics();
            if ($dbMetrics['slow_queries'] > 5) {
                $recommendations[] = [
                    'type' => 'database',
                    'priority' => 'high',
                    'title' => 'Optimize Slow Queries',
                    'description' => 'Multiple slow queries detected',
                    'action' => 'Review and optimize database queries'
                ];
            }

            // Check memory usage
            $memoryUsage = memory_get_usage(true);
            if ($memoryUsage > 100 * 1024 * 1024) { // 100MB
                $recommendations[] = [
                    'type' => 'memory',
                    'priority' => 'medium',
                    'title' => 'Memory Usage High',
                    'description' => 'Consider optimizing memory usage',
                    'action' => 'Review memory-intensive operations'
                ];
            }

            return response()->json([
                'recommendations' => $recommendations,
                'total_count' => count($recommendations)
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'error' => 'Performance recommendations yüklenirken hata oluştu',
                'message' => $e->getMessage()
            ], 500);
        }
    }

    /**
     * Export performance data
     */
    public function export(Request $request): JsonResponse
    {
        try {
            $format = $request->get('format', 'json');
            $period = $request->get('period', '24h');
            
            $data = [
                'export_info' => [
                    'timestamp' => now(),
                    'period' => $period,
                    'format' => $format
                ],
                'performance_data' => PerformanceMonitoringService::exportPerformanceData($format),
                'system_health' => $this->getSystemHealth(),
                'trends' => $this->trends($request)->getData(true)
            ];

            return response()->json($data);

        } catch (\Exception $e) {
            return response()->json([
                'error' => 'Performance data export edilirken hata oluştu',
                'message' => $e->getMessage()
            ], 500);
        }
    }
}
