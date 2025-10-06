<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;
use Illuminate\Database\Eloquent\Builder;

/**
 * Advanced Database Query Optimizer
 * Enterprise-level query optimization and monitoring
 */
class DatabaseOptimizerService
{
    private static array $queryCache = [];
    private static array $slowQueries = [];
    private static float $slowQueryThreshold = 0.1; // 100ms

    /**
     * Optimize query with caching and monitoring
     */
    public static function optimizeQuery(Builder $query, string $cacheKey = null, int $cacheTtl = 3600)
    {
        $startTime = microtime(true);
        
        // Check cache first
        if ($cacheKey && Cache::has($cacheKey)) {
            Log::info('Query cache hit', ['key' => $cacheKey]);
            return Cache::get($cacheKey);
        }

        // Execute query
        $result = $query->get();
        $executionTime = microtime(true) - $startTime;

        // Log slow queries
        if ($executionTime > self::$slowQueryThreshold) {
            self::logSlowQuery($query->toSql(), $executionTime, $query->getBindings());
        }

        // Cache result if cache key provided
        if ($cacheKey) {
            Cache::put($cacheKey, $result, $cacheTtl);
            Log::info('Query cached', ['key' => $cacheKey, 'ttl' => $cacheTtl]);
        }

        return $result;
    }

    /**
     * Execute raw query with optimization
     */
    public static function executeRawQuery(string $sql, array $bindings = [], string $cacheKey = null, int $cacheTtl = 3600)
    {
        $startTime = microtime(true);
        
        // Check cache first
        if ($cacheKey && Cache::has($cacheKey)) {
            return Cache::get($cacheKey);
        }

        // Execute query
        $result = DB::select($sql, $bindings);
        $executionTime = microtime(true) - $startTime;

        // Log slow queries
        if ($executionTime > self::$slowQueryThreshold) {
            self::logSlowQuery($sql, $executionTime, $bindings);
        }

        // Cache result
        if ($cacheKey) {
            Cache::put($cacheKey, $result, $cacheTtl);
        }

        return $result;
    }

    /**
     * Get query execution plan
     */
    public static function getQueryPlan(string $sql, array $bindings = []): array
    {
        $explainSql = "EXPLAIN " . $sql;
        return DB::select($explainSql, $bindings);
    }

    /**
     * Analyze table for optimization suggestions
     */
    public static function analyzeTable(string $tableName): array
    {
        $analysis = DB::select("ANALYZE TABLE {$tableName}");
        return $analysis;
    }

    /**
     * Get table statistics
     */
    public static function getTableStats(string $tableName): array
    {
        $stats = DB::select("SHOW TABLE STATUS LIKE '{$tableName}'");
        return $stats[0] ?? [];
    }

    /**
     * Log slow query
     */
    private static function logSlowQuery(string $sql, float $executionTime, array $bindings): void
    {
        $slowQuery = [
            'sql' => $sql,
            'execution_time' => $executionTime,
            'bindings' => $bindings,
            'timestamp' => now(),
        ];

        self::$slowQueries[] = $slowQuery;

        Log::warning('Slow query detected', $slowQuery);

        // Keep only last 100 slow queries
        if (count(self::$slowQueries) > 100) {
            self::$slowQueries = array_slice(self::$slowQueries, -100);
        }
    }

    /**
     * Get slow queries report
     */
    public static function getSlowQueriesReport(): array
    {
        return [
            'total_slow_queries' => count(self::$slowQueries),
            'threshold' => self::$slowQueryThreshold,
            'queries' => self::$slowQueries,
        ];
    }

    /**
     * Clear query cache
     */
    public static function clearQueryCache(): void
    {
        self::$queryCache = [];
        Cache::flush();
    }

    /**
     * Get database performance metrics
     */
    public static function getPerformanceMetrics(): array
    {
        $metrics = [];

        // Connection count
        $metrics['connections'] = DB::select("SHOW STATUS LIKE 'Threads_connected'")[0]->Value ?? 0;
        
        // Query cache hit ratio
        $cacheHits = DB::select("SHOW STATUS LIKE 'Qcache_hits'")[0]->Value ?? 0;
        $cacheInserts = DB::select("SHOW STATUS LIKE 'Qcache_inserts'")[0]->Value ?? 0;
        $metrics['query_cache_hit_ratio'] = $cacheInserts > 0 ? ($cacheHits / ($cacheHits + $cacheInserts)) * 100 : 0;

        // Slow query count
        $metrics['slow_queries'] = DB::select("SHOW STATUS LIKE 'Slow_queries'")[0]->Value ?? 0;

        // Table locks
        $metrics['table_locks_waited'] = DB::select("SHOW STATUS LIKE 'Table_locks_waited'")[0]->Value ?? 0;

        return $metrics;
    }

    /**
     * Optimize database indexes
     */
    public static function optimizeIndexes(): array
    {
        $tables = ['users', 'teachers', 'reservations', 'lessons', 'ratings', 'notifications'];
        $results = [];

        foreach ($tables as $table) {
            $result = DB::statement("OPTIMIZE TABLE {$table}");
            $results[$table] = $result;
        }

        return $results;
    }
}
