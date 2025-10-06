<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Queue;
use Exception;

class HealthCheckController extends Controller
{
    /**
     * Basic health check endpoint
     *
     * @return \Illuminate\Http\JsonResponse
     */
    public function basic(): JsonResponse
    {
        return response()->json([
            'status' => 'healthy',
            'timestamp' => now()->toISOString(),
            'version' => config('app.version', '1.0.0'),
            'environment' => config('app.env'),
        ]);
    }

    /**
     * Detailed health check with system metrics
     *
     * @return \Illuminate\Http\JsonResponse
     */
    public function detailed(): JsonResponse
    {
        $health = [
            'status' => 'healthy',
            'timestamp' => now()->toISOString(),
            'version' => config('app.version', '1.0.0'),
            'environment' => config('app.env'),
            'checks' => []
        ];

        // Database check
        $health['checks']['database'] = $this->checkDatabase();
        
        // Cache check
        $health['checks']['cache'] = $this->checkCache();
        
        // Storage check
        $health['checks']['storage'] = $this->checkStorage();
        
        // Queue check
        $health['checks']['queue'] = $this->checkQueue();
        
        // Redis check
        $health['checks']['redis'] = $this->checkRedis();
        
        // Memory usage
        $health['checks']['memory'] = $this->checkMemory();
        
        // Disk space
        $health['checks']['disk'] = $this->checkDiskSpace();

        // Determine overall status
        $overallStatus = 'healthy';
        foreach ($health['checks'] as $check) {
            if ($check['status'] === 'unhealthy') {
                $overallStatus = 'unhealthy';
                break;
            } elseif ($check['status'] === 'degraded') {
                $overallStatus = 'degraded';
            }
        }

        $health['status'] = $overallStatus;

        $statusCode = $overallStatus === 'healthy' ? 200 : ($overallStatus === 'degraded' ? 200 : 503);

        return response()->json($health, $statusCode);
    }

    /**
     * Check database connectivity and performance
     */
    private function checkDatabase(): array
    {
        try {
            $startTime = microtime(true);
            
            // Test basic connectivity
            DB::connection()->getPdo();
            
            // Test query performance
            $result = DB::select('SELECT 1 as test');
            
            $responseTime = round((microtime(true) - $startTime) * 1000, 2);
            
            // Check connection count (MySQL only)
            $connectionCount = null;
            if (config('database.default') === 'mysql') {
                try {
                    $connections = DB::select("SHOW STATUS LIKE 'Threads_connected'");
                    $connectionCount = $connections[0]->Value ?? null;
                } catch (Exception $e) {
                    // Ignore if not available
                }
            }

            return [
                'status' => 'healthy',
                'response_time_ms' => $responseTime,
                'connection_count' => $connectionCount,
                'message' => 'Database connection successful'
            ];
            
        } catch (Exception $e) {
            return [
                'status' => 'unhealthy',
                'error' => $e->getMessage(),
                'message' => 'Database connection failed'
            ];
        }
    }

    /**
     * Check cache system
     */
    private function checkCache(): array
    {
        try {
            $startTime = microtime(true);
            
            // Test cache write/read
            $testKey = 'health_check_' . time();
            $testValue = 'test_value_' . rand(1000, 9999);
            
            Cache::put($testKey, $testValue, 60);
            $retrievedValue = Cache::get($testKey);
            
            $responseTime = round((microtime(true) - $startTime) * 1000, 2);
            
            // Clean up test key
            Cache::forget($testKey);
            
            if ($retrievedValue !== $testValue) {
                return [
                    'status' => 'unhealthy',
                    'message' => 'Cache read/write test failed'
                ];
            }

            return [
                'status' => 'healthy',
                'response_time_ms' => $responseTime,
                'message' => 'Cache system working correctly'
            ];
            
        } catch (Exception $e) {
            return [
                'status' => 'unhealthy',
                'error' => $e->getMessage(),
                'message' => 'Cache system failed'
            ];
        }
    }

    /**
     * Check storage system
     */
    private function checkStorage(): array
    {
        try {
            $startTime = microtime(true);
            
            // Test storage write/read
            $testKey = 'health_check_' . time() . '.txt';
            $testContent = 'Health check test content';
            
            Storage::put($testKey, $testContent);
            $retrievedContent = Storage::get($testKey);
            
            $responseTime = round((microtime(true) - $startTime) * 1000, 2);
            
            // Clean up test file
            Storage::delete($testKey);
            
            if ($retrievedContent !== $testContent) {
                return [
                    'status' => 'unhealthy',
                    'message' => 'Storage read/write test failed'
                ];
            }

            return [
                'status' => 'healthy',
                'response_time_ms' => $responseTime,
                'message' => 'Storage system working correctly'
            ];
            
        } catch (Exception $e) {
            return [
                'status' => 'unhealthy',
                'error' => $e->getMessage(),
                'message' => 'Storage system failed'
            ];
        }
    }

