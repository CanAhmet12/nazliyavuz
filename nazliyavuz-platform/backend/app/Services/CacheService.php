<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

class CacheService
{
    /**
     * Cache duration constants
     */
    const SHORT_TERM = 300; // 5 minutes
    const MEDIUM_TERM = 1800; // 30 minutes
    const LONG_TERM = 3600; // 1 hour
    const VERY_LONG_TERM = 86400; // 24 hours

    /**
     * Cache key prefixes
     */
    const USER_PREFIX = 'user:';
    const TEACHER_PREFIX = 'teacher:';
    const CATEGORY_PREFIX = 'category:';
    const RESERVATION_PREFIX = 'reservation:';
    const SEARCH_PREFIX = 'search:';
    const ANALYTICS_PREFIX = 'analytics:';

    /**
     * Cache user data
     */
    public function cacheUser(int $userId, array $userData, int $duration = self::MEDIUM_TERM): void
    {
        $key = self::USER_PREFIX . $userId;
        Cache::put($key, $userData, $duration);
        
        Log::debug('User cached', ['user_id' => $userId, 'duration' => $duration]);
    }

    /**
     * Get cached user data
     */
    public function getCachedUser(int $userId): ?array
    {
        $key = self::USER_PREFIX . $userId;
        return Cache::get($key);
    }

    /**
     * Cache teacher data with relationships
     */
    public function cacheTeacher(int $teacherId, array $teacherData, int $duration = self::MEDIUM_TERM): void
    {
        $key = self::TEACHER_PREFIX . $teacherId;
        Cache::put($key, $teacherData, $duration);
        
        Log::debug('Teacher cached', ['teacher_id' => $teacherId, 'duration' => $duration]);
    }

    /**
     * Get cached teacher data
     */
    public function getCachedTeacher(int $teacherId): ?array
    {
        $key = self::TEACHER_PREFIX . $teacherId;
        return Cache::get($key);
    }

    /**
     * Cache categories list
     */
    public function cacheCategories(array $categories, int $duration = self::LONG_TERM): void
    {
        $key = self::CATEGORY_PREFIX . 'all';
        Cache::put($key, $categories, $duration);
        
        Log::debug('Categories cached', ['count' => count($categories), 'duration' => $duration]);
    }

    /**
     * Get cached categories
     */
    public function getCachedCategories(): ?array
    {
        $key = self::CATEGORY_PREFIX . 'all';
        return Cache::get($key);
    }

    /**
     * Cache search results
     */
    public function cacheSearchResults(string $query, array $filters, array $results, int $duration = self::SHORT_TERM): void
    {
        $key = self::SEARCH_PREFIX . md5($query . serialize($filters));
        Cache::put($key, $results, $duration);
        
        Log::debug('Search results cached', ['query' => $query, 'duration' => $duration]);
    }

    /**
     * Get cached search results
     */
    public function getCachedSearchResults(string $query, array $filters): ?array
    {
        $key = self::SEARCH_PREFIX . md5($query . serialize($filters));
        return Cache::get($key);
    }

    /**
     * Cache analytics data
     */
    public function cacheAnalytics(string $type, string $period, array $data, int $duration = self::MEDIUM_TERM): void
    {
        $key = self::ANALYTICS_PREFIX . $type . ':' . $period;
        Cache::put($key, $data, $duration);
        
        Log::debug('Analytics cached', ['type' => $type, 'period' => $period, 'duration' => $duration]);
    }

    /**
     * Get cached analytics data
     */
    public function getCachedAnalytics(string $type, string $period): ?array
    {
        $key = self::ANALYTICS_PREFIX . $type . ':' . $period;
        return Cache::get($key);
    }

    /**
     * Cache reservation data
     */
    public function cacheReservation(int $reservationId, array $reservationData, int $duration = self::MEDIUM_TERM): void
    {
        $key = self::RESERVATION_PREFIX . $reservationId;
        Cache::put($key, $reservationData, $duration);
        
        Log::debug('Reservation cached', ['reservation_id' => $reservationId, 'duration' => $duration]);
    }

