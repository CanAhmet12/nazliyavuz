<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Assignment;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Support\Facades\Log;
use Carbon\Carbon;

class SendAssignmentReminders extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'assignments:send-reminders';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Send reminders for assignments due in the next 2 days';

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
        $this->info('🔔 Sending assignment reminders...');

        try {
            // Find assignments due in the next 2 days (still pending)
            $upcomingAssignments = Assignment::where('status', 'pending')
                ->whereBetween('due_date', [
                    now(),
                    now()->addDays(2)
                ])
                ->with(['student', 'teacher'])
                ->get();

            $count = 0;

            foreach ($upcomingAssignments as $assignment) {
                $student = $assignment->student;
                
                if (!$student) {
                    $this->warn("   ⚠️  Assignment #{$assignment->id} - Student not found");
                    continue;
                }

                // Calculate hours remaining
                $hoursRemaining = now()->diffInHours($assignment->due_date);
                $daysRemaining = now()->diffInDays($assignment->due_date);

                $timeText = $daysRemaining > 0 
                    ? "{$daysRemaining} gün" 
                    : "{$hoursRemaining} saat";

                $title = "⏰ Ödev Hatırlatması";
                $message = "'{$assignment->title}' ödeviniz için son {$timeText} kaldı!";

                // Send notification
                $this->notificationService->sendCompleteNotification(
                    $student,
                    'assignment_reminder',
                    $title,
                    $message,
                    [
                        'assignment_id' => $assignment->id,
                        'due_date' => $assignment->due_date->toISOString(),
                        'hours_remaining' => $hoursRemaining,
                        'action' => 'assignment_reminder'
                    ],
                    "/assignments/{$assignment->id}",
                    "Ödevi Görüntüle"
                );

                $this->line("   📧 Reminder sent to {$student->name} - {$assignment->title} ({$timeText} remaining)");
                $count++;
            }

            if ($count === 0) {
                $this->info('✅ No reminders needed at this time.');
            } else {
                $this->info("✅ Sent {$count} reminder(s) successfully.");
            }

            Log::info('Assignment reminders sent', [
                'count' => $count,
                'timestamp' => now()->toDateTimeString()
            ]);

            return Command::SUCCESS;

        } catch (\Exception $e) {
            $this->error('❌ Error sending reminders: ' . $e->getMessage());
            
            Log::error('Failed to send assignment reminders', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);

            return Command::FAILURE;
        }
    }
}

