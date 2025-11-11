<?php

namespace App\Services;

use App\Models\User;
use App\Models\Notification;
use App\Models\AuditLog;
use App\Models\ScheduledNotification;
use App\Models\ScheduledNotificationLog;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\DB;

class AdminNotificationService
{
    protected $notificationService;

    public function __construct(NotificationService $notificationService)
    {
        $this->notificationService = $notificationService;
    }

    /**
     * Send bulk notification to users
     */
    public function sendBulkNotification(array $data): array
    {
        $validator = validator($data, [
            'title' => 'required|string|max:255',
            'message' => 'required|string|max:1000',
            'target_users' => 'required|array',
            'target_users.*' => 'in:all,students,teachers,admins',
            'type' => 'required|in:info,warning,success,error',
            'priority' => 'in:low,normal,high,urgent',
        ]);

        if ($validator->fails()) {
            throw new \InvalidArgumentException('Validation failed: ' . implode(', ', $validator->errors()->all()));
        }

        $targetUsers = $data['target_users'];
        $userQuery = User::query();

        // Filter users based on target
        if (!in_array('all', $targetUsers)) {
            $userQuery->whereIn('role', $targetUsers);
        }

        $users = $userQuery->get();
        $sentCount = 0;
        $failedCount = 0;

        DB::beginTransaction();
        try {
            foreach ($users as $user) {
                try {
                    // Create notification record
                    Notification::create([
                        'user_id' => $user->id,
                        'title' => $data['title'],
                        'message' => $data['message'],
                        'type' => $data['type'],
                        'priority' => $data['priority'] ?? 'normal',
                        'data' => json_encode([
                            'admin_notification' => true,
                            'bulk_notification' => true,
                        ]),
                    ]);

                    // Send email notification for high priority
                    if (($data['priority'] ?? 'normal') === 'urgent' || ($data['priority'] ?? 'normal') === 'high') {
                        $this->sendEmailNotification($user, $data);
                    }

                    $sentCount++;
                } catch (\Exception $e) {
                    Log::error('Failed to send notification to user', [
                        'user_id' => $user->id,
                        'error' => $e->getMessage(),
                    ]);
                    $failedCount++;
                }
            }

            // Log bulk notification action
            AuditLog::create([
                'user_id' => auth()->id(),
                'action' => 'bulk_notification_sent',
                'description' => "Bulk notification sent to {$sentCount} users",
                'severity' => $failedCount > 0 ? 'warning' : 'info',
                'meta' => [
                    'title' => $data['title'],
                    'target_users' => $targetUsers,
                    'sent_count' => $sentCount,
                    'failed_count' => $failedCount,
                ],
            ]);

            DB::commit();

            return [
                'success' => true,
                'sent_count' => $sentCount,
                'failed_count' => $failedCount,
                'total_targeted' => $users->count(),
            ];
        } catch (\Exception $e) {
            DB::rollBack();
            throw $e;
        }
    }

