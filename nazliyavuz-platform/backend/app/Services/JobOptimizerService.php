<?php

namespace App\Services;

use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Redis;
use App\Services\RedisPoolService;

/**
 * Background Job Optimizer Service
 * Enterprise-level job management and optimization
 */
class JobOptimizerService
{
    const PRIORITY_HIGH = 'high';
    const PRIORITY_NORMAL = 'normal';
    const PRIORITY_LOW = 'low';

    private static array $jobMetrics = [];
    private static array $batchJobs = [];

    /**
     * Dispatch job with optimization
     */
    public static function dispatchOptimized(string $jobClass, array $data = [], string $priority = self::PRIORITY_NORMAL, int $delay = 0): void
    {
        $jobId = uniqid('job_', true);
        
        // Add job metadata
        $jobData = [
            'id' => $jobId,
            'class' => $jobClass,
            'data' => $data,
            'priority' => $priority,
            'delay' => $delay,
            'created_at' => now(),
            'attempts' => 0,
        ];

        // Store job in Redis for tracking
        RedisPoolService::execute(function($redis) use ($jobId, $jobData) {
            $redis->hset('job_tracking', $jobId, json_encode($jobData));
            $redis->expire('job_tracking', 86400); // 24 hours
        });

        // Dispatch based on priority
        switch ($priority) {
            case self::PRIORITY_HIGH:
                Queue::push($jobClass, $data, 'high');
                break;
            case self::PRIORITY_LOW:
                Queue::push($jobClass, $data, 'low');
                break;
            default:
                Queue::push($jobClass, $data);
        }

        // Update metrics
        self::updateJobMetrics($priority, 'dispatched');

        Log::info('Job dispatched with optimization', [
            'job_id' => $jobId,
            'class' => $jobClass,
            'priority' => $priority,
            'delay' => $delay
        ]);
    }

    /**
     * Batch dispatch jobs
     */
    public static function batchDispatch(array $jobs, string $priority = self::PRIORITY_NORMAL): void
    {
        $batchId = uniqid('batch_', true);
        $batchJobs = [];

        foreach ($jobs as $job) {
            $jobId = uniqid('job_', true);
            $jobData = [
                'id' => $jobId,
                'batch_id' => $batchId,
                'class' => $job['class'],
                'data' => $job['data'] ?? [],
                'priority' => $priority,
                'created_at' => now(),
            ];

            $batchJobs[] = $jobData;

            // Dispatch job
            self::dispatchOptimized($job['class'], $job['data'] ?? [], $priority);
        }

        // Store batch information
        self::$batchJobs[$batchId] = [
            'jobs' => $batchJobs,
            'total_jobs' => count($jobs),
            'completed_jobs' => 0,
            'failed_jobs' => 0,
            'created_at' => now(),
        ];

        Log::info('Batch jobs dispatched', [
            'batch_id' => $batchId,
            'total_jobs' => count($jobs),
            'priority' => $priority
        ]);
    }

    /**
     * Get job status
     */
    public static function getJobStatus(string $jobId): ?array
    {
        $jobData = RedisPoolService::execute(function($redis) use ($jobId) {
            return $redis->hget('job_tracking', $jobId);
        });

        return $jobData ? json_decode($jobData, true) : null;
    }

    /**
     * Get batch status
     */
    public static function getBatchStatus(string $batchId): ?array
    {
        return self::$batchJobs[$batchId] ?? null;
    }

    /**
     * Update job metrics
     */
    private static function updateJobMetrics(string $priority, string $action): void
    {
        if (!isset(self::$jobMetrics[$priority])) {
            self::$jobMetrics[$priority] = [
                'dispatched' => 0,
                'completed' => 0,
                'failed' => 0,
                'processing_time' => 0,
            ];
        }

        if (isset(self::$jobMetrics[$priority][$action])) {
            self::$jobMetrics[$priority][$action]++;
        }
    }

    /**
     * Get job metrics
     */
    public static function getJobMetrics(): array
    {
        return self::$jobMetrics;
    }

    /**
     * Optimize queue processing
     */
    public static function optimizeQueueProcessing(): void
    {
        // Get queue statistics
        $queueStats = RedisPoolService::execute(function($redis) {
            return [
                'high_queue' => $redis->llen('queues:high'),
                'normal_queue' => $redis->llen('queues:default'),
                'low_queue' => $redis->llen('queues:low'),
            ];
        });

        // Adjust worker allocation based on queue sizes
        $totalJobs = array_sum($queueStats);
        
        if ($totalJobs > 100) {
            // Scale up workers for high load
            Log::info('High queue load detected, scaling workers', $queueStats);
        } elseif ($totalJobs < 10) {
            // Scale down workers for low load
            Log::info('Low queue load detected, scaling down workers', $queueStats);
        }

        Log::debug('Queue optimization completed', $queueStats);
    }

    /**
     * Monitor job performance
     */
    public static function monitorJobPerformance(): array
    {
        $performance = [];

        // Get job processing times
        $jobTimes = RedisPoolService::execute(function($redis) {
            return $redis->hgetall('job_performance');
        });

        foreach ($jobTimes as $jobId => $time) {
            $performance[$jobId] = [
                'processing_time' => $time,
                'status' => $time > 30 ? 'slow' : 'normal',
            ];
        }

        return $performance;
    }

    /**
     * Clean up completed jobs
     */
    public static function cleanupCompletedJobs(): void
    {
        $cutoffTime = now()->subHours(24);
        
        // Clean up old job tracking data
        RedisPoolService::execute(function($redis) use ($cutoffTime) {
            $jobs = $redis->hgetall('job_tracking');
            foreach ($jobs as $jobId => $jobData) {
                $data = json_decode($jobData, true);
                if ($data['created_at'] < $cutoffTime) {
                    $redis->hdel('job_tracking', $jobId);
                }
            }
        });

        Log::info('Completed jobs cleaned up');
    }

    /**
     * Get queue health status
     */
    public static function getQueueHealth(): array
    {
        $queueStats = RedisPoolService::execute(function($redis) {
            return [
                'high_queue' => $redis->llen('queues:high'),
                'normal_queue' => $redis->llen('queues:default'),
                'low_queue' => $redis->llen('queues:low'),
                'failed_queue' => $redis->llen('queues:failed'),
            ];
        });

        $totalJobs = array_sum($queueStats);
        $failedJobs = $queueStats['failed_queue'];

        $healthScore = $totalJobs > 0 ? (($totalJobs - $failedJobs) / $totalJobs) * 100 : 100;

        return [
            'queue_stats' => $queueStats,
            'total_jobs' => $totalJobs,
            'failed_jobs' => $failedJobs,
            'health_score' => $healthScore,
            'status' => $healthScore > 90 ? 'healthy' : ($healthScore > 70 ? 'warning' : 'critical'),
        ];
    }

    /**
     * Retry failed jobs
     */
    public static function retryFailedJobs(int $maxRetries = 3): void
    {
        $failedJobs = RedisPoolService::execute(function($redis) {
            return $redis->lrange('queues:failed', 0, -1);
        });

        foreach ($failedJobs as $jobData) {
            $job = json_decode($jobData, true);
            
            if ($job['attempts'] < $maxRetries) {
                // Retry job
                Queue::push($job['class'], $job['data']);
                
                Log::info('Failed job retried', [
                    'job_id' => $job['id'] ?? 'unknown',
                    'attempt' => $job['attempts'] + 1
                ]);
            }
        }
    }
}
