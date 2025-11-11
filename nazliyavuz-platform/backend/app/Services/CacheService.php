<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;

class CacheService
{
    /**
     * Invalidate user cache
     */
    public function invalidateUserCache(int $userId): void
    {
        // Clear user-specific cache keys
        $cacheKeys = [
            "user_reservations_{$userId}",
            "user_profile_{$userId}",
            "user_notifications_{$userId}",
            "user_assignments_{$userId}",
        ];
        
        foreach ($cacheKeys as $key) {
            Cache::forget($key);
        }
    }
    
    /**
     * Clear all cache
     */
    public function clearAllCache(): void
    {
        Cache::flush();
    }
    
    /**
     * Get cache statistics
     */
    public function getCacheStats(): array
    {
        return [
            'driver' => Cache::getStore()->getPrefix(),
            'status' => 'active'
        ];
    }
}