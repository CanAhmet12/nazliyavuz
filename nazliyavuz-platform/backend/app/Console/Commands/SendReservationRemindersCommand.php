<?php

namespace App\Console\Commands;

use App\Models\Reservation;
use App\Models\ReservationReminderSetting;
use App\Models\ReservationReminderWorkflow;
use App\Models\AuditLog;
use App\Services\ReservationReminderService;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;

class SendReservationRemindersCommand extends Command
{
    /**
     * The name and signature of the console command.
     */
    protected $signature = 'reservations:send-reminders {--window=10 : Time window in minutes around the target offset.}';

    /**
     * The console command description.
     */
    protected $description = 'Send automatic reservation reminders based on configured schedules.';

    public function __construct(
        protected ReservationReminderService $reservationReminderService
    ) {
        parent::__construct();
    }

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $workflows = ReservationReminderWorkflow::query()
            ->where('status', 'active')
            ->with(['steps' => function ($query) {
                $query->where('enabled', true)->orderBy('step_order');
            }])
            ->get();

        if ($workflows->isEmpty()) {
            $this->info('No active reservation reminder workflows found.');
            return self::SUCCESS;
        }

        $window = max((int) $this->option('window'), 1);
        $now = Carbon::now();
        $totalSent = 0;

        foreach ($workflows as $workflow) {
            if ($workflow->steps->isEmpty()) {
                continue;
            }

            $targetStatuses = $workflow->target_statuses ?? ['accepted', 'in_progress'];

            foreach ($workflow->steps as $step) {
                $timeWindow = $this->resolveTimeWindow($step, $now, $window);

                if (!$timeWindow) {
                    continue;
                }

                [$windowStart, $windowEnd] = $timeWindow;

                $reservationsQuery = Reservation::with(['student', 'teacher', 'reminderLogs.setting'])
                    ->whereNotNull('proposed_datetime')
                    ->whereBetween('proposed_datetime', [$windowStart, $windowEnd])
                    ->whereIn('status', $targetStatuses)
                    ->whereDoesntHave('reminderLogs', function ($query) use ($step) {
                        $query->where('reminder_setting_id', $step->id);
                    });

                if ($step->offset_direction === 'before') {
                    $reservationsQuery->where('proposed_datetime', '>', $now);
                } else {
                    $reservationsQuery->where('proposed_datetime', '<=', $now);
                }

                if ($step->stop_on_success) {
                    $reservationsQuery->whereDoesntHave('reminderLogs', function ($query) use ($step) {
                        $query->whereHas('setting', function ($inner) use ($step) {
                            $inner->where('workflow_id', $step->workflow_id);
                        });
                    });
                }

                $reservations = $reservationsQuery->get();

                if ($reservations->isEmpty()) {
                    continue;
                }

                foreach ($reservations as $reservation) {
                    $result = $this->reservationReminderService->sendReminder(
                        $reservation,
                        [],
                        'automatic',
                        $step
                    );

                    if (!($result['success'] ?? false)) {
                        continue;
                    }

                    $totalSent++;

                    AuditLog::createLog(
                        null,
                        'reservation_auto_reminder_sent',
                        Reservation::class,
                        $reservation->id,
                        [
                            'workflow_id' => $workflow->id,
                            'setting_id' => $step->id,
                            'channels' => $result['channels'] ?? [],
                        ]
                    );
                }
            }
        }

        $this->info("Automatic reminders sent: {$totalSent}");

        return self::SUCCESS;
    }

    /**
     * @return array{0: Carbon, 1: Carbon}|null
     */
    private function resolveTimeWindow(ReservationReminderSetting $step, Carbon $now, int $window): ?array
    {
        if (!$step->offset_minutes && $step->offset_minutes !== 0) {
            return null;
        }

        if ($step->offset_direction === 'after') {
            $targetTime = $now->copy()->subMinutes($step->offset_minutes);
        } else {
            $targetTime = $now->copy()->addMinutes($step->offset_minutes);
        }

        $windowSize = $step->send_window > 0 ? $step->send_window : $window;

        return [
            $targetTime->copy()->subMinutes($windowSize),
            $targetTime->copy()->addMinutes($windowSize),
        ];
    }
}

