<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Redis;
use App\Services\AdvancedCacheService;

class PerformanceMonitorCommand extends Command
{
    /**
     * The name and signature of the console command.
     */
    protected $signature = 'performance:monitor 
                            {--threshold=1000 : Response time threshold in milliseconds}
                            {--memory-threshold=128 : Memory usage threshold in MB}
                            {--cache-threshold=80 : Cache hit rate threshold in percentage}';

    /**
     * The console command description.
     */
    protected $description = 'Monitor application performance metrics';

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
        $this->info('🔍 Performance Monitoring Report');
        $this->line('');

        $thresholds = [
            'response_time' => $this->option('threshold'),
            'memory' => $this->option('memory-threshold'),
            'cache_hit_rate' => $this->option('cache-threshold'),
        ];

        $issues = [];

        // Check database performance
        $dbMetrics = $this->checkDatabasePerformance();
        $this->displayDatabaseMetrics($dbMetrics, $thresholds, $issues);

        // Check cache performance
        $cacheMetrics = $this->checkCachePerformance();
        $this->displayCacheMetrics($cacheMetrics, $thresholds, $issues);

        // Check memory usage
        $memoryMetrics = $this->checkMemoryUsage();
        $this->displayMemoryMetrics($memoryMetrics, $thresholds, $issues);

        // Check Redis performance
        $redisMetrics = $this->checkRedisPerformance();
        $this->displayRedisMetrics($redisMetrics, $thresholds, $issues);

        // Summary
        $this->line('');
        if (empty($issues)) {
            $this->info('✅ All performance metrics are within acceptable limits');
        } else {
            $this->error('⚠️ Performance issues detected:');
            foreach ($issues as $issue) {
                $this->line("   - {$issue}");
            }
        }

