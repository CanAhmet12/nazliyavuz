<?php

namespace App\Services;

use App\Models\Reservation;
use App\Models\ReservationReminderLog;
use App\Models\ReservationReminderSetting;
use Illuminate\Support\Facades\Log;
use App\Services\SmsService;

class ReservationReminderService
{
    public function __construct(
        protected NotificationService $notificationService,
        protected MailService $mailService,
        protected SmsService $smsService
    ) {
    }

    /**
     * @param array<mixed> $channelConfig
     */
    public function sendReminder(
        Reservation $reservation,
        array $channelConfig,
        string $source = 'automatic',
        ?ReservationReminderSetting $setting = null
    ): array {
        $channels = $this->normalizeChannelConfig($channelConfig, $setting);

        if (empty($channels)) {
            return [
                'success' => false,
                'message' => 'No channels selected',
            ];
        }

        $reservation->loadMissing(['student', 'teacher', 'category']);

        $sentChannels = [];
        $student = $reservation->student;
        $teacher = $reservation->teacher;

        if (($channels['student_push']['enabled'] ?? false) && $student) {
            try {
                $this->notificationService->sendReservationReminderNotification(
                    $student,
                    $reservation
                );
                $sentChannels[] = 'student_push';
            } catch (\Throwable $exception) {
                Log::warning('Failed to send student reservation reminder push', [
                    'reservation_id' => $reservation->id,
                    'error' => $exception->getMessage(),
                ]);
            }
        }

        if (($channels['teacher_push']['enabled'] ?? false) && $teacher) {
            try {
                $this->notificationService->sendReservationReminderNotification(
                    $teacher,
                    $reservation
                );
                $sentChannels[] = 'teacher_push';
            } catch (\Throwable $exception) {
                Log::warning('Failed to send teacher reservation reminder push', [
                    'reservation_id' => $reservation->id,
                    'error' => $exception->getMessage(),
                ]);
            }
        }

        if (($channels['student_email']['enabled'] ?? false) && $student) {
            try {
                if ($this->mailService->sendReservationReminderTo($student, $reservation, 'student')) {
                    $sentChannels[] = 'student_email';
                }
            } catch (\Throwable $exception) {
                Log::warning('Failed to send reservation reminder email to student', [
                    'reservation_id' => $reservation->id,
                    'error' => $exception->getMessage(),
                ]);
            }
        }

        if (($channels['teacher_email']['enabled'] ?? false) && $teacher) {
            try {
                if ($this->mailService->sendReservationReminderTo($teacher, $reservation, 'teacher')) {
                    $sentChannels[] = 'teacher_email';
                }
            } catch (\Throwable $exception) {
                Log::warning('Failed to send reservation reminder email to teacher', [
                    'reservation_id' => $reservation->id,
                    'error' => $exception->getMessage(),
                ]);
            }
        }

        if (($channels['student_sms']['enabled'] ?? false) && $student && !empty($student->phone)) {
            try {
                $smsResult = $this->smsService->send(
                    $student->phone,
                    $this->buildReminderSmsMessage($reservation, $student->name)
                );

                if ($smsResult['success'] ?? false) {
                    $sentChannels[] = 'student_sms';
                }
            } catch (\Throwable $exception) {
                Log::warning('Failed to send reservation reminder SMS to student', [
                    'reservation_id' => $reservation->id,
                    'error' => $exception->getMessage(),
                ]);
            }
        }

        if (($channels['teacher_sms']['enabled'] ?? false) && $teacher && !empty($teacher->phone)) {
            try {
                $smsResult = $this->smsService->send(
                    $teacher->phone,
                    $this->buildReminderSmsMessage($reservation, $teacher->name)
                );

                if ($smsResult['success'] ?? false) {
                    $sentChannels[] = 'teacher_sms';
                }
            } catch (\Throwable $exception) {
                Log::warning('Failed to send reservation reminder SMS to teacher', [
                    'reservation_id' => $reservation->id,
                    'error' => $exception->getMessage(),
                ]);
            }
        }

        if (empty($sentChannels)) {
            return [
                'success' => false,
                'message' => 'No reminder channels succeeded',
            ];
        }

        $log = ReservationReminderLog::create([
            'reservation_id' => $reservation->id,
            'reminder_setting_id' => $setting?->id,
            'channels' => $sentChannels,
            'source' => $source,
            'sent_at' => now(),
        ]);

        $reservation->reminder_sent = true;
        $reservation->reminder_sent_at = now();
        $reservation->reminder_count = ($reservation->reminder_count ?? 0) + 1;
        $reservation->save();

        if ($reservation->relationLoaded('reminderLogs')) {
            $reservation->reminderLogs->push($log->fresh('setting'));
        }

        return [
            'success' => true,
            'log_id' => $log->id,
            'channels' => $sentChannels,
        ];
    }

