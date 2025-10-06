<?php

namespace App\Services;

use App\Models\Notification;
use App\Models\User;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

class NotificationService
{
    /**
     * Create a new notification
     */
    public function createNotification(User $user, string $type, string $title, string $message, array $data = [], string $actionUrl = null, string $actionText = null): Notification
    {
        try {
            $notification = Notification::create([
                'user_id' => $user->id,
                'type' => $type,
                'title' => $title,
                'message' => $message,
                'data' => $data,
                'action_url' => $actionUrl,
                'action_text' => $actionText,
            ]);

            Log::info('Notification created', [
                'user_id' => $user->id,
                'type' => $type,
                'title' => $title,
            ]);

            return $notification;
        } catch (\Exception $e) {
            Log::error('Failed to create notification', [
                'user_id' => $user->id,
                'type' => $type,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Send notification to multiple users
     */
    public function sendBulkNotification(array $userIds, string $type, string $title, string $message, array $data = [], string $actionUrl = null, string $actionText = null): int
    {
        $count = 0;
        
        foreach ($userIds as $userId) {
            try {
                $user = User::find($userId);
                if ($user) {
                    $this->createNotification($user, $type, $title, $message, $data, $actionUrl, $actionText);
                    $count++;
                }
            } catch (\Exception $e) {
                Log::error('Failed to send bulk notification to user', [
                    'user_id' => $userId,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        Log::info('Bulk notification sent', [
            'total_users' => count($userIds),
            'successful' => $count,
            'type' => $type,
        ]);

        return $count;
    }

    /**
     * Send email notification
     */
    public function sendEmailNotification(User $user, string $subject, string $template, array $data = []): bool
    {
        try {
            Mail::send($template, $data, function ($message) use ($user, $subject) {
                $message->to($user->email, $user->name)
                        ->subject($subject);
            });

            Log::info('Email notification sent', [
                'user_id' => $user->id,
                'email' => $user->email,
                'subject' => $subject,
            ]);

            return true;
        } catch (\Exception $e) {
            Log::error('Failed to send email notification', [
                'user_id' => $user->id,
                'email' => $user->email,
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }

    /**
     * Mark notification as read
     */
    public function markAsRead(Notification $notification): bool
    {
        try {
            $notification->markAsRead();
            return true;
        } catch (\Exception $e) {
            Log::error('Failed to mark notification as read', [
                'notification_id' => $notification->id,
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }

    /**
     * Mark all notifications as read for user
     */
    public function markAllAsRead(User $user): int
    {
        try {
            $count = Notification::where('user_id', $user->id)
                ->where('is_read', false)
                ->update([
                    'is_read' => true,
                    'read_at' => now(),
                ]);

            Log::info('All notifications marked as read', [
                'user_id' => $user->id,
                'count' => $count,
            ]);

            return $count;
        } catch (\Exception $e) {
            Log::error('Failed to mark all notifications as read', [
                'user_id' => $user->id,
                'error' => $e->getMessage(),
            ]);
            return 0;
        }
    }

    /**
     * Delete notification
     */
    public function deleteNotification(Notification $notification): bool
    {
        try {
            $notification->delete();
            return true;
        } catch (\Exception $e) {
            Log::error('Failed to delete notification', [
                'notification_id' => $notification->id,
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }

    /**
     * Get notification statistics for user
     */
    public function getStatistics(User $user): array
    {
        try {
            $total = Notification::where('user_id', $user->id)->count();
            $unread = Notification::where('user_id', $user->id)->where('is_read', false)->count();
            $read = $total - $unread;

            // Get notifications by type
            $byType = Notification::where('user_id', $user->id)
                ->selectRaw('type, COUNT(*) as count')
                ->groupBy('type')
                ->get()
                ->pluck('count', 'type');

            return [
                'total' => $total,
                'unread' => $unread,
                'read' => $read,
                'by_type' => $byType,
            ];
        } catch (\Exception $e) {
            Log::error('Failed to get notification statistics', [
                'user_id' => $user->id,
                'error' => $e->getMessage(),
            ]);
            return [
                'total' => 0,
                'unread' => 0,
                'read' => 0,
                'by_type' => [],
            ];
        }
    }

    /**
     * Send video call notification
     */
    public function sendVideoCallNotification(int $receiverId, string $callerName, string $callType, string $callId): void
    {
        try {
            $user = User::find($receiverId);
            if (!$user) {
                Log::warning('Video call notification: User not found', ['receiver_id' => $receiverId]);
                return;
            }

            $title = "Video Çağrısı";
            $message = "{$callerName} size bir {$callType} çağrısı gönderdi";
            
            $this->createNotification(
                $user,
                'video_call',
                $title,
                $message,
                [
                    'call_id' => $callId,
                    'call_type' => $callType,
                    'caller_name' => $callerName,
                    'action' => 'video_call_invitation'
                ],
                "/video-call/{$callId}",
                "Çağrıyı Yanıtla"
            );

            Log::info('Video call notification sent', [
                'receiver_id' => $receiverId,
                'caller_name' => $callerName,
                'call_type' => $callType,
                'call_id' => $callId
            ]);

        } catch (\Exception $e) {
            Log::error('Failed to send video call notification', [
                'receiver_id' => $receiverId,
                'error' => $e->getMessage()
            ]);
        }
    }

    /**
     * Clean up old notifications
     */
    public function cleanupOldNotifications(int $daysOld = 30): int
    {
        try {
            $count = Notification::where('created_at', '<', now()->subDays($daysOld))
                ->where('is_read', true)
                ->delete();

            Log::info('Old notifications cleaned up', [
                'count' => $count,
                'days_old' => $daysOld,
            ]);

            return $count;
        } catch (\Exception $e) {
            Log::error('Failed to cleanup old notifications', [
                'error' => $e->getMessage(),
            ]);
            return 0;
        }
    }
}
