<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Redis;
use App\Services\AdvancedCacheService;

class CacheManagementCommand extends Command
{
    /**
     * The name and signature of the console command.
     */
    protected $signature = 'cache:manage 
                            {action : The action to perform (warm, clear, stats, invalidate)}
                            {--pattern=* : Pattern for cache operations}
                            {--user= : User ID for user-specific operations}
                            {--type= : Cache type for specific operations}';

    /**
     * The console command description.
     */
    protected $description = 'Manage application cache with advanced operations';

    private AdvancedCacheService $cacheService;

    public function __construct(AdvancedCacheService $cacheService)
    {
        parent::__construct();
        $this->cacheService = $cacheService;
    }

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $action = $this->argument('action');

        switch ($action) {
            case 'warm':
                return $this->warmCache();
            case 'clear':
                return $this->clearCache();
            case 'stats':
                return $this->showCacheStats();
            case 'invalidate':
                return $this->invalidateCache();
            default:
                $this->error("Unknown action: {$action}");
                return 1;
        }
    }

    /**
     * Warm up cache with frequently accessed data
     */
    private function warmCache(): int
    {
        $this->info('Warming up cache...');
        
        try {
            $this->cacheService->warmUpCache();
            $this->info('Cache warmed up successfully!');
            return 0;
        } catch (\Exception $e) {
            $this->error("Failed to warm cache: {$e->getMessage()}");
            return 1;
        }
    }

    /**
     * Clear cache based on pattern
     */
    private function clearCache(): int
    {
        $pattern = $this->option('pattern');
        
        $this->info("Clearing cache with pattern: {$pattern}");
        
        try {
            if ($pattern === '*') {
                Cache::flush();
                $this->info('All cache cleared!');
            } else {
                $this->cacheService->invalidateByPattern($pattern);
                $this->info("Cache cleared for pattern: {$pattern}");
            }
            return 0;
        } catch (\Exception $e) {
            $this->error("Failed to clear cache: {$e->getMessage()}");
            return 1;
        }
    }

    /**
     * Show cache statistics
     */
    private function showCacheStats(): int
    {
        $this->info('Cache Statistics:');
        $this->line('');
        
        try {
            // Get Redis info
            $redisInfo = Redis::info();
            
            $this->table(
                ['Metric', 'Value'],
                [
                    ['Used Memory', $this->formatBytes($redisInfo['used_memory'])],
                    ['Used Memory Peak', $this->formatBytes($redisInfo['used_memory_peak'])],
                    ['Connected Clients', $redisInfo['connected_clients']],
                    ['Total Commands Processed', $redisInfo['total_commands_processed']],
                    ['Keyspace Hits', $redisInfo['keyspace_hits']],
                    ['Keyspace Misses', $redisInfo['keyspace_misses']],
                    ['Hit Rate', $this->calculateHitRate($redisInfo['keyspace_hits'], $redisInfo['keyspace_misses'])],
                ]
            );
            
            // Get cache key counts by pattern
            $patterns = [
                'user:*' => 'User Cache',
                'teacher:*' => 'Teacher Cache',
                'reservation:*' => 'Reservation Cache',
                'message:*' => 'Message Cache',
                'chat:*' => 'Chat Cache',
                'stats:*' => 'Statistics Cache',
                'dashboard:*' => 'Dashboard Cache',
                'search:*' => 'Search Cache',
            ];
            
            $this->line('');
            $this->info('Cache Key Distribution:');
            
            $keyCounts = [];
            foreach ($patterns as $pattern => $description) {
                $keys = Redis::keys($pattern);
                $keyCounts[] = [$description, count($keys)];
            }
            
            $this->table(['Cache Type', 'Key Count'], $keyCounts);
            
            return 0;
        } catch (\Exception $e) {
            $this->error("Failed to get cache stats: {$e->getMessage()}");
            return 1;
        }
    }

    /**
     * Invalidate specific cache
     */
    private function invalidateCache(): int
    {
        $pattern = $this->option('pattern');
        $userId = $this->option('user');
        $type = $this->option('type');
        
        try {
            if ($userId) {
                $this->cacheService->invalidateUserCache($userId);
                $this->info("Cache invalidated for user: {$userId}");
            } elseif ($pattern) {
                $this->cacheService->invalidateByPattern($pattern);
                $this->info("Cache invalidated for pattern: {$pattern}");
            } elseif ($type) {
                $this->cacheService->invalidateByPattern("{$type}:*");
                $this->info("Cache invalidated for type: {$type}");
            } else {
                $this->error('Please specify --pattern, --user, or --type option');
                return 1;
            }
            
            return 0;
        } catch (\Exception $e) {
            $this->error("Failed to invalidate cache: {$e->getMessage()}");
            return 1;
        }
    }

    /**
     * Format bytes to human readable format
     */
    private function formatBytes(int $bytes): string
    {
        $units = ['B', 'KB', 'MB', 'GB'];
        $bytes = max($bytes, 0);
        $pow = floor(($bytes ? log($bytes) : 0) / log(1024));
        $pow = min($pow, count($units) - 1);
        
        $bytes /= (1 << (10 * $pow));
        
        return round($bytes, 2) . ' ' . $units[$pow];
    }

    /**
     * Calculate cache hit rate
     */
    private function calculateHitRate(int $hits, int $misses): string
    {
        $total = $hits + $misses;
        if ($total === 0) {
            return '0%';
        }
        
        $rate = ($hits / $total) * 100;
        return round($rate, 2) . '%';
    }
}
