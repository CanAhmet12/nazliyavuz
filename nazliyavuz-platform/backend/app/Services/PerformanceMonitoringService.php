<?php

namespace App\Services;

use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use App\Services\RedisPoolService;
use App\Services\DatabaseOptimizerService;
use App\Services\SmartCacheService;
use App\Services\JobOptimizerService;

/**
 * Performance Monitoring Service
 * Enterprise-level performance monitoring and analytics
 */
class PerformanceMonitoringService
{
    private static array $metrics = [];
    private static array $performanceHistory = [];
    private static float $startTime;

    /**
     * Initialize performance monitoring
     */
    public static function initialize(): void
    {
        self::$startTime = microtime(true);
        self::startMemoryTracking();
    }

    /**
     * Start memory tracking
     */
    private static function startMemoryTracking(): void
    {
        self::$metrics['memory'] = [
            'start' => memory_get_usage(true),
            'peak' => memory_get_peak_usage(true),
        ];
    }

    /**
     * Track API request performance
     */
    public static function trackApiRequest(string $endpoint, float $responseTime, int $statusCode, array $metadata = []): void
    {
        $requestData = [
            'endpoint' => $endpoint,
            'response_time' => $responseTime,
            'status_code' => $statusCode,
            'timestamp' => now(),
            'memory_usage' => memory_get_usage(true),
            'metadata' => $metadata,
        ];

        // Store in Redis for real-time monitoring
        RedisPoolService::execute(function($redis) use ($requestData) {
            $key = 'api_performance:' . date('Y-m-d-H');
            $redis->lpush($key, json_encode($requestData));
            $redis->expire($key, 86400); // Keep for 24 hours
        });

        // Log slow requests
        if ($responseTime > 1.0) {
            Log::warning('Slow API request detected', $requestData);
        }

        self::$performanceHistory[] = $requestData;
    }

    /**
     * Track database query performance
     */
    public static function trackDatabaseQuery(string $query, float $executionTime, int $rowsAffected = 0): void
    {
        $queryData = [
            'query' => $query,
            'execution_time' => $executionTime,
            'rows_affected' => $rowsAffected,
            'timestamp' => now(),
        ];

        // Store slow queries
        if ($executionTime > 0.1) {
            RedisPoolService::execute(function($redis) use ($queryData) {
                $key = 'slow_queries:' . date('Y-m-d-H');
                $redis->lpush($key, json_encode($queryData));
                $redis->expire($key, 86400);
            });
        }

        self::$metrics['database_queries'][] = $queryData;
    }

    /**
     * Track cache performance
     */
    public static function trackCacheOperation(string $operation, string $key, bool $hit, float $executionTime = 0): void
    {
        $cacheData = [
            'operation' => $operation,
            'key' => $key,
            'hit' => $hit,
            'execution_time' => $executionTime,
            'timestamp' => now(),
        ];

        self::$metrics['cache_operations'][] = $cacheData;

        // Update cache hit ratio
        if (!isset(self::$metrics['cache_stats'])) {
            self::$metrics['cache_stats'] = ['hits' => 0, 'misses' => 0];
        }

        if ($hit) {
            self::$metrics['cache_stats']['hits']++;
        } else {
            self::$metrics['cache_stats']['misses']++;
        }
    }

    /**
     * Track job performance
     */
    public static function trackJobPerformance(string $jobClass, float $executionTime, bool $success, array $metadata = []): void
    {
        $jobData = [
            'job_class' => $jobClass,
            'execution_time' => $executionTime,
            'success' => $success,
            'timestamp' => now(),
            'metadata' => $metadata,
        ];

        RedisPoolService::execute(function($redis) use ($jobData) {
            $key = 'job_performance:' . date('Y-m-d-H');
            $redis->lpush($key, json_encode($jobData));
            $redis->expire($key, 86400);
        });

        self::$metrics['job_performance'][] = $jobData;
    }

    /**
     * Get comprehensive performance report
     */
    public static function getPerformanceReport(): array
    {
        $report = [
            'timestamp' => now(),
            'uptime' => microtime(true) - self::$startTime,
            'memory_usage' => [
                'current' => memory_get_usage(true),
                'peak' => memory_get_peak_usage(true),
                'limit' => ini_get('memory_limit'),
            ],
            'cache_performance' => self::getCachePerformance(),
            'database_performance' => self::getDatabasePerformance(),
            'api_performance' => self::getApiPerformance(),
            'job_performance' => self::getJobPerformance(),
            'system_metrics' => self::getSystemMetrics(),
        ];

        return $report;
    }

    /**
     * Get cache performance metrics
     */
    private static function getCachePerformance(): array
    {
        $cacheStats = self::$metrics['cache_stats'] ?? ['hits' => 0, 'misses' => 0];
        $total = $cacheStats['hits'] + $cacheStats['misses'];
        
        return [
            'hit_ratio' => $total > 0 ? ($cacheStats['hits'] / $total) * 100 : 0,
            'total_operations' => $total,
            'hits' => $cacheStats['hits'],
            'misses' => $cacheStats['misses'],
            'smart_cache_stats' => SmartCacheService::getStats(),
        ];
    }

