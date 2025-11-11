<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Reservation;
use App\Services\NotificationService;
use Illuminate\Support\Facades\Log;
use Carbon\Carbon;

class CompleteFinishedReservations extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'reservations:auto-complete';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Automatically complete reservations that have finished';

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
        $this->info('🔄 Checking for finished reservations...');

        try {
            // Find accepted reservations where end time has passed
            // Use database-agnostic approach
            $finishedReservations = Reservation::where('status', 'accepted')
                ->get()
                ->filter(function ($reservation) {
                    $endTime = Carbon::parse($reservation->proposed_datetime)
                        ->addMinutes($reservation->duration_minutes);
                    return $endTime->lt(now());
                })
                ->load(['student', 'teacher.user']);

            $count = 0;

            foreach ($finishedReservations as $reservation) {
                // Calculate when reservation should have ended
                $endTime = Carbon::parse($reservation->proposed_datetime)
                    ->addMinutes($reservation->duration_minutes);

                // Update to completed
                $reservation->update(['status' => 'completed']);

                $this->line("   ✅ Reservation #{$reservation->id} - {$reservation->subject} → completed");

                // Send completion notifications to both parties
                try {
                    // Notify student
                    if ($reservation->student) {
                        $this->notificationService->sendReservationCompletedNotification(
                            $reservation->student,
                            $reservation->teacher->user,
                            $reservation,
                            'student'
                        );
                    }

                    // Notify teacher
                    if ($reservation->teacher && $reservation->teacher->user) {
                        $this->notificationService->sendReservationCompletedNotification(
                            $reservation->teacher->user,
                            $reservation->student,
                            $reservation,
                            'teacher'
                        );
                    }

                    // Send rating request to student
                    if ($reservation->student) {
                        $this->notificationService->sendRatingRequestNotification(
                            $reservation->student,
                            $reservation->teacher->user,
                            $reservation
                        );
                    }

                    $this->line("      📧 Notifications sent");

                } catch (\Exception $e) {
                    $this->warn("      ⚠️  Failed to send notifications: " . $e->getMessage());
                }

                Log::info('Reservation auto-completed', [
                    'reservation_id' => $reservation->id,
                    'subject' => $reservation->subject,
                    'ended_at' => $endTime->toDateTimeString(),
                    'student_id' => $reservation->student_id,
                    'teacher_id' => $reservation->teacher_id,
                ]);

                $count++;
            }

            if ($count === 0) {
                $this->info('✅ No reservations need completing at this time.');
            } else {
                $this->info("✅ Completed {$count} reservation(s) successfully.");
            }

            Log::info('Auto-complete reservations job finished', [
                'count' => $count,
                'timestamp' => now()->toDateTimeString()
            ]);

            return Command::SUCCESS;

        } catch (\Exception $e) {
            $this->error('❌ Error completing reservations: ' . $e->getMessage());

            Log::error('Failed to auto-complete reservations', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);

            return Command::FAILURE;
        }
    }
}

