<?php

namespace App\Jobs;

use App\Models\ScheduledNotification;
use App\Services\ScheduledNotificationService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class DispatchScheduledNotificationJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;
    public string $queue = 'notifications';
    public ?ScheduledNotification $notification = null;

    /**
     * Create a new job instance.
     */
    public function __construct(ScheduledNotification $notification)
    {
        $this->notification = $notification;
    }

    /**
     * Execute the job.
     */
    public function handle(ScheduledNotificationService $service): void
    {
        $notification = ScheduledNotification::find($this->notification->id);

        if (!$notification) {
            return;
        }

        if (!in_array($notification->status, ['queued', 'scheduled'])) {
            Log::info('Scheduled notification skipped due to status', [
                'scheduled_notification_id' => $notification->id,
                'status' => $notification->status,
            ]);

            return;
        }

        $service->handleDispatch($notification);
    }

    public function failed(\Throwable $exception): void
    {
        Log::error('DispatchScheduledNotificationJob failed', [
            'scheduled_notification_id' => $this->notification?->id,
            'error' => $exception->getMessage(),
        ]);
    }
}

