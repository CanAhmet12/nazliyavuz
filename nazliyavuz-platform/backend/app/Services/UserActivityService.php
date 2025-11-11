<?php

namespace App\Services;

use App\Models\User;
use App\Models\Teacher;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

/**
 * User Activity Service
 * Handles real-time user activity tracking and online status management
 */
class UserActivityService
{
    const ACTIVITY_TIMEOUT = 300; // 5 minutes
    const CACHE_PREFIX = 'user_activity:';
    const ONLINE_STATUS_PREFIX = 'user_online:';

    /**
     * Update user activity timestamp
     */
    public function updateUserActivity(int $userId): void
    {
        try {
            // Update last_activity_at in database
            User::where('id', $userId)->update([
                'last_activity_at' => now()
            ]);

            // Cache user activity
            $cacheKey = self::CACHE_PREFIX . $userId;
            Cache::put($cacheKey, now(), self::ACTIVITY_TIMEOUT);

            // Update online status
            $this->updateOnlineStatus($userId, true);

            Log::info('User activity updated', [
                'user_id' => $userId,
                'timestamp' => now()->toISOString()
            ]);

        } catch (\Exception $e) {
            Log::error('Failed to update user activity', [
                'user_id' => $userId,
                'error' => $e->getMessage()
            ]);
        }
    }

    /**
     * Update user online status
     */
    public function updateOnlineStatus(int $userId, bool $isOnline): void
    {
        try {
            $user = User::find($userId);
            if (!$user) return;

            // Update teacher online_available status if user is teacher
            if ($user->role === 'teacher') {
                Teacher::where('user_id', $userId)->update([
                    'online_available' => $isOnline
                ]);
            }

            // Cache online status
            $cacheKey = self::ONLINE_STATUS_PREFIX . $userId;
            if ($isOnline) {
                Cache::put($cacheKey, true, self::ACTIVITY_TIMEOUT);
            } else {
                Cache::forget($cacheKey);
            }

            // Send real-time status update
            $this->sendRealTimeStatusUpdate($userId, $isOnline);

            Log::info('User online status updated', [
                'user_id' => $userId,
                'is_online' => $isOnline
            ]);

        } catch (\Exception $e) {
            Log::error('Failed to update online status', [
                'user_id' => $userId,
                'is_online' => $isOnline,
                'error' => $e->getMessage()
            ]);
        }
    }

    /**
     * Check if user is currently online
     */
    public function isUserOnline(int $userId): bool
    {
        $cacheKey = self::CACHE_PREFIX . $userId;
        $lastActivity = Cache::get($cacheKey);

        if (!$lastActivity) {
            return false;
        }

        // Check if activity is within timeout period
        $timeDiff = now()->diffInSeconds($lastActivity);
        return $timeDiff <= self::ACTIVITY_TIMEOUT;
    }

    /**
     * Get user's last activity
     */
    public function getUserLastActivity(int $userId): ?\Carbon\Carbon
    {
        $cacheKey = self::CACHE_PREFIX . $userId;
        return Cache::get($cacheKey);
    }

    /**
     * Clean up expired activities
     */
    public function cleanupExpiredActivities(): void
    {
        try {
            // Get all users with expired activities
            $expiredUsers = User::where('last_activity_at', '<', now()->subMinutes(5))->get();

            foreach ($expiredUsers as $user) {
                $this->updateOnlineStatus($user->id, false);
            }

            Log::info('Expired activities cleaned up', [
                'count' => $expiredUsers->count()
            ]);

        } catch (\Exception $e) {
            Log::error('Failed to cleanup expired activities', [
                'error' => $e->getMessage()
            ]);
        }
    }

    /**
     * Send real-time status update via Pusher
     */
    private function sendRealTimeStatusUpdate(int $userId, bool $isOnline): void
    {
        try {
            $pusher = app('pusher');
            
            // Get all conversations for this user
            $conversations = DB::table('chats')
                ->where('user1_id', $userId)
                ->orWhere('user2_id', $userId)
                ->get();

            foreach ($conversations as $conversation) {
                $otherUserId = $conversation->user1_id === $userId 
                    ? $conversation->user2_id 
                    : $conversation->user1_id;

                $channel = "user-status-{$otherUserId}";
                
                $pusher->trigger($channel, 'user-status-update', [
                    'user_id' => $userId,
                    'is_online' => $isOnline,
                    'timestamp' => now()->toISOString(),
                ]);
            }

        } catch (\Exception $e) {
            Log::error('Failed to send real-time status update', [
                'user_id' => $userId,
                'is_online' => $isOnline,
                'error' => $e->getMessage()
            ]);
        }
    }

    /**
     * Get online users count
     */
    public function getOnlineUsersCount(): int
    {
        return User::where('last_activity_at', '>=', now()->subMinutes(5))->count();
    }

    /**
     * Get online teachers count
     */
    public function getOnlineTeachersCount(): int
    {
        return Teacher::where('online_available', true)
            ->whereHas('user', function($query) {
                $query->where('last_activity_at', '>=', now()->subMinutes(5));
            })
            ->count();
    }
}