    /**
     * Check queue system
     */
    private function checkQueue(): array
    {
        try {
            $queueSize = Queue::size();
            
            return [
                'status' => 'healthy',
                'queue_size' => $queueSize,
                'message' => 'Queue system accessible'
            ];
            
        } catch (Exception $e) {
            return [
                'status' => 'unhealthy',
                'error' => $e->getMessage(),
                'message' => 'Queue system failed'
            ];
        }
    }

    /**
     * Check Redis connectivity
     */
    private function checkRedis(): array
    {
        try {
            if (config('cache.default') !== 'redis') {
                return [
                    'status' => 'healthy',
                    'message' => 'Redis not configured as default cache'
                ];
            }

            $startTime = microtime(true);
            
            // Test Redis connection
            Redis::ping();
            
            // Test Redis write/read
            $testKey = 'health_check_redis_' . time();
            $testValue = 'test_value_' . rand(1000, 9999);
            
            Redis::set($testKey, $testValue, 'EX', 60);
            $retrievedValue = Redis::get($testKey);
            
            $responseTime = round((microtime(true) - $startTime) * 1000, 2);
            
            // Clean up test key
            Redis::del($testKey);
            
            if ($retrievedValue !== $testValue) {
                return [
                    'status' => 'unhealthy',
                    'message' => 'Redis read/write test failed'
                ];
            }

            // Get Redis info
            $info = Redis::info();
            
            return [
                'status' => 'healthy',
                'response_time_ms' => $responseTime,
                'redis_version' => $info['redis_version'] ?? 'unknown',
                'connected_clients' => $info['connected_clients'] ?? 0,
                'used_memory_human' => $info['used_memory_human'] ?? 'unknown',
                'message' => 'Redis system working correctly'
            ];
            
        } catch (Exception $e) {
            return [
                'status' => 'unhealthy',
                'error' => $e->getMessage(),
                'message' => 'Redis system failed'
            ];
        }
    }

    /**
     * Check memory usage
     */
    private function checkMemory(): array
    {
        try {
            $memoryUsage = memory_get_usage(true);
            $memoryPeak = memory_get_peak_usage(true);
            $memoryLimit = $this->parseMemoryLimit(ini_get('memory_limit'));
            
            $usagePercentage = $memoryLimit > 0 ? round(($memoryUsage / $memoryLimit) * 100, 2) : 0;
            
            $status = 'healthy';
            if ($usagePercentage > 90) {
                $status = 'unhealthy';
            } elseif ($usagePercentage > 75) {
                $status = 'degraded';
            }

            return [
                'status' => $status,
                'current_usage' => $this->formatBytes($memoryUsage),
                'peak_usage' => $this->formatBytes($memoryPeak),
                'limit' => $this->formatBytes($memoryLimit),
                'usage_percentage' => $usagePercentage,
                'message' => 'Memory usage within acceptable limits'
            ];
            
        } catch (Exception $e) {
            return [
                'status' => 'unhealthy',
                'error' => $e->getMessage(),
                'message' => 'Memory check failed'
            ];
        }
    }

    /**
     * Check disk space
     */
    private function checkDiskSpace(): array
    {
        try {
            $storagePath = storage_path();
            $totalSpace = disk_total_space($storagePath);
            $freeSpace = disk_free_space($storagePath);
            $usedSpace = $totalSpace - $freeSpace;
            
            $usagePercentage = $totalSpace > 0 ? round(($usedSpace / $totalSpace) * 100, 2) : 0;
            
            $status = 'healthy';
            if ($usagePercentage > 90) {
                $status = 'unhealthy';
            } elseif ($usagePercentage > 80) {
                $status = 'degraded';
            }

            return [
                'status' => $status,
                'total_space' => $this->formatBytes($totalSpace),
                'free_space' => $this->formatBytes($freeSpace),
                'used_space' => $this->formatBytes($usedSpace),
                'usage_percentage' => $usagePercentage,
                'message' => 'Disk space within acceptable limits'
            ];
            
        } catch (Exception $e) {
            return [
                'status' => 'unhealthy',
                'error' => $e->getMessage(),
                'message' => 'Disk space check failed'
            ];
        }
    }

    /**
     * Parse memory limit string to bytes
     */
    private function parseMemoryLimit(string $limit): int
    {
        $limit = trim($limit);
        $last = strtolower($limit[strlen($limit) - 1]);
        $value = (int) $limit;

        switch ($last) {
            case 'g':
                $value *= 1024;
            case 'm':
                $value *= 1024;
            case 'k':
                $value *= 1024;
        }

        return $value;
    }

    /**
     * Format bytes to human readable format
     */
    private function formatBytes(int $bytes): string
    {
        $units = ['B', 'KB', 'MB', 'GB', 'TB'];
        
        for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
            $bytes /= 1024;
        }
        
        return round($bytes, 2) . ' ' . $units[$i];
    }
}
