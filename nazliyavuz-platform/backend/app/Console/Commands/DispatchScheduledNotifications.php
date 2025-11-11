<?php

namespace App\Console\Commands;

use App\Models\ScheduledNotification;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;

class DispatchScheduledNotifications extends Command
{
    /**
     * The name and signature of the console command.
     */
    protected $signature = 'notifications:dispatch-scheduled {--limit=50}';

    /**
     * The console command description.
     */
    protected $description = 'Dispatch scheduled notifications that are due';

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        if (config('queue.default') === 'sync') {
            $message = 'Queue connection is set to "sync". Scheduled notifications require an async queue driver.';
            $this->error($message);
            Log::warning('notifications:dispatch-scheduled aborted due to sync queue driver', [
                'queue_connection' => config('queue.default'),
            ]);

            return self::FAILURE;
        }

        $limit = (int) $this->option('limit');

        $notifications = ScheduledNotification::query()
            ->whereIn('status', ['scheduled', 'queued'])
            ->whereNotNull('scheduled_at')
            ->where('scheduled_at', '<=', now())
            ->orderBy('scheduled_at')
            ->limit($limit)
            ->get();

        if ($notifications->isEmpty()) {
            $this->info('No scheduled notifications due.');
            return self::SUCCESS;
        }

        foreach ($notifications as $notification) {
            if ($notification->status !== 'queued') {
                $notification->update(['status' => 'queued']);
            }

            dispatch(new \App\Jobs\DispatchScheduledNotificationJob($notification));
            $this->info("Scheduled notification #{$notification->id} queued.");
        }

        return self::SUCCESS;
    }
}

