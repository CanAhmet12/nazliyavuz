<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Redis;

class HealthCheckCommand extends Command
{
    /**
     * The name and signature of the console command.
     */
    protected $signature = 'health:check';

    /**
     * The console command description.
     */
    protected $description = 'Check application health status';

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $checks = [
            'database' => $this->checkDatabase(),
            'cache' => $this->checkCache(),
            'redis' => $this->checkRedis(),
            'storage' => $this->checkStorage(),
            'queue' => $this->checkQueue(),
        ];

        $allHealthy = true;
        $output = [];

        foreach ($checks as $service => $status) {
            $output[] = sprintf('%s: %s', ucfirst($service), $status ? 'OK' : 'FAIL');
            if (!$status) {
                $allHealthy = false;
            }
        }

        if ($allHealthy) {
            $this->info('All services are healthy');
            return 0;
        } else {
            $this->error('Some services are unhealthy');
            foreach ($output as $line) {
                $this->line($line);
            }
            return 1;
        }
    }

    /**
     * Check database connection
     */
    private function checkDatabase(): bool
    {
        try {
            DB::connection()->getPdo();
            return true;
        } catch (\Exception $e) {
            return false;
        }
    }

    /**
     * Check cache system
     */
    private function checkCache(): bool
    {
        try {
            Cache::put('health_check', 'ok', 60);
            return Cache::get('health_check') === 'ok';
        } catch (\Exception $e) {
            return false;
        }
    }

    /**
     * Check Redis connection
     */
    private function checkRedis(): bool
    {
        try {
            Redis::ping();
            return true;
        } catch (\Exception $e) {
            return false;
        }
    }

    /**
     * Check storage permissions
     */
    private function checkStorage(): bool
    {
        try {
            $storagePath = storage_path();
            $cachePath = storage_path('framework/cache');
            $logsPath = storage_path('logs');
            $sessionsPath = storage_path('framework/sessions');

            return is_writable($storagePath) &&
                   is_writable($cachePath) &&
                   is_writable($logsPath) &&
                   is_writable($sessionsPath);
        } catch (\Exception $e) {
            return false;
        }
    }

    /**
     * Check queue system
     */
    private function checkQueue(): bool
    {
        try {
            // Check if queue connection is working
            $connection = config('queue.default');
            $queue = app('queue')->connection($connection);
            
            // Try to get queue size (this tests the connection)
            $queue->size();
            return true;
        } catch (\Exception $e) {
            return false;
        }
    }
}
