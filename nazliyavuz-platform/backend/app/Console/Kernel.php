<?php

namespace App\Console;

use App\Services\AdminBackupService;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

class Kernel extends ConsoleKernel
{
    /**
     * Define the application's command schedule.
     */
    protected function schedule(Schedule $schedule): void
    {
        // Cache warming every hour
        $schedule->command('cache:manage warm')
                 ->hourly()
                 ->withoutOverlapping()
                 ->runInBackground();

        // Cache statistics every 30 minutes
        $schedule->command('cache:manage stats')
                 ->everyThirtyMinutes()
                 ->withoutOverlapping();

        // Clear expired cache every 6 hours
        $schedule->command('cache:manage clear --pattern=expired:*')
                 ->everySixHours()
                 ->withoutOverlapping();

        // Performance optimization cleanup
        $schedule->command('optimize:clear')
                 ->daily()
                 ->at('02:00')
                 ->withoutOverlapping();

        // Database optimization
        $schedule->command('db:monitor')
                 ->everyTenMinutes()
                 ->withoutOverlapping();

        // ✅ Assignment Management
        // Update overdue assignments every 5 minutes
        $schedule->command('assignments:update-overdue')
                 ->everyFiveMinutes()
                 ->withoutOverlapping()
                 ->runInBackground();

        // Send assignment reminders daily at 9:00 AM
        $schedule->command('assignments:send-reminders')
                 ->dailyAt('09:00')
                 ->withoutOverlapping()
                 ->runInBackground();

        // ✅ Reservation Management
        // Auto-complete finished reservations every 5 minutes
        $schedule->command('reservations:auto-complete')
                 ->everyFiveMinutes()
                 ->withoutOverlapping()
                 ->runInBackground();

        // Send lesson reminders every 10 minutes
        $schedule->command('reservations:send-reminders')
                 ->everyTenMinutes()
                 ->withoutOverlapping()
                 ->runInBackground();

        // Dispatch scheduled notifications every minute
        $schedule->command('notifications:dispatch-scheduled')
                 ->everyMinute()
                 ->withoutOverlapping()
                 ->runInBackground();

        // Automated backups
        $databaseSchedule = config('backup.schedule.database', []);
        if (($databaseSchedule['enabled'] ?? false) && !empty($databaseSchedule['cron'])) {
            $storageDisk = config('backup.storage_disk', 'local');
            $schedule->command('backup:database', [
                    '--storage' => $storageDisk,
                    '--compress' => 'true',
                    '--retention' => (string) config('backup.retention_days', 30),
                ])
                ->cron($databaseSchedule['cron'])
                ->onOneServer()
                ->withoutOverlapping()
                ->runInBackground();
        }

        $filesystemSchedule = config('backup.schedule.filesystem', []);
        if (($filesystemSchedule['enabled'] ?? false) && !empty($filesystemSchedule['cron'])) {
            $schedule->call(function () {
                app(AdminBackupService::class)->createFileSystemBackup([
                    'source' => 'scheduler',
                    'trigger' => 'scheduler:filesystem',
                    'storage' => config('backup.storage_disk', 'local'),
                ]);
            })
                ->cron($filesystemSchedule['cron'])
                ->onOneServer()
                ->withoutOverlapping()
                ->runInBackground();
        }

        $fullSchedule = config('backup.schedule.full', []);
        if (($fullSchedule['enabled'] ?? false) && !empty($fullSchedule['cron'])) {
            $schedule->call(function () {
                app(AdminBackupService::class)->createFullBackup([
                    'source' => 'scheduler',
                    'trigger' => 'scheduler:full',
                    'storage' => config('backup.storage_disk', 'local'),
                ]);
            })
                ->cron($fullSchedule['cron'])
                ->onOneServer()
                ->withoutOverlapping()
                ->runInBackground();
        }
    }

    /**
     * Register the commands for the application.
     */
    protected function commands(): void
    {
        $this->load(__DIR__.'/Commands');

        require base_path('routes/console.php');
    }
}