        return empty($issues) ? 0 : 1;
    }

    /**
     * Check database performance
     */
    private function checkDatabasePerformance(): array
    {
        $start = microtime(true);
        
        // Test a simple query
        $result = DB::select('SELECT 1 as test');
        
        $end = microtime(true);
        $responseTime = ($end - $start) * 1000; // Convert to milliseconds

        // Get slow query log count
        $slowQueries = DB::select("
            SELECT COUNT(*) as count 
            FROM information_schema.processlist 
            WHERE TIME > 2 AND COMMAND = 'Query'
        ");

        return [
            'response_time' => $responseTime,
            'slow_queries' => $slowQueries[0]->count ?? 0,
            'active_connections' => DB::select('SHOW STATUS LIKE "Threads_connected"')[0]->Value ?? 0,
        ];
    }

    /**
     * Check cache performance
     */
    private function checkCachePerformance(): array
    {
        $start = microtime(true);
        
        // Test cache operations
        $testKey = 'performance_test_' . time();
        $testData = ['test' => 'data', 'timestamp' => now()];
        
        Cache::put($testKey, $testData, 60);
        $retrieved = Cache::get($testKey);
        Cache::forget($testKey);
        
        $end = microtime(true);
        $responseTime = ($end - $start) * 1000;

        // Get Redis info
        $redisInfo = Redis::info();
        
        $hitRate = 0;
        if (($redisInfo['keyspace_hits'] + $redisInfo['keyspace_misses']) > 0) {
            $hitRate = ($redisInfo['keyspace_hits'] / 
                       ($redisInfo['keyspace_hits'] + $redisInfo['keyspace_misses'])) * 100;
        }

        return [
            'response_time' => $responseTime,
            'hit_rate' => $hitRate,
            'memory_usage' => $redisInfo['used_memory_human'] ?? 'Unknown',
            'connected_clients' => $redisInfo['connected_clients'] ?? 0,
        ];
    }

    /**
     * Check memory usage
     */
    private function checkMemoryUsage(): array
    {
        $memoryUsage = memory_get_usage(true);
        $memoryPeak = memory_get_peak_usage(true);
        
        return [
            'current' => $memoryUsage / 1024 / 1024, // MB
            'peak' => $memoryPeak / 1024 / 1024, // MB
            'limit' => ini_get('memory_limit'),
        ];
    }

    /**
     * Check Redis performance
     */
    private function checkRedisPerformance(): array
    {
        $redisInfo = Redis::info();
        
        return [
            'used_memory' => $redisInfo['used_memory'] ?? 0,
            'used_memory_peak' => $redisInfo['used_memory_peak'] ?? 0,
            'connected_clients' => $redisInfo['connected_clients'] ?? 0,
            'total_commands_processed' => $redisInfo['total_commands_processed'] ?? 0,
            'keyspace_hits' => $redisInfo['keyspace_hits'] ?? 0,
            'keyspace_misses' => $redisInfo['keyspace_misses'] ?? 0,
        ];
    }

    /**
     * Display database metrics
     */
    private function displayDatabaseMetrics(array $metrics, array $thresholds, array &$issues): void
    {
        $this->info('📊 Database Performance:');
        
        $responseTime = $metrics['response_time'];
        $slowQueries = $metrics['slow_queries'];
        $connections = $metrics['active_connections'];
        
        $this->table(['Metric', 'Value', 'Status'], [
            ['Response Time', number_format($responseTime, 2) . ' ms', 
             $responseTime > $thresholds['response_time'] ? '⚠️ High' : '✅ Good'],
            ['Slow Queries', $slowQueries, 
             $slowQueries > 0 ? '⚠️ Detected' : '✅ None'],
            ['Active Connections', $connections, 
             $connections > 100 ? '⚠️ High' : '✅ Normal'],
        ]);
        
        if ($responseTime > $thresholds['response_time']) {
            $issues[] = "Database response time is high: {$responseTime}ms";
        }
        if ($slowQueries > 0) {
            $issues[] = "Slow queries detected: {$slowQueries}";
        }
        if ($connections > 100) {
            $issues[] = "High number of active connections: {$connections}";
        }
        
        $this->line('');
    }

    /**
     * Display cache metrics
     */
    private function displayCacheMetrics(array $metrics, array $thresholds, array &$issues): void
    {
        $this->info('🗄️ Cache Performance:');
        
        $responseTime = $metrics['response_time'];
        $hitRate = $metrics['hit_rate'];
        $memoryUsage = $metrics['memory_usage'];
        $clients = $metrics['connected_clients'];
        
        $this->table(['Metric', 'Value', 'Status'], [
            ['Response Time', number_format($responseTime, 2) . ' ms', 
             $responseTime > $thresholds['response_time'] ? '⚠️ High' : '✅ Good'],
            ['Hit Rate', number_format($hitRate, 2) . '%', 
             $hitRate < $thresholds['cache_hit_rate'] ? '⚠️ Low' : '✅ Good'],
            ['Memory Usage', $memoryUsage, '✅ Normal'],
            ['Connected Clients', $clients, 
             $clients > 50 ? '⚠️ High' : '✅ Normal'],
        ]);
        
        if ($responseTime > $thresholds['response_time']) {
            $issues[] = "Cache response time is high: {$responseTime}ms";
        }
        if ($hitRate < $thresholds['cache_hit_rate']) {
            $issues[] = "Cache hit rate is low: {$hitRate}%";
        }
        if ($clients > 50) {
            $issues[] = "High number of Redis clients: {$clients}";
        }
        
        $this->line('');
    }

    /**
     * Display memory metrics
     */
    private function displayMemoryMetrics(array $metrics, array $thresholds, array &$issues): void
    {
        $this->info('💾 Memory Usage:');
        
        $current = $metrics['current'];
        $peak = $metrics['peak'];
        $limit = $metrics['limit'];
        
        $this->table(['Metric', 'Value', 'Status'], [
            ['Current Usage', number_format($current, 2) . ' MB', 
             $current > $thresholds['memory'] ? '⚠️ High' : '✅ Good'],
            ['Peak Usage', number_format($peak, 2) . ' MB', '✅ Normal'],
            ['Memory Limit', $limit, '✅ Normal'],
        ]);
        
        if ($current > $thresholds['memory']) {
            $issues[] = "High memory usage: {$current}MB";
        }
        
        $this->line('');
    }

    /**
     * Display Redis metrics
     */
    private function displayRedisMetrics(array $metrics, array $thresholds, array &$issues): void
    {
        $this->info('🔴 Redis Performance:');
        
        $usedMemory = $metrics['used_memory'];
        $usedMemoryPeak = $metrics['used_memory_peak'];
        $commandsProcessed = $metrics['total_commands_processed'];
        $hits = $metrics['keyspace_hits'];
        $misses = $metrics['keyspace_misses'];
        
        $this->table(['Metric', 'Value', 'Status'], [
            ['Used Memory', $this->formatBytes($usedMemory), '✅ Normal'],
            ['Peak Memory', $this->formatBytes($usedMemoryPeak), '✅ Normal'],
            ['Commands Processed', number_format($commandsProcessed), '✅ Normal'],
            ['Cache Hits', number_format($hits), '✅ Normal'],
            ['Cache Misses', number_format($misses), '✅ Normal'],
        ]);
        
        $this->line('');
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
}