    /**
     * @return array<string, array<string, mixed>>
     */
    private function normalizeChannelConfig(array $channelConfig, ?ReservationReminderSetting $setting = null): array
    {
        if ($this->isSimpleChannelMap($channelConfig)) {
            return [
                'student_push' => [
                    'enabled' => (bool) ($channelConfig['student_push'] ?? false),
                    'template_id' => null,
                ],
                'teacher_push' => [
                    'enabled' => (bool) ($channelConfig['teacher_push'] ?? false),
                    'template_id' => null,
                ],
                'student_email' => [
                    'enabled' => (bool) ($channelConfig['email'] ?? false),
                    'template_id' => null,
                ],
                'teacher_email' => [
                    'enabled' => false,
                    'template_id' => null,
                ],
                'student_sms' => [
                    'enabled' => false,
                    'template_id' => null,
                ],
                'teacher_sms' => [
                    'enabled' => false,
                    'template_id' => null,
                ],
            ];
        }

        if ($setting) {
            $channels = $setting->channel_config;

            return [
                'student_push' => [
                    'enabled' => (bool) ($channels['student']['push']['enabled'] ?? false),
                    'template_id' => $channels['student']['push']['template_id'] ?? null,
                ],
                'teacher_push' => [
                    'enabled' => (bool) ($channels['teacher']['push']['enabled'] ?? false),
                    'template_id' => $channels['teacher']['push']['template_id'] ?? null,
                ],
                'student_email' => [
                    'enabled' => (bool) ($channels['student']['email']['enabled'] ?? false),
                    'template_id' => $channels['student']['email']['template_id'] ?? null,
                ],
                'teacher_email' => [
                    'enabled' => (bool) ($channels['teacher']['email']['enabled'] ?? false),
                    'template_id' => $channels['teacher']['email']['template_id'] ?? null,
                ],
                'student_sms' => [
                    'enabled' => (bool) ($channels['student']['sms']['enabled'] ?? false),
                    'template_id' => $channels['student']['sms']['template_id'] ?? null,
                ],
                'teacher_sms' => [
                    'enabled' => (bool) ($channels['teacher']['sms']['enabled'] ?? false),
                    'template_id' => $channels['teacher']['sms']['template_id'] ?? null,
                ],
            ];
        }

        return [];
    }

    private function isSimpleChannelMap(array $channels): bool
    {
        $allowedKeys = ['student_push', 'teacher_push', 'email'];

        foreach (array_keys($channels) as $key) {
            if (!in_array($key, $allowedKeys, true)) {
                return false;
            }
        }

        return true;
    }

    private function buildReminderSmsMessage(Reservation $reservation, string $recipientName): string
    {
        $lessonTime = $reservation->proposed_datetime
            ? $reservation->proposed_datetime->timezone(config('app.timezone'))->format('d.m.Y H:i')
            : 'belirtilmedi';

        $subject = $reservation->subject ?? ($reservation->category->name ?? 'dersiniz');

        return sprintf(
            'Merhaba %s, %s için planlanan dersiniz %s tarihinde başlayacak. Lütfen zamanında hazır olun. - Nazliyavuz',
            $recipientName,
            $subject,
            $lessonTime
        );
    }
}