    /**
     * Get cached reservation data
     */
    public function getCachedReservation(int $reservationId): ?array
    {
        $key = self::RESERVATION_PREFIX . $reservationId;
        return Cache::get($key);
    }

    /**
     * Invalidate user cache
     */
    public function invalidateUser(int $userId): void
    {
        $key = self::USER_PREFIX . $userId;
        Cache::forget($key);
        
        Log::debug('User cache invalidated', ['user_id' => $userId]);
    }

    /**
     * Invalidate teacher cache
     */
    public function invalidateTeacher(int $teacherId): void
    {
        $key = self::TEACHER_PREFIX . $teacherId;
        Cache::forget($key);
        
        Log::debug('Teacher cache invalidated', ['teacher_id' => $teacherId]);
    }

    /**
     * Invalidate categories cache
     */
    public function invalidateCategories(): void
    {
        $key = self::CATEGORY_PREFIX . 'all';
        Cache::forget($key);
        
        Log::debug('Categories cache invalidated');
    }

    /**
     * Invalidate search cache
     */
    public function invalidateSearchCache(): void
    {
        // This would need to be implemented with cache tags or pattern matching
        // For now, we'll log the action
        Log::debug('Search cache invalidated');
    }

    /**
     * Invalidate analytics cache
     */
    public function invalidateAnalytics(string $type = null): void
    {
        if ($type) {
            $key = self::ANALYTICS_PREFIX . $type . ':';
            // This would need pattern matching to clear all analytics for a type
            Log::debug('Analytics cache invalidated', ['type' => $type]);
        } else {
            Log::debug('All analytics cache invalidated');
        }
    }

    /**
     * Cache with tags for easier invalidation
     */
    public function cacheWithTags(string $key, $value, array $tags, int $duration = self::MEDIUM_TERM): void
    {
        Cache::tags($tags)->put($key, $value, $duration);
        
        Log::debug('Data cached with tags', ['key' => $key, 'tags' => $tags, 'duration' => $duration]);
    }

    /**
     * Invalidate cache by tags
     */
    public function invalidateByTags(array $tags): void
    {
        Cache::tags($tags)->flush();
        
        Log::debug('Cache invalidated by tags', ['tags' => $tags]);
    }

    /**
     * Get cache statistics
     */
    public function getCacheStats(): array
    {
        // This would depend on the cache driver implementation
        return [
            'driver' => config('cache.default'),
            'store' => config('cache.stores.' . config('cache.default')),
            'memory_usage' => memory_get_usage(true),
            'peak_memory' => memory_get_peak_usage(true),
        ];
    }

    /**
     * Warm up cache with frequently accessed data
     */
    public function warmUpCache(): void
    {
        Log::info('Starting cache warm-up');
        
        try {
            // Warm up categories
            $this->warmUpCategories();
            
            // Warm up popular teachers
            $this->warmUpPopularTeachers();
            
            // Warm up analytics
            $this->warmUpAnalytics();
            
            Log::info('Cache warm-up completed');
        } catch (\Exception $e) {
            Log::error('Cache warm-up failed', ['error' => $e->getMessage()]);
        }
    }

    /**
     * Warm up categories cache
     */
    private function warmUpCategories(): void
    {
        // This would typically call the Category model to get all categories
        Log::debug('Warming up categories cache');
    }

    /**
     * Warm up popular teachers cache
     */
    private function warmUpPopularTeachers(): void
    {
        // This would typically call the Teacher model to get popular teachers
        Log::debug('Warming up popular teachers cache');
    }

    /**
     * Warm up analytics cache
     */
    private function warmUpAnalytics(): void
    {
        // This would typically call the AdminController analytics methods
        Log::debug('Warming up analytics cache');
    }
}