    /**
     * Get database performance metrics
     */
    private static function getDatabasePerformance(): array
    {
        $queries = self::$metrics['database_queries'] ?? [];
        $totalTime = array_sum(array_column($queries, 'execution_time'));
        $slowQueries = array_filter($queries, fn($q) => $q['execution_time'] > 0.1);

        return [
            'total_queries' => count($queries),
            'total_execution_time' => $totalTime,
            'average_execution_time' => count($queries) > 0 ? $totalTime / count($queries) : 0,
            'slow_queries_count' => count($slowQueries),
            'database_metrics' => DatabaseOptimizerService::getPerformanceMetrics(),
        ];
    }

    /**
     * Get API performance metrics
     */
    private static function getApiPerformance(): array
    {
        $requests = self::$performanceHistory;
        $totalTime = array_sum(array_column($requests, 'response_time'));
        $slowRequests = array_filter($requests, fn($r) => $r['response_time'] > 1.0);

        return [
            'total_requests' => count($requests),
            'average_response_time' => count($requests) > 0 ? $totalTime / count($requests) : 0,
            'slow_requests_count' => count($slowRequests),
            'status_codes' => array_count_values(array_column($requests, 'status_code')),
        ];
    }

    /**
     * Get job performance metrics
     */
    private static function getJobPerformance(): array
    {
        $jobs = self::$metrics['job_performance'] ?? [];
        $successfulJobs = array_filter($jobs, fn($j) => $j['success']);
        $totalTime = array_sum(array_column($jobs, 'execution_time'));

        return [
            'total_jobs' => count($jobs),
            'successful_jobs' => count($successfulJobs),
            'failed_jobs' => count($jobs) - count($successfulJobs),
            'success_rate' => count($jobs) > 0 ? (count($successfulJobs) / count($jobs)) * 100 : 0,
            'average_execution_time' => count($jobs) > 0 ? $totalTime / count($jobs) : 0,
            'job_metrics' => JobOptimizerService::getJobMetrics(),
            'queue_health' => JobOptimizerService::getQueueHealth(),
        ];
    }

    /**
     * Get system metrics
     */
    private static function getSystemMetrics(): array
    {
        return [
            'php_version' => PHP_VERSION,
            'laravel_version' => app()->version(),
            'server_time' => now(),
            'timezone' => config('app.timezone'),
            'environment' => config('app.env'),
            'debug_mode' => config('app.debug'),
        ];
    }

    /**
     * Get real-time performance dashboard data
     */
    public static function getDashboardData(): array
    {
        return [
            'current_performance' => self::getPerformanceReport(),
            'redis_pool_stats' => RedisPoolService::getPoolStats(),
            'cache_stats' => SmartCacheService::getStats(),
            'database_stats' => DatabaseOptimizerService::getPerformanceMetrics(),
            'job_stats' => JobOptimizerService::getJobMetrics(),
            'queue_health' => JobOptimizerService::getQueueHealth(),
        ];
    }

    /**
     * Generate performance alerts
     */
    public static function generateAlerts(): array
    {
        $alerts = [];
        $report = self::getPerformanceReport();

        // Memory usage alert
        if ($report['memory_usage']['current'] > 100 * 1024 * 1024) { // 100MB
            $alerts[] = [
                'type' => 'memory',
                'level' => 'warning',
                'message' => 'High memory usage detected',
                'value' => $report['memory_usage']['current'],
            ];
        }

        // Slow API requests alert
        if ($report['api_performance']['slow_requests_count'] > 10) {
            $alerts[] = [
                'type' => 'api',
                'level' => 'warning',
                'message' => 'High number of slow API requests',
                'value' => $report['api_performance']['slow_requests_count'],
            ];
        }

        // Cache hit ratio alert
        if ($report['cache_performance']['hit_ratio'] < 70) {
            $alerts[] = [
                'type' => 'cache',
                'level' => 'warning',
                'message' => 'Low cache hit ratio',
                'value' => $report['cache_performance']['hit_ratio'],
            ];
        }

        return $alerts;
    }

    /**
     * Export performance data
     */
    public static function exportPerformanceData(string $format = 'json'): string
    {
        $data = self::getPerformanceReport();

        switch ($format) {
            case 'json':
                return json_encode($data, JSON_PRETTY_PRINT);
            case 'csv':
                return self::convertToCsv($data);
            default:
                return json_encode($data);
        }
    }

    /**
     * Convert data to CSV format
     */
    private static function convertToCsv(array $data): string
    {
        $csv = '';
        foreach ($data as $key => $value) {
            if (is_array($value)) {
                $csv .= $key . ',' . json_encode($value) . "\n";
            } else {
                $csv .= $key . ',' . $value . "\n";
            }
        }
        return $csv;
    }

    /**
     * Clear performance metrics
     */
    public static function clearMetrics(): void
    {
        self::$metrics = [];
        self::$performanceHistory = [];
        self::initialize();
    }
}
