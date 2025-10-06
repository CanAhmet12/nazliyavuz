<?php

namespace App\Console;

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
