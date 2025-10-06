<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Facades\Log;
use App\Services\RedisPoolService;

/**
 * Smart Caching Strategy Service
 * Multi-level caching with intelligent invalidation
 */
class SmartCacheService
{
    const CACHE_LEVEL_L1 = 'memory'; // In-memory cache
    const CACHE_LEVEL_L2 = 'redis';  // Redis cache
    const CACHE_LEVEL_L3 = 'database'; // Database cache

    private static array $memoryCache = [];
    private static array $cacheTags = [];
    private static array $cacheDependencies = [];

    /**
     * Get data with multi-level caching
     */
    public static function get(string $key, callable $callback = null, int $ttl = 3600, array $tags = []): mixed
    {
        // L1 Cache (Memory)
        if (isset(self::$memoryCache[$key])) {
            Log::debug('L1 cache hit', ['key' => $key]);
            return self::$memoryCache[$key];
        }

        // L2 Cache (Redis)
        try {
            $redisValue = RedisPoolService::execute(function($redis) use ($key) {
                return $redis->get($key);
            });
        } catch (\Exception $e) {
            $redisValue = null;
        }

        if ($redisValue !== null) {
            $data = unserialize($redisValue);
            self::$memoryCache[$key] = $data; // Store in L1
            Log::debug('L2 cache hit', ['key' => $key]);
            return $data;
        }

        // L3 Cache (Database) or Callback
        if ($callback) {
            $data = $callback();
            self::set($key, $data, $ttl, $tags);
            Log::debug('Cache miss, data generated', ['key' => $key]);
            return $data;
        }

        return null;
    }

    /**
     * Set data in multi-level cache
     */
    public static function set(string $key, mixed $data, int $ttl = 3600, array $tags = []): void
    {
        // L1 Cache (Memory)
        self::$memoryCache[$key] = $data;

        // L2 Cache (Redis)
        try {
            RedisPoolService::execute(function($redis) use ($key, $data, $ttl) {
                $redis->setex($key, $ttl, serialize($data));
            });
        } catch (\Exception $e) {
            Log::warning('Redis cache set failed: ' . $e->getMessage());
        }

        // Store cache tags and dependencies
        if (!empty($tags)) {
            self::$cacheTags[$key] = $tags;
            foreach ($tags as $tag) {
                if (!isset(self::$cacheDependencies[$tag])) {
                    self::$cacheDependencies[$tag] = [];
                }
                self::$cacheDependencies[$tag][] = $key;
            }
        }

        Log::debug('Data cached', ['key' => $key, 'ttl' => $ttl, 'tags' => $tags]);
    }

    /**
     * Invalidate cache by tags
     */
    public static function invalidateByTags(array $tags): void
    {
        foreach ($tags as $tag) {
            if (isset(self::$cacheDependencies[$tag])) {
                foreach (self::$cacheDependencies[$tag] as $key) {
                    self::forget($key);
                }
            }
        }

        Log::info('Cache invalidated by tags', ['tags' => $tags]);
    }

    /**
     * Forget specific cache key
     */
    public static function forget(string $key): void
    {
        // Remove from L1
        unset(self::$memoryCache[$key]);

        // Remove from L2
        RedisPoolService::execute(function($redis) use ($key) {
            $redis->del($key);
        });

        // Remove tags
        if (isset(self::$cacheTags[$key])) {
            foreach (self::$cacheTags[$key] as $tag) {
                if (isset(self::$cacheDependencies[$tag])) {
                    $index = array_search($key, self::$cacheDependencies[$tag]);
                    if ($index !== false) {
                        unset(self::$cacheDependencies[$tag][$index]);
                    }
                }
            }
            unset(self::$cacheTags[$key]);
        }

        Log::debug('Cache forgotten', ['key' => $key]);
    }

    /**
     * Warm up cache
     */
    public static function warmUp(array $cacheKeys): void
    {
        foreach ($cacheKeys as $key => $callback) {
            if (!isset(self::$memoryCache[$key])) {
                self::get($key, $callback);
            }
        }

        Log::info('Cache warmed up', ['keys' => array_keys($cacheKeys)]);
    }

    /**
     * Get cache statistics
     */
    public static function getStats(): array
    {
        $redisStats = RedisPoolService::execute(function($redis) {
            return $redis->info('memory');
        });

        return [
            'l1_cache_size' => count(self::$memoryCache),
            'l1_cache_memory' => memory_get_usage(true),
            'redis_memory' => $redisStats['used_memory'] ?? 0,
            'cache_tags' => count(self::$cacheTags),
            'cache_dependencies' => count(self::$cacheDependencies),
        ];
    }

    /**
     * Clear all caches
     */
    public static function clearAll(): void
    {
        // Clear L1
        self::$memoryCache = [];
        self::$cacheTags = [];
        self::$cacheDependencies = [];

        // Clear L2
        RedisPoolService::execute(function($redis) {
            $redis->flushdb();
        });

        Log::info('All caches cleared');
    }

    /**
     * Cache with automatic invalidation
     */
    public static function rememberWithInvalidation(string $key, callable $callback, int $ttl = 3600, array $invalidationRules = []): mixed
    {
        $data = self::get($key, $callback, $ttl);

        // Set up automatic invalidation
        if (!empty($invalidationRules)) {
            foreach ($invalidationRules as $rule) {
                self::setInvalidationRule($key, $rule);
            }
        }

        return $data;
    }

    /**
     * Set invalidation rule
     */
    private static function setInvalidationRule(string $key, array $rule): void
    {
        // Implementation for automatic cache invalidation based on rules
        // This could include time-based, event-based, or dependency-based invalidation
    }

    /**
     * Batch cache operations
     */
    public static function batchSet(array $data, int $ttl = 3600): void
    {
        foreach ($data as $key => $value) {
            self::set($key, $value, $ttl);
        }

        Log::info('Batch cache set', ['count' => count($data)]);
    }

    /**
     * Batch cache retrieval
     */
    public static function batchGet(array $keys): array
    {
        $results = [];
        $missingKeys = [];

        foreach ($keys as $key) {
            if (isset(self::$memoryCache[$key])) {
                $results[$key] = self::$memoryCache[$key];
            } else {
                $missingKeys[] = $key;
            }
        }

        // Fetch missing keys from Redis
        if (!empty($missingKeys)) {
            $redisResults = RedisPoolService::execute(function($redis) use ($missingKeys) {
                return $redis->mget($missingKeys);
            });

            foreach ($missingKeys as $index => $key) {
                if ($redisResults[$index] !== null) {
                    $results[$key] = unserialize($redisResults[$index]);
                    self::$memoryCache[$key] = $results[$key];
                }
            }
        }

        return $results;
    }
}
