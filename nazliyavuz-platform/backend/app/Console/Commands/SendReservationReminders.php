<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Reservation;
use App\Services\NotificationService;
use Illuminate\Support\Facades\Log;
use Carbon\Carbon;

class SendReservationReminders extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'reservations:send-reminders';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Send reminders for upcoming reservations (1 hour before)';

    protected NotificationService $notificationService;

    public function __construct(NotificationService $notificationService)
    {
        parent::__construct();
        $this->notificationService = $notificationService;
    }

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $this->info('🔔 Sending reservation reminders...');

        try {
            // Find accepted reservations starting in 50-70 minutes (1 hour ± 10 min window)
            $upcomingReservations = Reservation::where('status', 'accepted')
                ->whereBetween('proposed_datetime', [
                    now()->addMinutes(50),
                    now()->addMinutes(70)
                ])
                ->with(['student', 'teacher.user'])
                ->get();

            // Filter out already reminded (if we add reminder tracking)
            // For now, send to all in window

            $count = 0;

            foreach ($upcomingReservations as $reservation) {
                $minutesUntilStart = now()->diffInMinutes($reservation->proposed_datetime, false);

                // Send reminder to student
                try {
                    if ($reservation->student) {
                        $this->notificationService->sendLessonReminderNotification(
                            $reservation->student,
                            $reservation,
                            (int) $minutesUntilStart
                        );

                        $this->line("   📧 Reminder sent to student: {$reservation->student->name} - {$reservation->subject} ({$minutesUntilStart} min)");
                    }
                } catch (\Exception $e) {
                    $this->warn("      ⚠️  Failed to send student reminder: " . $e->getMessage());
                }

                // Send reminder to teacher
                try {
                    if ($reservation->teacher && $reservation->teacher->user) {
                        $this->notificationService->sendLessonReminderNotification(
                            $reservation->teacher->user,
                            $reservation,
                            (int) $minutesUntilStart
                        );

                        $this->line("   📧 Reminder sent to teacher: {$reservation->teacher->user->name} - {$reservation->subject} ({$minutesUntilStart} min)");
                    }
                } catch (\Exception $e) {
                    $this->warn("      ⚠️  Failed to send teacher reminder: " . $e->getMessage());
                }

                Log::info('Reservation reminder sent', [
                    'reservation_id' => $reservation->id,
                    'subject' => $reservation->subject,
                    'starts_at' => $reservation->proposed_datetime->toDateTimeString(),
                    'minutes_until' => $minutesUntilStart,
                ]);

                $count++;
            }

            if ($count === 0) {
                $this->info('✅ No reminders needed at this time.');
            } else {
                $this->info("✅ Sent {$count} reminder(s) successfully.");
            }

            Log::info('Reservation reminders job finished', [
                'count' => $count,
                'timestamp' => now()->toDateTimeString()
            ]);

            return Command::SUCCESS;

        } catch (\Exception $e) {
            $this->error('❌ Error sending reminders: ' . $e->getMessage());

            Log::error('Failed to send reservation reminders', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);

            return Command::FAILURE;
        }
    }
}