    /**
     * Send email notification
     */
    private function sendEmailNotification(User $user, array $data): void
    {
        try {
            Mail::send('emails.admin-notification', [
                'user' => $user,
                'title' => $data['title'],
                'message' => $data['message'],
                'type' => $data['type'],
            ], function ($message) use ($user, $data) {
                $message->to($user->email, $user->name)
                    ->subject('[Admin] ' . $data['title']);
            });
        } catch (\Exception $e) {
            Log::error('Failed to send email notification', [
                'user_id' => $user->id,
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * Send system maintenance notification
     */
    public function sendMaintenanceNotification(array $data): array
    {
        $data['title'] = 'Sistem Bakım Bildirimi';
        $data['type'] = 'warning';
        $data['priority'] = 'high';

        return $this->sendBulkNotification($data);
    }

    /**
     * Send security alert notification
     */
    public function sendSecurityAlert(array $data): array
    {
        $data['type'] = 'error';
        $data['priority'] = 'urgent';

        return $this->sendBulkNotification($data);
    }

    /**
     * Send feature announcement
     */
    public function sendFeatureAnnouncement(array $data): array
    {
        $data['type'] = 'info';
        $data['priority'] = 'normal';

        return $this->sendBulkNotification($data);
    }

    /**
     * Send user-specific notification
     */
    public function sendUserNotification(int $userId, array $data): bool
    {
        $user = User::findOrFail($userId);

        try {
            Notification::create([
                'user_id' => $user->id,
                'title' => $data['title'],
                'message' => $data['message'],
                'type' => $data['type'] ?? 'info',
                'priority' => $data['priority'] ?? 'normal',
                'data' => json_encode([
                    'admin_notification' => true,
                    'targeted_notification' => true,
                ]),
            ]);

            // Log the action
            AuditLog::create([
                'user_id' => auth()->id(),
                'action' => 'user_notification_sent',
                'description' => "Notification sent to user {$user->name}",
                'severity' => 'info',
                'meta' => [
                    'target_user_id' => $userId,
                    'title' => $data['title'],
                ],
            ]);

            return true;
        } catch (\Exception $e) {
            Log::error('Failed to send user notification', [
                'user_id' => $userId,
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }

    /**
     * Get notification statistics
     */
    public function getNotificationStats(): array
    {
        $totalNotifications = Notification::count();
        $unreadNotifications = Notification::where('read_at', null)->count();
        $todayNotifications = Notification::whereDate('created_at', today())->count();
        $thisWeekNotifications = Notification::where('created_at', '>=', now()->subWeek())->count();

        return [
            'total' => $totalNotifications,
            'unread' => $unreadNotifications,
            'today' => $todayNotifications,
            'this_week' => $thisWeekNotifications,
            'read_rate' => $totalNotifications > 0 ? round((($totalNotifications - $unreadNotifications) / $totalNotifications) * 100, 2) : 0,
        ];
    }

    /**
     * Get notification analytics
     */
    public function getNotificationAnalytics(): array
    {
        $notificationsByType = Notification::select('type', DB::raw('count(*) as count'))
            ->groupBy('type')
            ->get()
            ->pluck('count', 'type')
            ->toArray();

        $notificationsByPriority = Notification::select('priority', DB::raw('count(*) as count'))
            ->groupBy('priority')
            ->get()
            ->pluck('count', 'priority')
            ->toArray();

        $dailyNotifications = Notification::select(DB::raw('DATE(created_at) as date'), DB::raw('count(*) as count'))
            ->where('created_at', '>=', now()->subDays(30))
            ->groupBy('date')
            ->orderBy('date')
            ->get()
            ->toArray();

        $topSenders = ScheduledNotification::select('created_by', DB::raw('COUNT(*) as count'))
            ->whereNotNull('created_by')
            ->with('creator:id,name,email')
            ->groupBy('created_by')
            ->orderByDesc('count')
            ->limit(5)
            ->get()
            ->map(fn ($item) => [
                'user_id' => $item->created_by,
                'count' => (int) $item->count,
                'name' => optional($item->creator)->name,
                'email' => optional($item->creator)->email,
            ])
            ->toArray();

        $topTemplates = ScheduledNotification::select('template_id', DB::raw('COUNT(*) as count'))
            ->whereNotNull('template_id')
            ->with('template:id,name,slug')
            ->groupBy('template_id')
            ->orderByDesc('count')
            ->limit(5)
            ->get()
            ->map(fn ($item) => [
                'template_id' => $item->template_id,
                'name' => optional($item->template)->name,
                'slug' => optional($item->template)->slug,
                'count' => (int) $item->count,
            ])
            ->toArray();

        $targetBreakdown = ScheduledNotification::select('target_type', DB::raw('COUNT(*) as count'))
            ->groupBy('target_type')
            ->get()
            ->pluck('count', 'target_type')
            ->toArray();

        $channelUsage = ScheduledNotification::select('channels')
            ->get()
            ->reduce(function ($carry, $notification) {
                $channels = $notification->channels ?? [];
                if (is_array($channels)) {
                    foreach ($channels as $channel => $enabled) {
                        if ($enabled) {
                            $carry[$channel] = ($carry[$channel] ?? 0) + 1;
                        }
                    }
                }

                return $carry;
            }, []);

        $totalJobs = ScheduledNotificationLog::count();
        $sentJobs = ScheduledNotificationLog::where('status', 'sent')->count();
        $failedJobs = ScheduledNotificationLog::where('status', 'failed')->count();

        $messagesSent = (int) ScheduledNotificationLog::where('status', 'sent')->sum('sent_count');
        $messagesFailed = (int) ScheduledNotificationLog::sum('fail_count');

        $delivery = [
            'total_jobs' => $totalJobs,
            'sent_jobs' => $sentJobs,
            'failed_jobs' => $failedJobs,
            'processing_jobs' => ScheduledNotificationLog::where('status', 'processing')->count(),
            'success_rate' => $totalJobs > 0 ? round(($sentJobs / $totalJobs) * 100, 2) : 0,
            'messages_sent' => $messagesSent,
            'messages_failed' => $messagesFailed,
        ];

        $recentFailures = ScheduledNotificationLog::with(['scheduledNotification:id,title'])
            ->where('status', 'failed')
            ->orderByDesc('created_at')
            ->limit(5)
            ->get()
            ->map(fn ($log) => [
                'id' => $log->id,
                'scheduled_notification_id' => $log->scheduled_notification_id,
                'title' => optional($log->scheduledNotification)->title,
                'error_message' => $log->error_message,
                'fail_count' => (int) $log->fail_count,
                'finished_at' => optional($log->finished_at)->toIso8601String(),
            ])
            ->toArray();

        return [
            'by_type' => $notificationsByType,
            'by_priority' => $notificationsByPriority,
            'daily_trend' => $dailyNotifications,
            'top_senders' => $topSenders,
            'top_templates' => $topTemplates,
            'target_breakdown' => $targetBreakdown,
            'channel_usage' => $channelUsage,
            'delivery' => $delivery,
            'recent_failures' => $recentFailures,
        ];
    }

    /**
     * Mark notifications as read
     */
    public function markNotificationsAsRead(array $notificationIds): bool
    {
        try {
            Notification::whereIn('id', $notificationIds)
                ->update(['read_at' => now()]);

            return true;
        } catch (\Exception $e) {
            Log::error('Failed to mark notifications as read', [
                'notification_ids' => $notificationIds,
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }

    /**
     * Delete old notifications
     */
    public function cleanupOldNotifications(int $daysOld = 90): int
    {
        $deletedCount = Notification::where('created_at', '<', now()->subDays($daysOld))->delete();

        Log::info('Old notifications cleaned up', [
            'deleted_count' => $deletedCount,
            'days_old' => $daysOld,
        ]);

        return $deletedCount;
    }
}
