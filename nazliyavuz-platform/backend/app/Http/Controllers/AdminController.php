<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Collection;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Str;
use App\Models\User;
use App\Models\Teacher;
use App\Models\Reservation;
use App\Models\Category;
use App\Models\Notification;
use App\Models\Payment;
use App\Models\Lesson;
use App\Models\ReservationReminderSetting;
use App\Models\ReservationReminderLog;
use App\Models\ReservationReminderWorkflow;
use App\Models\ScheduledNotification;
use App\Models\ScheduledNotificationLog;
use App\Models\NotificationTemplate;
use App\Models\ReservationRefund;
use Carbon\Carbon;
use App\Models\AuditLog;
use App\Services\CacheService;
use App\Services\NotificationService;
use App\Services\AdminAnalyticsService;
use App\Services\AdminNotificationService;
use App\Services\AdminReportService;
use App\Services\AdminBackupService;
use App\Services\PaytrService;
use App\Services\ReservationReminderService;
use App\Services\ScheduledNotificationService;
use App\Services\NotificationTemplateService;
use App\Services\MailService;
use App\Services\PushNotificationService;
use App\Services\EnvironmentService;
use App\Services\SmsService;
use App\Services\ReservationRefundService;
use App\Jobs\ProcessReservationRefundJob;
use App\Jobs\SendPushNotification;

/**
 * @OA\Tag(
 *     name="Admin",
 *     description="Admin paneli ve moderasyon işlemleri"
 * )
 */
class AdminController extends Controller
{
    protected CacheService $cacheService;
    protected NotificationService $notificationService;
    protected AdminAnalyticsService $analyticsService;
    protected AdminNotificationService $adminNotificationService;
    protected AdminReportService $reportService;
    protected AdminBackupService $backupService;
    protected PaytrService $paytrService;
    protected ReservationReminderService $reservationReminderService;
    protected ScheduledNotificationService $scheduledNotificationService;
    protected NotificationTemplateService $notificationTemplateService;
    protected MailService $mailService;
    protected PushNotificationService $pushNotificationService;
    protected EnvironmentService $environmentService;
    protected SmsService $smsService;
    protected ReservationRefundService $reservationRefundService;
    protected ?Collection $reminderSettingsCache = null;
    protected ?Collection $reminderWorkflowsCache = null;

    public function __construct(
        NotificationService $notificationService,
        AdminAnalyticsService $analyticsService,
        AdminNotificationService $adminNotificationService,
        AdminReportService $reportService,
        AdminBackupService $backupService,
        PaytrService $paytrService,
        ReservationReminderService $reservationReminderService,
        ScheduledNotificationService $scheduledNotificationService,
        NotificationTemplateService $notificationTemplateService,
        MailService $mailService,
        PushNotificationService $pushNotificationService,
        EnvironmentService $environmentService,
        SmsService $smsService,
        ReservationRefundService $reservationRefundService
    ) {
        // Rate limiting for admin operations will be handled in routes
        
        // Cache service temporarily disabled for deployment
        $this->notificationService = $notificationService;
        $this->analyticsService = $analyticsService;
        $this->adminNotificationService = $adminNotificationService;
        $this->reportService = $reportService;
        $this->backupService = $backupService;
        $this->paytrService = $paytrService;
        $this->reservationReminderService = $reservationReminderService;
        $this->scheduledNotificationService = $scheduledNotificationService;
        $this->notificationTemplateService = $notificationTemplateService;
        $this->mailService = $mailService;
        $this->pushNotificationService = $pushNotificationService;
        $this->environmentService = $environmentService;
        $this->smsService = $smsService;
        $this->reservationRefundService = $reservationRefundService;
    }

    /**
     * Handle reschedule requests as admin
     */
    public function handleRescheduleRequest(Request $request, Reservation $reservation): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'action' => 'required|string|in:approve,reject,clear',
            'rejection_reason' => 'required_if:action,reject|string|max:500',
            'notify_participants' => 'sometimes|boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $notes = $this->decodeTeacherNotes($reservation->teacher_notes);

        if (!isset($notes['reschedule_request']) || !is_array($notes['reschedule_request'])) {
            return response()->json([
                'error' => [
                    'code' => 'NO_RESCHEDULE_REQUEST',
                    'message' => 'Bekleyen yeniden planlama talebi bulunamadı',
                ],
            ], 404);
        }

        $rescheduleData = $notes['reschedule_request'];
        $notifyParticipants = $request->boolean('notify_participants', true);

        DB::beginTransaction();

        try {
            $action = $request->input('action');
            $message = null;
            $newDatetime = null;

            if ($action === 'approve') {
                $newDatetime = Carbon::parse($rescheduleData['new_datetime'] ?? $reservation->proposed_datetime);
                $reservation->proposed_datetime = $newDatetime;
                $rescheduleData['status'] = 'approved';
                $rescheduleData['handled_by'] = $admin->id;
                $rescheduleData['handled_by_role'] = 'admin';
                $rescheduleData['handled_at'] = now()->toISOString();
                unset($rescheduleData['rejection_reason']);
                $message = 'Yeniden planlama talebi onaylandı';
            } elseif ($action === 'reject') {
                $rescheduleData['status'] = 'rejected';
                $rescheduleData['handled_by'] = $admin->id;
                $rescheduleData['handled_by_role'] = 'admin';
                $rescheduleData['handled_at'] = now()->toISOString();
                $rescheduleData['rejection_reason'] = $request->input('rejection_reason');
                $message = 'Yeniden planlama talebi reddedildi';
            } else {
                unset($notes['reschedule_request']);
                $rescheduleData = null;
                $message = 'Yeniden planlama talebi temizlendi';
            }

            if ($rescheduleData) {
                $notes['reschedule_request'] = $rescheduleData;

                $history = $notes['reschedule_history'] ?? [];
                $history[] = $rescheduleData;
                $notes['reschedule_history'] = $history;
            }

            $this->syncTeacherNotes($reservation, $notes);
            $reservation->save();

            DB::commit();

        } catch (\Throwable $e) {
            DB::rollBack();

            \Log::error('Admin reschedule handling failed: ' . $e->getMessage(), [
                'reservation_id' => $reservation->id,
                'admin_id' => $admin->id,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'RESCHEDULE_HANDLE_ERROR',
                    'message' => 'Yeniden planlama talebi işlenirken bir hata oluştu',
                ],
            ], 500);
        }

        $reservation->load(['student', 'teacher', 'category', 'payments', 'lessons.teacher', 'lessons.student', 'reminderLogs.setting']);

        $rescheduleData = $this->extractRescheduleRequest($reservation->teacher_notes);

        if ($notifyParticipants && $rescheduleData) {
            try {
                if (($request->action === 'approve' || $request->action === 'reject') && $reservation->student) {
                    $title = $request->action === 'approve'
                        ? '✅ Yeniden Planlama Onaylandı'
                        : '❌ Yeniden Planlama Reddedildi';

                    $studentMessage = $request->action === 'approve'
                        ? sprintf(
                            "'%s' dersinizin yeniden planlama talebi admin tarafından onaylandı.\nYeni tarih: %s",
                            $reservation->subject,
                            isset($rescheduleData['new_datetime'])
                                ? Carbon::parse($rescheduleData['new_datetime'])->locale('tr')->isoFormat('D MMMM YYYY, HH:mm')
                                : $reservation->proposed_datetime?->locale('tr')->isoFormat('D MMMM YYYY, HH:mm')
                        )
                        : sprintf(
                            "'%s' dersinizin yeniden planlama talebi admin tarafından reddedildi.\nSebep: %s",
                            $reservation->subject,
                            $rescheduleData['rejection_reason'] ?? 'Belirtilmedi'
                        );

                    $this->notificationService->sendCompleteNotification(
                        $reservation->student,
                        'reservation',
                        $title,
                        $studentMessage,
                        [
                            'reservation_id' => $reservation->id,
                            'reschedule_status' => $rescheduleData['status'] ?? null,
                        ],
                        "/reservations/{$reservation->id}",
                        "Detayları Gör"
                    );
                }

                if ($reservation->teacher && $request->action === 'approve') {
                    $this->notificationService->sendCompleteNotification(
                        $reservation->teacher,
                        'reservation',
                        '📅 Ders Yeniden Planlandı',
                        sprintf(
                            "'%s' dersi admin tarafından %s tarihine taşındı.",
                            $reservation->subject,
                            isset($rescheduleData['new_datetime'])
                                ? Carbon::parse($rescheduleData['new_datetime'])->locale('tr')->isoFormat('D MMMM YYYY, HH:mm')
                                : $reservation->proposed_datetime?->locale('tr')->isoFormat('D MMMM YYYY, HH:mm')
                        ),
                        [
                            'reservation_id' => $reservation->id,
                            'reschedule_status' => $rescheduleData['status'] ?? null,
                        ],
                        "/reservations/{$reservation->id}",
                        "Rezervasyonu Görüntüle"
                    );
                }
            } catch (\Exception $e) {
                \Log::warning('Failed to send admin reschedule notifications: ' . $e->getMessage(), [
                    'reservation_id' => $reservation->id,
                ]);
            }
        }

        AuditLog::createLog(
            $admin->id,
            'reservation_reschedule_handled',
            Reservation::class,
            $reservation->id,
            [
                'action' => $request->action,
                'rejection_reason' => $request->input('rejection_reason'),
                'reschedule_request' => $rescheduleData,
            ],
            $request->ip(),
            $request->userAgent()
        );

        return response()->json([
            'success' => true,
            'reservation' => $this->transformReservationForAdmin($reservation),
        ]);
    }

    private function transformReservationForAdmin(Reservation $reservation): array
    {
        $reservation->loadMissing(['lessons.teacher', 'lessons.student', 'reminderLogs.setting', 'refunds.payment', 'refunds.creator']);

        $data = $reservation->toArray();
        $data['reschedule_request'] = $this->extractRescheduleRequest($reservation->teacher_notes);
        $data['reschedule_history'] = $this->extractRescheduleHistory($reservation->teacher_notes ?? null, $reservation);

        $lessons = $reservation->lessons instanceof \Illuminate\Support\Collection
            ? $reservation->lessons
            : collect($reservation->lessons);

        $sortedLessons = $lessons
            ->sortByDesc(function (Lesson $lesson) {
                return $lesson->scheduled_at ?? $lesson->created_at;
            })
            ->values();

        $data['lessons'] = $sortedLessons
            ->map(fn (Lesson $lesson) => $this->transformLessonForAdmin($lesson))
            ->values()
            ->all();

        $data['lesson_summary'] = [
            'total' => $lessons->count(),
            'completed' => $lessons->where('status', 'completed')->count(),
            'in_progress' => $lessons->where('status', 'in_progress')->count(),
            'upcoming' => $lessons->where('status', 'scheduled')->count(),
            'last_lesson_at' => optional(
                $lessons
                    ->filter(fn (Lesson $lesson) => in_array($lesson->status, ['in_progress', 'completed']))
                    ->sortByDesc(fn (Lesson $lesson) => $lesson->ended_at ?? $lesson->started_at ?? $lesson->scheduled_at)
                    ->first()
            )->ended_at?->toIso8601String()
                ?? optional(
                    $lessons
                        ->filter(fn (Lesson $lesson) => in_array($lesson->status, ['in_progress', 'completed']))
                        ->sortByDesc(fn (Lesson $lesson) => $lesson->started_at ?? $lesson->scheduled_at ?? $lesson->created_at)
                        ->first()
                )->started_at?->toIso8601String(),
            'next_lesson_at' => optional(
                $lessons
                    ->where('status', 'scheduled')
                    ->sortBy(fn (Lesson $lesson) => $lesson->scheduled_at ?? $lesson->created_at)
                    ->first()
            )->scheduled_at?->toIso8601String(),
        ];

        $reminderLogs = $reservation->reminderLogs instanceof \Illuminate\Support\Collection
            ? $reservation->reminderLogs
            : collect($reservation->reminderLogs);

        $sortedReminderLogs = $reminderLogs
            ->sortByDesc(fn (ReservationReminderLog $log) => $log->sent_at ?? $log->created_at)
            ->values();

        $lastReminder = $sortedReminderLogs->first();

        $data['reminder_logs'] = $sortedReminderLogs
            ->take(10)
            ->map(function (ReservationReminderLog $log) {
                return [
                    'id' => $log->id,
                    'sent_at' => $log->sent_at?->toIso8601String(),
                    'source' => $log->source,
                    'channels' => $log->channels ?? [],
                    'setting' => $log->setting ? [
                        'id' => $log->setting->id,
                        'name' => $log->setting->name,
                        'offset_minutes' => $log->setting->offset_minutes,
                    ] : null,
                ];
            })
            ->values()
            ->all();

        $pendingSettings = $this->getPendingReminderSettings($reservation, $reminderLogs);

        $data['reminder_summary'] = [
            'total_sent' => $reminderLogs->count(),
            'last_sent_at' => $lastReminder?->sent_at?->toIso8601String(),
            'last_channels' => $lastReminder?->channels ?? [],
            'pending' => $pendingSettings,
        ];

        $data['refunds'] = $reservation->refunds
            ->sortByDesc('created_at')
            ->map(fn (ReservationRefund $refund) => $this->transformReservationRefund($refund))
            ->values()
            ->all();

        return $data;
    }

    private function transformLessonForAdmin(Lesson $lesson): array
    {
        $lesson->loadMissing(['teacher', 'student']);

        return [
            'id' => $lesson->id,
            'status' => $lesson->status,
            'status_text' => $lesson->status_text ?? null,
            'scheduled_at' => $lesson->scheduled_at?->toIso8601String(),
            'started_at' => $lesson->started_at?->toIso8601String(),
            'ended_at' => $lesson->ended_at?->toIso8601String(),
            'duration_minutes' => $lesson->duration_minutes,
            'formatted_duration' => $lesson->formatted_duration ?? null,
            'notes' => $lesson->notes,
            'feedback' => $lesson->feedback,
            'rating' => $lesson->rating,
            'rated_at' => $lesson->rated_at?->toIso8601String(),
            'is_overdue' => (bool) ($lesson->is_overdue ?? false),
            'can_be_started' => (bool) ($lesson->can_be_started ?? false),
            'can_be_rated' => (bool) ($lesson->can_be_rated ?? false),
            'teacher' => $lesson->teacher ? [
                'id' => $lesson->teacher->id,
                'name' => $lesson->teacher->name,
                'email' => $lesson->teacher->email,
            ] : null,
            'student' => $lesson->student ? [
                'id' => $lesson->student->id,
                'name' => $lesson->student->name,
                'email' => $lesson->student->email,
            ] : null,
            'created_at' => $lesson->created_at?->toIso8601String(),
            'updated_at' => $lesson->updated_at?->toIso8601String(),
        ];
    }

    private function transformReminderSetting(ReservationReminderSetting $setting): array
    {
        $channels = $setting->channel_config;

        return [
            'id' => $setting->id,
            'workflow_id' => $setting->workflow_id,
            'name' => $setting->name,
            'offset_minutes' => $setting->offset_minutes,
            'offset_direction' => $setting->offset_direction,
            'offset_human' => $this->formatOffsetDescriptor($setting->offset_minutes, $setting->offset_direction),
            'send_window' => $setting->send_window,
            'step_order' => $setting->step_order,
            'enabled' => $setting->enabled,
            'stop_on_success' => $setting->stop_on_success,
            'channels' => $channels,
            'metadata' => $setting->metadata ?? [],
            'created_at' => $setting->created_at?->toIso8601String(),
            'updated_at' => $setting->updated_at?->toIso8601String(),
        ];
    }

    private function transformReminderWorkflow(ReservationReminderWorkflow $workflow): array
    {
        $workflow->loadMissing(['steps' => fn ($query) => $query->orderBy('step_order')]);

        return [
            'id' => $workflow->id,
            'name' => $workflow->name,
            'slug' => $workflow->slug,
            'description' => $workflow->description,
            'status' => $workflow->status,
            'target_statuses' => $workflow->target_statuses ?? ['accepted', 'in_progress'],
            'target_roles' => $workflow->target_roles ?? ['student', 'teacher'],
            'meta' => $workflow->meta ?? [],
            'steps' => $workflow->steps
                ->sortBy('step_order')
                ->map(fn (ReservationReminderSetting $step) => $this->transformReminderSetting($step))
                ->values()
                ->all(),
            'created_at' => $workflow->created_at?->toIso8601String(),
            'updated_at' => $workflow->updated_at?->toIso8601String(),
        ];
    }

    private function transformReservationRefund(ReservationRefund $refund): array
    {
        $refund->loadMissing(['payment', 'creator']);

        return [
            'id' => $refund->id,
            'amount' => (float) $refund->amount,
            'currency' => $refund->currency,
            'status' => $refund->status,
            'reason' => $refund->reason,
            'notify_participants' => $refund->notify_participants,
            'cancel_reservation' => $refund->cancel_reservation,
            'attempts' => $refund->attempts,
            'max_attempts' => $refund->max_attempts,
            'last_attempt_at' => $refund->last_attempt_at?->toIso8601String(),
            'processed_at' => $refund->processed_at?->toIso8601String(),
            'failure_code' => $refund->failure_code,
            'failure_message' => $refund->failure_message,
            'provider' => [
                'name' => $refund->provider_name,
                'reference' => $refund->provider_reference,
                'response' => $refund->provider_response,
            ],
            'meta' => $refund->meta ?? [],
            'created_at' => $refund->created_at?->toIso8601String(),
            'updated_at' => $refund->updated_at?->toIso8601String(),
            'payment' => $refund->payment ? [
                'id' => $refund->payment->id,
                'amount' => (float) $refund->payment->amount,
                'status' => $refund->payment->status,
                'paytr_order_id' => $refund->payment->paytr_order_id,
            ] : null,
            'created_by' => $refund->creator?->only(['id', 'name', 'email']),
        ];
    }

    private function getPendingReminderSettings(Reservation $reservation, Collection $existingLogs): array
    {
        if (!$reservation->proposed_datetime) {
            return [];
        }

        $activeWorkflows = $this->getActiveReminderWorkflows();

        if ($activeWorkflows->isEmpty()) {
            return [];
        }

        $sentSettingIds = $existingLogs
            ->pluck('reminder_setting_id')
            ->filter()
            ->unique()
            ->all();

        $workflowSentMap = $existingLogs
            ->filter(fn (ReservationReminderLog $log) => $log->setting && $log->setting->workflow_id)
            ->groupBy(fn (ReservationReminderLog $log) => $log->setting->workflow_id)
            ->map->pluck('reminder_setting_id')
            ->map(fn ($ids) => $ids->unique()->all());

        $results = [];
        $proposedAt = $reservation->proposed_datetime->copy();

        foreach ($activeWorkflows as $workflow) {
            $workflowLogs = $workflowSentMap->get($workflow->id, []);

            foreach ($workflow->steps as $step) {
                if (!$step->enabled) {
                    continue;
                }

                if (in_array($step->id, $sentSettingIds, true)) {
                    continue;
                }

                if ($step->stop_on_success && !empty($workflowLogs)) {
                    continue;
                }

                $scheduledFor = $step->offset_direction === 'after'
                    ? $proposedAt->copy()->addMinutes($step->offset_minutes)
                    : $proposedAt->copy()->subMinutes($step->offset_minutes);

                if ($scheduledFor->isPast()) {
                    continue;
                }

                $results[] = [
                    'id' => $step->id,
                    'workflow_id' => $workflow->id,
                    'workflow_name' => $workflow->name,
                    'name' => $step->name,
                    'offset_minutes' => $step->offset_minutes,
                    'offset_direction' => $step->offset_direction,
                    'scheduled_for' => $scheduledFor->toIso8601String(),
                    'channels' => $step->channel_config,
                ];
            }
        }

        return $results;
    }

    private function getActiveReminderSettings(bool $refresh = false): Collection
    {
        $workflows = $this->getActiveReminderWorkflows($refresh);

        return $workflows
            ->flatMap(fn (ReservationReminderWorkflow $workflow) => $workflow->steps)
            ->sortBy('step_order')
            ->values();
    }

    private function getActiveReminderWorkflows(bool $refresh = false): Collection
    {
        if ($refresh || $this->reminderWorkflowsCache === null) {
            $this->reminderWorkflowsCache = ReservationReminderWorkflow::with(['steps' => function ($query) {
                $query->orderBy('step_order');
            }])->where('status', 'active')->get();
        }

        return $this->reminderWorkflowsCache;
    }

    private function clearReminderSettingsCache(): void
    {
        $this->reminderSettingsCache = null;
        $this->reminderWorkflowsCache = null;
    }

    private function normalizeNotificationChannels(?array $channels): array
    {
        $default = [
            'push' => true,
            'email' => false,
            'in_app' => true,
        ];

        if (!is_array($channels)) {
            return $default;
        }

        return [
            'push' => array_key_exists('push', $channels) ? (bool) $channels['push'] : $default['push'],
            'email' => array_key_exists('email', $channels) ? (bool) $channels['email'] : $default['email'],
            'in_app' => array_key_exists('in_app', $channels) ? (bool) $channels['in_app'] : $default['in_app'],
        ];
    }

    private function transformScheduledNotification(ScheduledNotification $notification): array
    {
        $notification->loadMissing(['creator', 'template', 'logs' => function ($query) {
            $query->orderByDesc('created_at')->limit(5);
        }]);

        return [
            'id' => $notification->id,
            'title' => $notification->title,
            'message' => $notification->message,
            'type' => $notification->type,
            'priority' => $notification->priority,
            'target_type' => $notification->target_type,
            'target_filters' => $notification->target_filters,
            'channels' => $notification->channels,
            'template_id' => $notification->template_id,
            'status' => $notification->status,
            'scheduled_at' => $notification->scheduled_at?->toIso8601String(),
            'timezone' => $notification->timezone,
            'sent_count' => $notification->sent_count,
            'fail_count' => $notification->fail_count,
            'last_attempt_at' => $notification->last_attempt_at?->toIso8601String(),
            'meta' => $notification->meta,
            'created_by' => $notification->creator?->only(['id', 'name', 'email']),
            'created_at' => $notification->created_at?->toIso8601String(),
            'updated_at' => $notification->updated_at?->toIso8601String(),
            'template' => $notification->template ? $this->transformNotificationTemplate($notification->template) : null,
            'recent_logs' => $notification->logs->map(fn (ScheduledNotificationLog $log) => [
                'id' => $log->id,
                'status' => $log->status,
                'sent_count' => $log->sent_count,
                'fail_count' => $log->fail_count,
                'started_at' => $log->started_at?->toIso8601String(),
                'finished_at' => $log->finished_at?->toIso8601String(),
                'error_message' => $log->error_message,
            ])->all(),
        ];
    }

    private function formatOffsetMinutes(int $minutes): string
    {
        $hours = intdiv($minutes, 60);
        $remainingMinutes = $minutes % 60;

        $parts = [];

        if ($hours > 0) {
            $parts[] = $hours . ' sa';
        }

        if ($remainingMinutes > 0) {
            $parts[] = $remainingMinutes . ' dk';
        }

        if (empty($parts)) {
            return '0 dk';
        }

        return implode(' ', $parts);
    }

    private function formatOffsetDescriptor(int $minutes, string $direction): string
    {
        $label = $this->formatOffsetMinutes($minutes);

        return $direction === 'after'
            ? "{$label} sonra"
            : "{$label} önce";
    }

    private function getOrCreateDefaultReminderWorkflow(?User $actor = null): ReservationReminderWorkflow
    {
        $slug = Str::slug('Varsayılan Hatırlatma Akışı');

        $workflow = ReservationReminderWorkflow::firstOrCreate(
            ['slug' => $slug],
            [
                'name' => 'Varsayılan Hatırlatma Akışı',
                'description' => 'Otomatik hatırlatmalar için varsayılan akış.',
                'status' => 'active',
                'target_statuses' => ['accepted', 'in_progress'],
                'target_roles' => ['student', 'teacher'],
                'created_by' => $actor?->id,
                'updated_by' => $actor?->id,
            ]
        );

        if ($actor && $workflow->wasRecentlyCreated) {
            $workflow->created_by = $actor->id;
            $workflow->updated_by = $actor->id;
            $workflow->save();
        }

        return $workflow;
    }

    private function sanitizeReminderChannelPayload(?array $payload, ?array $fallback = null): array
    {
        $base = $fallback ?? [
            'student' => [
                'push' => ['enabled' => false, 'template_id' => null],
                'email' => ['enabled' => false, 'template_id' => null],
                'sms' => ['enabled' => false, 'template_id' => null],
            ],
            'teacher' => [
                'push' => ['enabled' => false, 'template_id' => null],
                'email' => ['enabled' => false, 'template_id' => null],
                'sms' => ['enabled' => false, 'template_id' => null],
            ],
        ];

        if (!is_array($payload) || empty($payload)) {
            return $base;
        }

        $result = $base;

        foreach (['student', 'teacher'] as $audience) {
            foreach (['push', 'email', 'sms'] as $channel) {
                $channelPayload = $payload[$audience][$channel] ?? null;

                if (!is_array($channelPayload)) {
                    continue;
                }

                if (array_key_exists('enabled', $channelPayload)) {
                    $result[$audience][$channel]['enabled'] = (bool) $channelPayload['enabled'];
                }

                if (array_key_exists('template_id', $channelPayload)) {
                    $templateId = $channelPayload['template_id'];
                    $result[$audience][$channel]['template_id'] = $templateId !== null ? (int) $templateId : null;
                }
            }
        }

        return $result;
    }

    private function serializeBasicReminderChannels(bool $notifyStudent, bool $notifyTeacher, bool $sendEmail): array
    {
        return [
            'student' => [
                'push' => ['enabled' => $notifyStudent, 'template_id' => null],
                'email' => ['enabled' => $sendEmail, 'template_id' => null],
                'sms' => ['enabled' => false, 'template_id' => null],
            ],
            'teacher' => [
                'push' => ['enabled' => $notifyTeacher, 'template_id' => null],
                'email' => ['enabled' => false, 'template_id' => null],
                'sms' => ['enabled' => false, 'template_id' => null],
            ],
        ];
    }

    private function deriveReminderChannelFlags(array $channels): array
    {
        return [
            'notify_student' => (bool) ($channels['student']['push']['enabled'] ?? false),
            'notify_teacher' => (bool) ($channels['teacher']['push']['enabled'] ?? false),
            'send_email' => (bool) ($channels['student']['email']['enabled'] ?? false),
        ];
    }

    private function sanitizeReminderStatuses(?array $statuses): array
    {
        $allowed = ['pending', 'accepted', 'in_progress', 'completed', 'cancelled'];

        if (!is_array($statuses) || empty($statuses)) {
            return ['accepted', 'in_progress'];
        }

        return array_values(array_intersect($allowed, $statuses));
    }

    private function sanitizeReminderRoles(?array $roles): array
    {
        $allowed = ['student', 'teacher'];

        if (!is_array($roles) || empty($roles)) {
            return ['student', 'teacher'];
        }

        return array_values(array_intersect($allowed, $roles));
    }

    private function transformNotificationTemplate(NotificationTemplate $template): array
    {
        $template->loadMissing(['creator', 'updater']);

        return [
            'id' => $template->id,
            'name' => $template->name,
            'slug' => $template->slug,
            'channel' => $template->channel,
            'subject' => $template->subject,
            'body' => $template->body,
            'variables' => $template->variables,
            'action_url' => $template->action_url,
            'action_text' => $template->action_text,
            'is_default' => $template->is_default,
            'status' => $template->status,
            'created_by' => $template->creator?->only(['id', 'name', 'email']),
            'updated_by' => $template->updater?->only(['id', 'name', 'email']),
            'created_at' => $template->created_at?->toIso8601String(),
            'updated_at' => $template->updated_at?->toIso8601String(),
        ];
    }

    private function extractRescheduleRequest(?string $teacherNotes): ?array
    {
        if (empty($teacherNotes)) {
            return null;
        }

        $decoded = json_decode($teacherNotes, true);

        if (!is_array($decoded) || !isset($decoded['reschedule_request']) || !is_array($decoded['reschedule_request'])) {
            return null;
        }

        return $decoded['reschedule_request'];
    }

    private function decodeTeacherNotes(?string $teacherNotes): array
    {
        if (empty($teacherNotes)) {
            return [];
        }

        $decoded = json_decode($teacherNotes, true);

        if (json_last_error() !== JSON_ERROR_NONE || !is_array($decoded)) {
            return ['legacy_note' => $teacherNotes];
        }

        return $decoded;
    }

    private function syncTeacherNotes(Reservation $reservation, array $notes): void
    {
        $filteredNotes = array_filter($notes, function ($value) {
            return !is_null($value) && $value !== '' && $value !== [];
        });

        if (empty($filteredNotes)) {
            $reservation->teacher_notes = null;
        } else {
            $reservation->teacher_notes = json_encode($filteredNotes, JSON_UNESCAPED_UNICODE);
        }
    }

    private function extractRescheduleHistory(?string $teacherNotes, Reservation $reservation): array
    {
        $history = [];

        $decoded = [];

        if (!empty($teacherNotes)) {
            $decoded = json_decode($teacherNotes, true);

            if (isset($decoded['reschedule_history']) && is_array($decoded['reschedule_history'])) {
                $history = array_values($decoded['reschedule_history']);
            }
        }

        $pending = $this->extractRescheduleRequest($teacherNotes);

        if ($pending) {
            $history[] = array_merge($pending, ['current_status' => $reservation->status]);
        }

        return $history;
    }

    /**
     * Execute a bulk status update for reservations.
     *
     * @param array<int> $reservationIds
     */
    private function performBulkStatusUpdate(array $reservationIds, string $status, User $admin, array $options = []): array
    {
        $ids = array_values(array_unique($reservationIds));

        if (empty($ids)) {
            throw new \RuntimeException('RESERVATIONS_NOT_FOUND');
        }

        return DB::transaction(function () use ($ids, $status, $admin, $options) {
            $reservations = Reservation::with(['student', 'teacher', 'category', 'payments', 'lessons.teacher', 'lessons.student', 'reminderLogs.setting'])
                ->lockForUpdate()
                ->whereIn('id', $ids)
                ->get();

            if ($reservations->isEmpty()) {
                throw new \RuntimeException('RESERVATIONS_NOT_FOUND');
            }

            $notify = (bool) ($options['notify_participants'] ?? false);
            $adminNotes = $options['admin_notes'] ?? null;
            $hasAdminNotesColumn = Schema::hasColumn('reservations', 'admin_notes');
            $cancellationReason = $options['cancellation_reason'] ?? null;
            $ip = $options['ip'] ?? null;
            $userAgent = $options['user_agent'] ?? null;

            $transformed = [];
            $undoPayload = [];

            foreach ($reservations as $reservation) {
                $undoPayload[] = $this->buildReservationUndoSnapshot($reservation, $hasAdminNotesColumn);

                $previousStatus = $reservation->status;

                $reservation->status = $status;

                if ($adminNotes !== null && $hasAdminNotesColumn) {
                    $reservation->admin_notes = $adminNotes;
                }

                if ($status === 'cancelled') {
                    $reservation->cancelled_by_id = $admin->id;
                    $reservation->cancelled_reason = $cancellationReason;
                    $reservation->cancelled_at = now();
                } elseif ($previousStatus === 'cancelled') {
                    $reservation->cancelled_by_id = null;
                    $reservation->cancelled_reason = null;
                    $reservation->cancelled_at = null;
                }

                $reservation->save();
                $reservation->load(['student', 'teacher', 'category', 'payments', 'lessons.teacher', 'lessons.student', 'reminderLogs.setting']);

                $this->dispatchStatusNotifications($reservation, $previousStatus, $status, $admin, $notify);

                AuditLog::createLog(
                    $admin->id,
                    'reservation_status_bulk_updated',
                    Reservation::class,
                    $reservation->id,
                    [
                        'from' => $previousStatus,
                        'to' => $status,
                        'bulk' => true,
                        'notify_participants' => $notify,
                    ],
                    $ip,
                    $userAgent
                );

                $transformed[] = $this->transformReservationForAdmin($reservation);
            }

            return [
                'count' => count($transformed),
                'reservations' => $transformed,
                'undo' => $undoPayload,
            ];
        });
    }

    /**
     * Build the undo snapshot for a reservation.
     */
    private function buildReservationUndoSnapshot(Reservation $reservation, bool $includeAdminNotes = true): array
    {
        return [
            'reservation_id' => $reservation->id,
            'previous_status' => $reservation->status,
            'previous_cancelled_reason' => $reservation->cancelled_reason,
            'previous_cancelled_at' => $reservation->cancelled_at?->toIso8601String(),
            'previous_cancelled_by_id' => $reservation->cancelled_by_id,
            'previous_admin_notes' => $includeAdminNotes ? $reservation->admin_notes : null,
        ];
    }

    /**
     * Dispatch appropriate notifications for status changes.
     */
    private function dispatchStatusNotifications(Reservation $reservation, string $oldStatus, string $newStatus, User $actor, bool $shouldNotify): void
    {
        if (!$shouldNotify || $oldStatus === $newStatus) {
            return;
        }

        try {
            $reservation->loadMissing(['student', 'teacher']);

            switch ($newStatus) {
                case 'accepted':
                    if ($reservation->student && $reservation->teacher) {
                        $this->notificationService->sendReservationAcceptedNotification(
                            $reservation->student,
                            $reservation->teacher,
                            $reservation
                        );
                    }
                    break;
                case 'completed':
                    if ($reservation->student && $reservation->teacher) {
                        $this->notificationService->sendReservationCompletedNotification(
                            $reservation->student,
                            $reservation->teacher,
                            $reservation,
                            'student'
                        );
                        $this->notificationService->sendReservationCompletedNotification(
                            $reservation->teacher,
                            $reservation->student,
                            $reservation,
                            'teacher'
                        );
                        $this->notificationService->sendRatingRequestNotification(
                            $reservation->student,
                            $reservation->teacher,
                            $reservation
                        );
                    }
                    break;
                case 'cancelled':
                    if ($reservation->student) {
                        $this->notificationService->sendReservationCancelledNotification(
                            $reservation->student,
                            $actor,
                            $reservation
                        );
                    }
                    if ($reservation->teacher) {
                        $this->notificationService->sendReservationCancelledNotification(
                            $reservation->teacher,
                            $actor,
                            $reservation
                        );
                    }
                    break;
            }
        } catch (\Throwable $throwable) {
            Log::warning('Failed to send reservation status notifications', [
                'error' => $throwable->getMessage(),
                'reservation_id' => $reservation->id,
                'new_status' => $newStatus,
            ]);
        }
    }

    /**
     * @OA\Get(
     *     path="/admin/dashboard",
     *     tags={"Admin"},
     *     summary="Admin dashboard istatistikleri",
     *     description="Admin paneli için genel istatistikleri getirir",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="Dashboard verileri başarıyla getirildi",
     *         @OA\JsonContent(
     *             @OA\Property(property="stats", type="object"),
     *             @OA\Property(property="recent_activities", type="array", @OA\Items(type="object"))
     *         )
     *     )
     * )
     */
    public function dashboard(): JsonResponse
    {
        try {
            // Admin yetkisi zaten middleware tarafından kontrol ediliyor
            $dashboardData = $this->analyticsService->getDashboardStats();
            $realTimeStats = $this->analyticsService->getRealTimeStats();

            return response()->json([
                'success' => true,
                'stats' => $dashboardData,
                'real_time' => $realTimeStats,
                'timestamp' => now()->toISOString(),
            ]);
        } catch (\Exception $e) {
            \Log::error('Dashboard error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => 'Dashboard verileri yüklenirken hata oluştu',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * En iyi öğretmenleri getir
     */
    private function getTopTeachers(): array
    {
        return \DB::table('users')
            ->join('teachers', 'users.id', '=', 'teachers.user_id')
            ->select(
                'users.id',
                'users.name',
                'users.email',
                'teachers.rating_avg',
                'teachers.rating_count',
                \DB::raw('COUNT(reservations.id) as total_lessons')
            )
            ->leftJoin('reservations', function ($join) {
                $join->on('users.id', '=', 'reservations.teacher_id')
                     ->where('reservations.status', '=', 'completed');
            })
            ->where('users.role', 'teacher')
            ->where('users.teacher_status', 'approved')
            ->groupBy('users.id', 'users.name', 'users.email', 'teachers.rating_avg', 'teachers.rating_count')
            ->orderBy('teachers.rating_avg', 'desc')
            ->orderBy('total_lessons', 'desc')
            ->limit(10)
            ->get()
            ->toArray();
    }

    /**
     * Kullanıcı büyüme istatistikleri
     */
    private function getUserGrowthStats(): array
    {
        $months = [];
        for ($i = 11; $i >= 0; $i--) {
            $date = now()->subMonths($i);
            $months[] = [
                'month' => $date->format('M Y'),
                'users' => User::whereYear('created_at', $date->year)
                    ->whereMonth('created_at', $date->month)
                    ->count(),
                'teachers' => User::where('role', 'teacher')
                    ->whereYear('created_at', $date->year)
                    ->whereMonth('created_at', $date->month)
                    ->count(),
                'students' => User::where('role', 'student')
                    ->whereYear('created_at', $date->year)
                    ->whereMonth('created_at', $date->month)
                    ->count(),
            ];
        }
        
        return $months;
    }

    /**
     * @OA\Get(
     *     path="/admin/analytics",
     *     tags={"Admin"},
     *     summary="Detaylı analitik veriler",
     *     description="Admin paneli için detaylı analitik verileri getirir",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="Analitik veriler başarıyla getirildi"
     *     )
     * )
     */
    public function getAnalytics(): JsonResponse
    {
        try {
            $analytics = [
                'user_growth' => $this->getUserGrowthData(),
                'reservation_trends' => $this->getReservationTrends(),
                'category_popularity' => $this->getCategoryPopularity(),
                'teacher_performance' => $this->getTeacherPerformance(),
            ];

            return response()->json([
                'success' => true,
                'analytics' => $analytics,
            ]);
        } catch (\Exception $e) {
            \Log::error('Analytics error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => 'Analytics verileri yüklenirken hata oluştu',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * @OA\Put(
     *     path="/admin/users/{user}/status",
     *     tags={"Admin"},
     *     summary="Kullanıcı durumunu güncelle",
     *     description="Kullanıcının aktif/pasif durumunu günceller",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="user",
     *         in="path",
     *         required=true,
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             @OA\Property(property="status", type="string", enum={"active", "suspended"}),
     *             @OA\Property(property="reason", type="string")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Kullanıcı durumu başarıyla güncellendi"
     *     )
     * )
     */
    public function updateUserStatus(Request $request, User $user): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'status' => 'required|in:active,suspended',
            'reason' => 'nullable|string|max:500',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $status = $request->status;
        $reason = $request->reason;

        if ($status === 'suspended') {
            $user->update([
                'suspended_at' => now(),
                'suspension_reason' => $reason,
            ]);
        } else {
            $user->update([
                'suspended_at' => null,
                'suspended_until' => null,
                'suspension_reason' => null,
            ]);
        }

        // Log the action
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'user_status_updated',
            'description' => "User {$user->name} status updated to {$status}",
            'severity' => $status === 'suspended' ? 'warning' : 'info',
            'meta' => [
                'target_user_id' => $user->id,
                'status' => $status,
                'reason' => $reason,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Kullanıcı durumu başarıyla güncellendi',
            'user' => $user->fresh(),
        ]);
    }

    // getReservations method moved to later in file to avoid duplicates

    /**
     * @OA\Get(
     *     path="/admin/categories",
     *     tags={"Admin"},
     *     summary="Kategorileri listele",
     *     description="Admin paneli için kategorileri getirir",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="Kategoriler başarıyla getirildi"
     *     )
     * )
     */
    public function getCategories(): JsonResponse
    {
        $categories = Category::with('children')
            ->orderBy('sort_order')
            ->get();

        return response()->json([
            'success' => true,
            'categories' => $categories,
        ]);
    }

    /**
     * @OA\Post(
     *     path="/admin/categories",
     *     tags={"Admin"},
     *     summary="Yeni kategori oluştur",
     *     description="Admin paneli için yeni kategori oluşturur",
     *     security={{"bearerAuth":{}}},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             @OA\Property(property="name", type="string"),
     *             @OA\Property(property="description", type="string"),
     *             @OA\Property(property="parent_id", type="integer"),
     *             @OA\Property(property="icon", type="string"),
     *             @OA\Property(property="sort_order", type="integer")
     *         )
     *     ),
     *     @OA\Response(
     *         response=201,
     *         description="Kategori başarıyla oluşturuldu"
     *     )
     * )
     */
    public function createCategory(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'description' => 'nullable|string',
            'parent_id' => 'nullable|exists:categories,id',
            'icon' => 'nullable|string|max:255',
            'sort_order' => 'nullable|integer|min:0',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $category = Category::create([
            'name' => $request->name,
            'description' => $request->description,
            'parent_id' => $request->parent_id,
            'icon' => $request->icon,
            'sort_order' => $request->sort_order ?? 0,
            'slug' => \Str::slug($request->name),
        ]);

        // Log the action
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'category_created',
            'description' => "Category '{$category->name}' created",
            'severity' => 'info',
            'meta' => [
                'category_id' => $category->id,
                'category_name' => $category->name,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Kategori başarıyla oluşturuldu',
            'category' => $category,
        ], 201);
    }

    /**
     * @OA\Get(
     *     path="/admin/audit-logs",
     *     tags={"Admin"},
     *     summary="Audit loglarını listele",
     *     description="Admin paneli için audit loglarını getirir",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="action",
     *         in="query",
     *         @OA\Schema(type="string")
     *     ),
     *     @OA\Parameter(
     *         name="user_id",
     *         in="query",
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Audit logları başarıyla getirildi"
     *     )
     * )
     */
    public function getAuditLogs(Request $request): JsonResponse
    {
        $query = AuditLog::with('user')
            ->when($request->filled('action'), fn ($q) => $q->where('action', $request->input('action')))
            ->when($request->filled('user_id'), fn ($q) => $q->where('user_id', $request->integer('user_id')))
            ->when($request->filled('severity'), fn ($q) => $q->severity($request->input('severity')))
            ->when($request->filled('target_type'), fn ($q) => $q->where('target_type', $request->input('target_type')))
            ->when($request->filled('target_id'), fn ($q) => $q->where('target_id', $request->integer('target_id')))
            ->betweenDates(
                $request->input('from'),
                $request->input('to')
            )
            ->search($request->input('query'));

        $sort = $request->input('sort', 'created_at_desc');
        [$sortColumn, $sortDirection] = match ($sort) {
            'created_at_asc' => ['created_at', 'asc'],
            'severity_desc' => ['severity', 'desc'],
            'severity_asc' => ['severity', 'asc'],
            default => ['created_at', 'desc'],
        };

        $logs = $query->orderBy($sortColumn, $sortDirection)
            ->paginate($request->integer('per_page', 20));

        $actions = AuditLog::query()
            ->select('action')
            ->distinct()
            ->orderBy('action')
            ->pluck('action');

        $targetTypes = AuditLog::query()
            ->select('target_type')
            ->distinct()
            ->orderBy('target_type')
            ->pluck('target_type');

        return response()->json([
            'success' => true,
            'logs' => $logs->items(),
            'pagination' => [
                'current_page' => $logs->currentPage(),
                'last_page' => $logs->lastPage(),
                'per_page' => $logs->perPage(),
                'total' => $logs->total(),
            ],
            'filters' => [
                'actions' => $actions,
                'target_types' => $targetTypes,
            ],
        ]);
    }

    // User management methods
    public function listUsers(Request $request): JsonResponse
    {
        $query = User::query();

        if ($request->has('role') && $request->role) {
            $query->where('role', $request->role);
        }

        if ($request->has('status') && $request->status) {
            if ($request->status === 'active') {
                $query->whereNull('suspended_at');
            } elseif ($request->status === 'suspended') {
                $query->whereNotNull('suspended_at');
            }
        }

        $users = $query->orderBy('created_at', 'desc')
            ->paginate($request->get('per_page', 20));

        return response()->json([
            'success' => true,
            'users' => $users->items(),
            'pagination' => [
                'current_page' => $users->currentPage(),
                'last_page' => $users->lastPage(),
                'per_page' => $users->perPage(),
                'total' => $users->total(),
            ],
        ]);
    }

    public function searchUsers(Request $request): JsonResponse
    {
        $query = $request->get('q', '');
        
        if (strlen($query) < 2) {
            return response()->json([
                'success' => true,
                'users' => [],
            ]);
        }

        $users = User::where('name', 'like', "%{$query}%")
            ->orWhere('email', 'like', "%{$query}%")
            ->limit(20)
            ->get();

        return response()->json([
            'success' => true,
            'users' => $users,
        ]);
    }

    public function deleteUser(int $id): JsonResponse
    {
        $user = User::findOrFail($id);
        
        // Prevent admin from deleting themselves
        if ($user->id === Auth::id()) {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Kendi hesabınızı silemezsiniz'
                ]
            ], 403);
        }

        $userName = $user->name;
        $user->delete();

        // Log the action
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'user_deleted',
            'description' => "User '{$userName}' deleted",
            'severity' => 'warning',
            'meta' => [
                'deleted_user_id' => $id,
                'deleted_user_name' => $userName,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Kullanıcı başarıyla silindi',
        ]);
    }

    public function deleteMultipleUsers(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'user_ids' => 'required|array|min:1',
            'user_ids.*' => 'integer|exists:users,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $userIds = $request->user_ids;
        $deletedCount = 0;

        foreach ($userIds as $userId) {
            if ($userId !== Auth::id()) {
                $user = User::find($userId);
                if ($user) {
                    $user->delete();
                    $deletedCount++;
                }
            }
        }

        // Log the action
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'multiple_users_deleted',
            'description' => "{$deletedCount} users deleted",
            'severity' => 'warning',
            'meta' => [
                'deleted_user_ids' => $userIds,
                'deleted_count' => $deletedCount,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => "{$deletedCount} kullanıcı başarıyla silindi",
            'deleted_count' => $deletedCount,
        ]);
    }

    public function deleteUsersByName(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|min:2',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $name = $request->name;
        $users = User::where('name', 'like', "%{$name}%")->get();
        $deletedCount = 0;

        foreach ($users as $user) {
            if ($user->id !== Auth::id()) {
                $user->delete();
                $deletedCount++;
            }
        }

        // Log the action
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'users_deleted_by_name',
            'description' => "Users with name '{$name}' deleted",
            'severity' => 'warning',
            'meta' => [
                'search_name' => $name,
                'deleted_count' => $deletedCount,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => "İsimde '{$name}' geçen {$deletedCount} kullanıcı silindi",
            'deleted_count' => $deletedCount,
        ]);
    }

    // Teacher approval methods (moved to later in file to avoid duplicates)

    // Helper methods for analytics
    private function getUserGrowthData(): array
    {
        try {
            $data = [];
            for ($i = 11; $i >= 0; $i--) {
                $date = now()->subMonths($i);
                $count = User::whereYear('created_at', $date->year)
                    ->whereMonth('created_at', $date->month)
                    ->count();
                $data[] = [
                    'month' => $date->format('Y-m'),
                    'count' => $count,
                ];
            }
            return $data;
        } catch (\Exception $e) {
            \Log::error('User growth data error: ' . $e->getMessage());
            return [];
        }
    }

    private function getReservationTrends(): array
    {
        try {
            $data = [];
            for ($i = 6; $i >= 0; $i--) {
                $date = now()->subDays($i);
                $count = Reservation::whereDate('created_at', $date)->count();
                $data[] = [
                    'date' => $date->format('Y-m-d'),
                    'count' => $count,
                ];
            }
            return $data;
        } catch (\Exception $e) {
            \Log::error('Reservation trends error: ' . $e->getMessage());
            return [];
        }
    }

    private function getCategoryPopularity(): array
    {
        try {
            return Category::withCount('reservations')
                ->orderBy('reservations_count', 'desc')
                ->limit(10)
                ->get()
                ->map(function ($category) {
                    return [
                        'name' => $category->name,
                        'count' => $category->reservations_count ?? 0,
                    ];
                })
                ->toArray();
        } catch (\Exception $e) {
            \Log::error('Category popularity error: ' . $e->getMessage());
            return [];
        }
    }

    private function getTeacherPerformance(): array
    {
        try {
            return Teacher::with('user')
                ->withCount('reservations')
                ->orderBy('reservations_count', 'desc')
                ->limit(10)
                ->get()
                ->map(function ($teacher) {
                    return [
                        'name' => $teacher->user->name ?? 'Bilinmeyen',
                        'reservations_count' => $teacher->reservations_count ?? 0,
                        'average_rating' => $teacher->rating_avg ?? 0,
                    ];
                })
                ->toArray();
        } catch (\Exception $e) {
            \Log::error('Teacher performance error: ' . $e->getMessage());
            return [];
        }
    }

    /**
     * Suspend a user
     */
    public function suspendUser(Request $request, int $userId): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'reason' => 'required|string|max:255',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Geçersiz veri',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $user = User::findOrFail($userId);
            
            // Update user status
            $user->update([
                'status' => 'suspended',
                'suspended_reason' => $request->reason,
                'suspended_at' => now(),
                'suspended_by' => Auth::id(),
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Kullanıcı başarıyla askıya alındı',
                'user' => $user->fresh()
            ]);

        } catch (\Exception $e) {
            \Log::error('Error suspending user: ' . $e->getMessage());
            return response()->json([
                'error' => [
                    'code' => 'SUSPEND_USER_ERROR',
                    'message' => 'Kullanıcı askıya alınırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Unsuspend a user
     */
    public function unsuspendUser(Request $request, int $userId): JsonResponse
    {
        try {
            $user = User::findOrFail($userId);
            
            // Update user status
            $user->update([
                'status' => 'active',
                'suspended_reason' => null,
                'suspended_at' => null,
                'suspended_by' => null,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Kullanıcı askıdan kaldırıldı',
                'user' => $user->fresh()
            ]);

        } catch (\Exception $e) {
            \Log::error('Error unsuspending user: ' . $e->getMessage());
            return response()->json([
                'error' => [
                    'code' => 'UNSUSPEND_USER_ERROR',
                    'message' => 'Kullanıcı askıdan kaldırılırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * @OA\Get(
     *     path="/admin/users",
     *     tags={"Admin"},
     *     summary="Tüm kullanıcıları listele",
     *     description="Admin paneli için kullanıcı listesini getirir",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="role",
     *         in="query",
     *         @OA\Schema(type="string", enum={"student", "teacher", "admin"})
     *     ),
     *     @OA\Parameter(
     *         name="status",
     *         in="query",
     *         @OA\Schema(type="string", enum={"active", "suspended"})
     *     ),
     *     @OA\Parameter(
     *         name="search",
     *         in="query",
     *         @OA\Schema(type="string")
     *     ),
     *     @OA\Parameter(
     *         name="page",
     *         in="query",
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Kullanıcı listesi başarıyla getirildi"
     *     )
     * )
     */
    public function getUsers(Request $request): JsonResponse
    {
        $query = User::query();

        // Filtreleme
        if ($request->filled('role')) {
            $query->where('role', $request->role);
        }

        if ($request->filled('status')) {
            if ($request->status === 'active') {
                $query->where('status', 'active');
            } elseif ($request->status === 'suspended') {
                $query->where('status', 'suspended');
            }
        }

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('email', 'like', "%{$search}%");
            });
        }

        // Sayfalama
        $perPage = $request->get('per_page', 20);
        $users = $query->with(['teacher'])
            ->orderBy('created_at', 'desc')
            ->paginate($perPage);

        return response()->json([
            'success' => true,
            'users' => $users->items(),
            'pagination' => [
                'current_page' => $users->currentPage(),
                'last_page' => $users->lastPage(),
                'per_page' => $users->perPage(),
                'total' => $users->total(),
            ],
        ]);
    }

    /**
     * @OA\Get(
     *     path="/admin/teachers/pending",
     *     tags={"Admin"},
     *     summary="Onay bekleyen öğretmenleri listele",
     *     description="Admin onayı bekleyen öğretmenleri getirir",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="Onay bekleyen öğretmenler başarıyla getirildi"
     *     )
     * )
     */
    public function getPendingTeachers(): JsonResponse
    {
        $pendingTeachers = User::with(['teacher'])
            ->where('role', 'teacher')
            ->where('teacher_status', 'pending')
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json([
            'success' => true,
            'pending_teachers' => $pendingTeachers,
        ]);
    }

    /**
     * @OA\Post(
     *     path="/admin/teachers/{user}/approve",
     *     tags={"Admin"},
     *     summary="Öğretmeni onayla",
     *     description="Bekleyen öğretmen başvurusunu onaylar",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="user",
     *         in="path",
     *         required=true,
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             @OA\Property(property="notes", type="string")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Öğretmen başarıyla onaylandı"
     *     )
     * )
     */
    public function approveTeacher(Request $request, User $user): JsonResponse
    {
        if ($user->role !== 'teacher') {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_USER',
                    'message' => 'Bu kullanıcı bir öğretmen değil'
                ]
            ], 400);
        }

        if ($user->teacher_status !== 'pending') {
            return response()->json([
                'error' => [
                    'code' => 'ALREADY_PROCESSED',
                    'message' => 'Bu öğretmen başvurusu zaten işlenmiş'
                ]
            ], 400);
        }

        $adminId = Auth::id();
        $notes = $request->input('notes');

        $user->approveTeacher($adminId, $notes);

        // ✅ Send approval notification
        try {
            $admin = Auth::user();
            $this->notificationService->sendTeacherApprovedNotification($user, $admin);
            Log::info('✅ Teacher approval notification sent', [
                'teacher_id' => $user->id,
                'admin_id' => $adminId
            ]);
        } catch (\Exception $e) {
            Log::warning('Failed to send teacher approval notification: ' . $e->getMessage());
        }

        // Audit log
        AuditLog::create([
            'user_id' => $adminId,
            'action' => 'teacher_approved',
            'description' => "Teacher {$user->name} approved",
            'severity' => 'info',
            'target_type' => 'user',
            'target_id' => $user->id,
            'meta' => [
                'teacher_name' => $user->name,
                'notes' => $notes,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Öğretmen başarıyla onaylandı',
            'teacher' => $user->fresh()->load('teacher'),
        ]);
    }

    /**
     * @OA\Post(
     *     path="/admin/teachers/{user}/reject",
     *     tags={"Admin"},
     *     summary="Öğretmeni reddet",
     *     description="Bekleyen öğretmen başvurusunu reddeder",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="user",
     *         in="path",
     *         required=true,
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             @OA\Property(property="reason", type="string")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Öğretmen başvurusu reddedildi"
     *     )
     * )
     */
    public function rejectTeacher(Request $request, User $user): JsonResponse
    {
        if ($user->role !== 'teacher') {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_USER',
                    'message' => 'Bu kullanıcı bir öğretmen değil'
                ]
            ], 400);
        }

        if ($user->teacher_status !== 'pending') {
            return response()->json([
                'error' => [
                    'code' => 'ALREADY_PROCESSED',
                    'message' => 'Bu öğretmen başvurusu zaten işlenmiş'
                ]
            ], 400);
        }

        $validator = Validator::make($request->all(), [
            'reason' => 'required|string|max:500',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $adminId = Auth::id();
        $reason = $request->input('reason');

        $user->update([
            'teacher_status' => 'rejected',
            'rejected_by' => $adminId,
            'rejected_at' => now(),
            'rejection_reason' => $reason,
        ]);

        // ✅ Send rejection notification
        try {
            $this->notificationService->sendTeacherRejectedNotification($user, $reason);
            Log::info('✅ Teacher rejection notification sent', [
                'teacher_id' => $user->id,
                'admin_id' => $adminId,
                'reason' => $reason
            ]);
        } catch (\Exception $e) {
            Log::warning('Failed to send teacher rejection notification: ' . $e->getMessage());
        }

        // Audit log
        AuditLog::create([
            'user_id' => $adminId,
            'action' => 'teacher_rejected',
            'target_type' => 'user',
            'target_id' => $user->id,
            'details' => [
                'teacher_name' => $user->name,
                'reason' => $reason,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Öğretmen başvurusu reddedildi',
            'teacher' => $user->fresh()->load('teacher'),
        ]);
    }

    /**
     * @OA\Get(
     *     path="/admin/reservations",
     *     tags={"Admin"},
     *     summary="Tüm rezervasyonları listele",
     *     description="Admin paneli için rezervasyon listesini getirir",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="status",
     *         in="query",
     *         @OA\Schema(type="string", enum={"pending", "confirmed", "in_progress", "completed", "cancelled"})
     *     ),
     *     @OA\Parameter(
     *         name="page",
     *         in="query",
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Rezervasyon listesi başarıyla getirildi"
     *     )
     * )
     */
    public function getReservations(Request $request): JsonResponse
    {
        $query = Reservation::with([
            'student',
            'teacher',
            'category',
            'payments',
            'lessons.teacher',
            'lessons.student',
            'reminderLogs.setting',
        ]);

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        if ($request->filled('date_from')) {
            try {
                $from = Carbon::parse($request->date_from)->startOfDay();
                $query->where('proposed_datetime', '>=', $from);
            } catch (\Exception $e) {
                // Ignore invalid date formats
            }
        }

        if ($request->filled('date_to')) {
            try {
                $to = Carbon::parse($request->date_to)->endOfDay();
                $query->where('proposed_datetime', '<=', $to);
            } catch (\Exception $e) {
                // Ignore invalid date formats
            }
        }

        if ($request->filled('teacher_id')) {
            $query->where('teacher_id', $request->get('teacher_id'));
        } elseif ($request->filled('teacher_query')) {
            $teacherQuery = $request->get('teacher_query');
            $query->whereHas('teacher', function ($q) use ($teacherQuery) {
                $q->where('name', 'like', "%{$teacherQuery}%")
                    ->orWhere('email', 'like', "%{$teacherQuery}%");
            });
        }

        if ($request->filled('student_id')) {
            $query->where('student_id', $request->get('student_id'));
        } elseif ($request->filled('student_query')) {
            $studentQuery = $request->get('student_query');
            $query->whereHas('student', function ($q) use ($studentQuery) {
                $q->where('name', 'like', "%{$studentQuery}%")
                    ->orWhere('email', 'like', "%{$studentQuery}%");
            });
        }

        if ($request->filled('search')) {
            $search = $request->get('search');
            $query->where(function ($q) use ($search) {
                $q->where('subject', 'like', "%{$search}%")
                    ->orWhere('notes', 'like', "%{$search}%")
                    ->orWhereHas('category', function ($categoryQuery) use ($search) {
                        $categoryQuery->where('name', 'like', "%{$search}%");
                    });
            });
        }

        $perPage = (int) $request->get('per_page', 20);
        $reservations = $query->orderBy('proposed_datetime', 'desc')
            ->paginate($perPage);

        $transformedReservations = $reservations->getCollection()
            ->map(fn (Reservation $reservation) => $this->transformReservationForAdmin($reservation))
            ->values();

        return response()->json([
            'success' => true,
            'reservations' => $transformedReservations,
            'pagination' => [
                'current_page' => $reservations->currentPage(),
                'last_page' => $reservations->lastPage(),
                'per_page' => $reservations->perPage(),
                'total' => $reservations->total(),
            ],
        ]);
    }

    public function getReservationCalendar(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'start_date' => 'nullable|date',
            'end_date' => 'nullable|date|after_or_equal:start_date',
            'teacher_id' => 'nullable|integer|exists:users,id',
            'student_id' => 'nullable|integer|exists:users,id',
            'category_id' => 'nullable|integer|exists:categories,id',
            'status' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $start = $request->filled('start_date')
            ? Carbon::parse($request->input('start_date'))->startOfDay()
            : Carbon::now()->startOfDay();

        $end = $request->filled('end_date')
            ? Carbon::parse($request->input('end_date'))->endOfDay()
            : (clone $start)->addDays(30)->endOfDay();

        $query = Reservation::with(['student', 'teacher', 'category'])
            ->whereNotNull('proposed_datetime')
            ->whereBetween('proposed_datetime', [$start, $end]);

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        if ($request->filled('teacher_id')) {
            $query->where('teacher_id', $request->teacher_id);
        }

        if ($request->filled('student_id')) {
            $query->where('student_id', $request->student_id);
        }

        if ($request->filled('category_id')) {
            $query->where('category_id', $request->category_id);
        }

        $reservations = $query->orderBy('proposed_datetime')->get();

        $items = $reservations->map(function (Reservation $reservation) {
            $start = $reservation->proposed_datetime?->copy();

            $duration = $reservation->duration_minutes ?? 60;
            $end = $start ? $start->copy()->addMinutes($duration) : null;

            $reschedule = $this->extractRescheduleRequest($reservation->teacher_notes);

            return [
                'id' => $reservation->id,
                'title' => $reservation->subject ?? $reservation->category->name ?? "Rezervasyon #{$reservation->id}",
                'subject' => $reservation->subject,
                'status' => $reservation->status,
                'start' => $start?->toIso8601String(),
                'end' => $end?->toIso8601String(),
                'proposed_datetime' => $reservation->proposed_datetime?->toIso8601String(),
                'created_at' => $reservation->created_at?->toIso8601String(),
                'duration_minutes' => $reservation->duration_minutes,
                'price' => $reservation->price,
                'currency' => $reservation->currency ?? 'TRY',
                'payment_status' => $reservation->payment_status,
                'notes' => $reservation->notes,
                'teacher_notes' => $reservation->teacher_notes,
                'admin_notes' => $reservation->admin_notes ?? null,
                'student_id' => $reservation->student_id,
                'teacher_id' => $reservation->teacher_id,
                'category_id' => $reservation->category_id,
                'category' => $reservation->category?->only(['id', 'name']),
                'teacher' => $reservation->teacher ? [
                    'id' => $reservation->teacher->id,
                    'name' => $reservation->teacher->name,
                    'email' => $reservation->teacher->email,
                ] : null,
                'student' => $reservation->student ? [
                    'id' => $reservation->student->id,
                    'name' => $reservation->student->name,
                    'email' => $reservation->student->email,
                ] : null,
                'is_reschedule_pending' => ($reschedule['status'] ?? null) === 'pending',
                'reschedule_request' => $reschedule,
            ];
        });

        return response()->json([
            'success' => true,
            'start_date' => $start->toDateString(),
            'end_date' => $end->toDateString(),
            'count' => $items->count(),
            'reservations' => $items,
        ]);
    }

    /**
     * @OA\Put(
     *     path="/admin/reservations/{reservation}/status",
     *     tags={"Admin"},
     *     summary="Rezervasyon durumunu güncelle",
     *     description="Admin kullanıcıları için rezervasyon durumunu ve notlarını günceller",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="reservation",
     *         in="path",
     *         required=true,
     *         description="Rezervasyon ID"
     *     ),
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             @OA\Property(property="status", type="string", enum={"pending", "accepted", "in_progress", "completed", "cancelled"}),
     *             @OA\Property(property="teacher_notes", type="string"),
     *             @OA\Property(property="admin_notes", type="string"),
     *             @OA\Property(property="notify_participants", type="boolean", default=true),
     *             @OA\Property(property="cancellation_reason", type="string")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Rezervasyon durum güncellemesi başarılı",
     *     )
     * )
     */
    public function updateReservationStatus(Request $request, Reservation $reservation): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'status' => 'required|string|in:pending,accepted,in_progress,completed,cancelled',
            'teacher_notes' => 'nullable|string|max:1000',
            'admin_notes' => 'nullable|string|max:1000',
            'notes' => 'nullable|string|max:1000',
            'notify_participants' => 'sometimes|boolean',
            'cancellation_reason' => 'nullable|string|max:500',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $status = $request->input('status');
        $oldStatus = $reservation->status;
        $notifyParticipants = $request->boolean('notify_participants', true);

        $reservation->status = $status;

        if ($request->has('teacher_notes')) {
            $reservation->teacher_notes = $request->input('teacher_notes');
        }

        if ($request->has('notes')) {
            $reservation->notes = $request->input('notes');
        }

        if ($request->has('admin_notes') && Schema::hasColumn('reservations', 'admin_notes')) {
            $reservation->admin_notes = $request->input('admin_notes');
        }

        if ($status === 'cancelled') {
            $reservation->cancelled_by_id = $admin->id;
            $reservation->cancelled_reason = $request->input('cancellation_reason');
            $reservation->cancelled_at = now();
        } else {
            $reservation->cancelled_by_id = null;
            $reservation->cancelled_reason = null;
            $reservation->cancelled_at = null;
        }

        $reservation->save();
        $reservation->load(['student', 'teacher', 'category', 'payments', 'lessons.teacher', 'lessons.student', 'reminderLogs.setting']);

        $this->dispatchStatusNotifications($reservation, $oldStatus, $status, $admin, $notifyParticipants);

        AuditLog::createLog(
            $admin->id,
            'reservation_status_updated',
            Reservation::class,
            $reservation->id,
            [
                'previous_status' => $oldStatus,
                'new_status' => $status,
                'notify_participants' => $notifyParticipants,
                'cancellation_reason' => $request->input('cancellation_reason'),
            ],
            $request->ip(),
            $request->userAgent()
        );

        return response()->json([
            'success' => true,
            'message' => 'Rezervasyon durumu güncellendi',
            'reservation' => $this->transformReservationForAdmin($reservation),
        ]);
    }

    public function updateReservationSchedule(Request $request, Reservation $reservation): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'proposed_datetime' => 'required|date',
            'duration_minutes' => 'nullable|integer|min:15|max:480',
            'teacher_id' => 'nullable|integer|exists:users,id',
            'category_id' => 'nullable|integer|exists:categories,id',
            'notify_participants' => 'sometimes|boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $payload = $validator->validated();

        $oldDatetime = $reservation->proposed_datetime?->toIso8601String();
        $oldDuration = $reservation->duration_minutes;
        $oldTeacher = $reservation->teacher_id;
        $oldCategory = $reservation->category_id;

        $reservation->proposed_datetime = Carbon::parse($payload['proposed_datetime']);

        if (array_key_exists('duration_minutes', $payload)) {
            $reservation->duration_minutes = $payload['duration_minutes'] ?? $reservation->duration_minutes;
        }

        if (array_key_exists('teacher_id', $payload)) {
            $reservation->teacher_id = $payload['teacher_id'];
        }

        if (array_key_exists('category_id', $payload)) {
            $reservation->category_id = $payload['category_id'];
        }

        $reservation->save();
        $reservation->load(['student', 'teacher', 'category', 'lessons.teacher', 'lessons.student', 'reminderLogs.setting']);

        AuditLog::createLog(
            $admin->id,
            'reservation_schedule_updated',
            Reservation::class,
            $reservation->id,
            [
                'old_datetime' => $oldDatetime,
                'new_datetime' => $reservation->proposed_datetime?->toIso8601String(),
                'old_duration' => $oldDuration,
                'new_duration' => $reservation->duration_minutes,
                'old_teacher_id' => $oldTeacher,
                'new_teacher_id' => $reservation->teacher_id,
                'old_category_id' => $oldCategory,
                'new_category_id' => $reservation->category_id,
            ],
            $request->ip(),
            $request->userAgent()
        );

        return response()->json([
            'success' => true,
            'reservation' => $this->transformReservationForAdmin($reservation),
        ]);
    }

    /**
     * @OA\Post(
     *     path="/admin/reservations/{reservation}/refund",
     *     tags={"Admin"},
     *     summary="Rezervasyon ödemesini iade et",
     *     description="Admin kullanıcıları için manuel (offline) rezervasyon iadesi gerçekleştirir",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="reservation",
     *         in="path",
     *         required=true,
     *         description="Rezervasyon ID"
     *     ),
     *     @OA\RequestBody(
     *         required=false,
     *         @OA\JsonContent(
     *             @OA\Property(property="refund_amount", type="number", format="float"),
     *             @OA\Property(property="reason", type="string"),
     *             @OA\Property(property="notify_participants", type="boolean", default=true),
     *             @OA\Property(property="cancel_reservation", type="boolean", default=false)
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="İade işlemi başarıyla tamamlandı",
     *     )
     * )
     */
    public function refundReservation(Request $request, Reservation $reservation): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'refund_amount' => 'nullable|numeric|min:0',
            'reason' => 'nullable|string|max:500',
            'notify_participants' => 'sometimes|boolean',
            'cancel_reservation' => 'sometimes|boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        if (!in_array($reservation->payment_status, ['paid', 'partial_refund'])) {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_PAYMENT_STATUS',
                    'message' => 'Yalnızca ödemesi tamamlanmış rezervasyonlar için iade yapılabilir',
                ],
            ], 400);
        }

        $payment = Payment::where('reservation_id', $reservation->id)
            ->whereIn('status', ['success', 'processing', 'refunded'])
            ->latest('paid_at')
            ->first();

        if (!$payment || !$payment->paid_at) {
            return response()->json([
                'error' => [
                    'code' => 'PAYMENT_NOT_FOUND',
                    'message' => 'İade edilecek bir ödeme kaydı bulunamadı',
                ],
            ], 404);
        }

        $notifyParticipants = $request->boolean('notify_participants', true);
        $cancelReservation = $request->boolean('cancel_reservation', false);
        $existingRefund = (float) ($reservation->refund_amount ?? 0);
        $maxRefund = (float) ($reservation->price ?? $payment->amount ?? 0);
        $remainingRefundable = max($maxRefund - $existingRefund, 0);

        if ($remainingRefundable <= 0) {
            return response()->json([
                'error' => [
                    'code' => 'ALREADY_REFUNDED',
                    'message' => 'Bu rezervasyon için iade limiti dolmuştur',
                ],
            ], 400);
        }

        $requestedRefund = (float) $request->input('refund_amount', $remainingRefundable);
        $refundAmount = min($requestedRefund, $remainingRefundable);

        if ($refundAmount <= 0) {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_REFUND_AMOUNT',
                    'message' => 'Geçerli bir iade tutarı giriniz',
                ],
            ], 422);
        }

        $refund = $this->reservationRefundService->createRefund($reservation, $payment, [
            'amount' => $refundAmount,
            'currency' => $reservation->currency ?? $payment->currency ?? 'TRY',
            'reason' => $request->input('reason'),
            'notify_participants' => $notifyParticipants,
            'cancel_reservation' => $cancelReservation,
            'max_attempts' => 3,
            'provider_payload' => [
                'merchant_oid' => $payment->paytr_order_id,
            ],
            'meta' => [
                'existing_refund_total' => $existingRefund,
                'requested_refund' => $requestedRefund,
                'max_refund' => $maxRefund,
            ],
            'created_by' => $admin->id,
        ]);

        $processingResult = $this->reservationRefundService->processRefund($refund);

        if (!($processingResult['success'] ?? false)) {
            if (config('queue.default') !== 'sync') {
                ProcessReservationRefundJob::dispatch($refund);
            } else {
                return response()->json([
                    'error' => [
                        'code' => $processingResult['code'] ?? 'REFUND_ERROR',
                        'message' => $processingResult['message'] ?? 'İade işlemi başarısız oldu',
                        'details' => $processingResult['response'] ?? null,
                    ],
                ], 502);
            }
        }

        $reservation->refresh();
        $reservation->load([
            'student',
            'teacher',
            'category',
            'payments',
            'refunds.payment',
            'refunds.creator',
            'lessons.teacher',
            'lessons.student',
            'reminderLogs.setting',
        ]);

        $refund->load(['payment', 'creator']);

        $message = ($processingResult['success'] ?? false)
            ? 'İade işlemi tamamlandı'
            : 'İade talebi kuyruğa alındı';

        return response()->json([
            'success' => true,
            'message' => $message,
            'reservation' => $this->transformReservationForAdmin($reservation),
            'refund' => $this->transformReservationRefund($refund),
            'paytr' => $processingResult['paytr'] ?? null,
            'status' => $refund->status,
        ]);
    }

    /**
     * Bulk update reservation statuses.
     */
    public function bulkUpdateReservationStatus(Request $request): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'reservation_ids' => 'required|array|min:1|max:100',
            'reservation_ids.*' => 'integer|exists:reservations,id',
            'status' => 'required|string|in:pending,accepted,in_progress,completed,cancelled',
            'notify_participants' => 'sometimes|boolean',
            'admin_notes' => 'nullable|string|max:1000',
            'cancellation_reason' => 'nullable|string|max:500',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $data = $validator->validated();

        try {
            $result = $this->performBulkStatusUpdate(
                $data['reservation_ids'],
                $data['status'],
                $admin,
                [
                    'notify_participants' => $request->boolean('notify_participants', false),
                    'admin_notes' => $request->input('admin_notes'),
                    'cancellation_reason' => $request->input('cancellation_reason'),
                    'ip' => $request->ip(),
                    'user_agent' => $request->userAgent(),
                ]
            );
        } catch (\RuntimeException $exception) {
            if ($exception->getMessage() === 'RESERVATIONS_NOT_FOUND') {
                return response()->json([
                    'error' => [
                        'code' => 'RESERVATIONS_NOT_FOUND',
                        'message' => 'Seçilen rezervasyonlar bulunamadı',
                    ],
                ], 404);
            }

            throw $exception;
        } catch (\Throwable $throwable) {
            Log::error('Admin bulk status update failed', [
                'error' => $throwable->getMessage(),
                'admin_id' => $admin->id,
                'reservation_ids' => $data['reservation_ids'],
            ]);

            return response()->json([
                'error' => [
                    'code' => 'BULK_STATUS_ERROR',
                    'message' => 'Toplu durum güncellemesi sırasında bir hata oluştu',
                ],
            ], 500);
        }

        return response()->json([
            'success' => true,
            'message' => 'Toplu durum güncellemesi tamamlandı',
            'updated_count' => $result['count'],
            'reservations' => $result['reservations'],
            'undo' => $result['undo'],
        ]);
    }

    /**
     * Bulk cancel reservations.
     */
    public function bulkCancelReservations(Request $request): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'reservation_ids' => 'required|array|min:1|max:100',
            'reservation_ids.*' => 'integer|exists:reservations,id',
            'reason' => 'nullable|string|max:500',
            'notify_participants' => 'sometimes|boolean',
            'admin_notes' => 'nullable|string|max:1000',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $data = $validator->validated();

        try {
            $result = $this->performBulkStatusUpdate(
                $data['reservation_ids'],
                'cancelled',
                $admin,
                [
                    'notify_participants' => $request->boolean('notify_participants', true),
                    'admin_notes' => $request->input('admin_notes'),
                    'cancellation_reason' => $request->input('reason'),
                    'ip' => $request->ip(),
                    'user_agent' => $request->userAgent(),
                ]
            );
        } catch (\RuntimeException $exception) {
            if ($exception->getMessage() === 'RESERVATIONS_NOT_FOUND') {
                return response()->json([
                    'error' => [
                        'code' => 'RESERVATIONS_NOT_FOUND',
                        'message' => 'Seçilen rezervasyonlar bulunamadı',
                    ],
                ], 404);
            }

            throw $exception;
        } catch (\Throwable $throwable) {
            Log::error('Admin bulk cancellation failed', [
                'error' => $throwable->getMessage(),
                'admin_id' => $admin->id,
                'reservation_ids' => $data['reservation_ids'],
            ]);

            return response()->json([
                'error' => [
                    'code' => 'BULK_CANCEL_ERROR',
                    'message' => 'Toplu iptal işlemi sırasında bir hata oluştu',
                ],
            ], 500);
        }

        return response()->json([
            'success' => true,
            'message' => 'Toplu iptal işlemi tamamlandı',
            'updated_count' => $result['count'],
            'reservations' => $result['reservations'],
            'undo' => $result['undo'],
        ]);
    }

    /**
     * Bulk send reservation reminders.
     */
    public function bulkSendReservationReminders(Request $request): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'reservation_ids' => 'required|array|min:1|max:100',
            'reservation_ids.*' => 'integer|exists:reservations,id',
            'notify_student' => 'sometimes|boolean',
            'notify_teacher' => 'sometimes|boolean',
            'send_email' => 'sometimes|boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $data = $validator->validated();
        $reservationIds = array_values(array_unique($data['reservation_ids']));

        $notifyStudent = $request->boolean('notify_student', true);
        $notifyTeacher = $request->boolean('notify_teacher', true);
        $sendEmail = $request->boolean('send_email', true);

        if (!$notifyStudent && !$notifyTeacher && !$sendEmail) {
            return response()->json([
                'error' => [
                    'code' => 'NO_CHANNEL_SELECTED',
                    'message' => 'En az bir bildirim kanalı seçmelisiniz',
                ],
            ], 422);
        }

        try {
            $result = DB::transaction(function () use (
                $reservationIds,
                $notifyStudent,
                $notifyTeacher,
                $sendEmail,
                $admin,
                $request
            ) {
                $reservations = Reservation::with(['student', 'teacher', 'category', 'payments', 'lessons.teacher', 'lessons.student', 'reminderLogs.setting'])
                    ->lockForUpdate()
                    ->whereIn('id', $reservationIds)
                    ->get();

                if ($reservations->isEmpty()) {
                    throw new \RuntimeException('RESERVATIONS_NOT_FOUND');
                }

                $processed = [];
                $channels = [
                    'student_push' => $notifyStudent,
                    'teacher_push' => $notifyTeacher,
                    'email' => $sendEmail,
                ];

                foreach ($reservations as $reservation) {
                    $result = $this->reservationReminderService->sendReminder(
                        $reservation,
                        $channels,
                        'manual'
                    );

                    if (!($result['success'] ?? false)) {
                        continue;
                    }

                    AuditLog::createLog(
                        $admin->id,
                        'reservation_bulk_reminder_sent',
                        Reservation::class,
                        $reservation->id,
                        [
                            'channels' => $result['channels'] ?? array_keys(array_filter($channels)),
                            'reminder_count' => $reservation->reminder_count,
                            'source' => 'manual',
                        ],
                        $request->ip(),
                        $request->userAgent()
                    );

                    $reservation->load(['reminderLogs.setting']);
                    $processed[] = $this->transformReservationForAdmin($reservation);
                }

                return [
                    'processed' => $processed,
                    'processed_ids' => $reservations->pluck('id')->all(),
                ];
            });
        } catch (\RuntimeException $exception) {
            if ($exception->getMessage() === 'RESERVATIONS_NOT_FOUND') {
                return response()->json([
                    'error' => [
                        'code' => 'RESERVATIONS_NOT_FOUND',
                        'message' => 'Seçilen rezervasyonlar bulunamadı',
                    ],
                ], 404);
            }

            throw $exception;
        } catch (\Throwable $throwable) {
            Log::error('Admin bulk reminder failed', [
                'error' => $throwable->getMessage(),
                'admin_id' => $admin->id,
                'reservation_ids' => $reservationIds,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'BULK_REMINDER_ERROR',
                    'message' => 'Hatırlatma gönderilirken bir hata oluştu',
                ],
            ], 500);
        }

        return response()->json([
            'success' => true,
            'message' => 'Hatırlatmalar gönderildi',
            'processed_count' => count($result['processed']),
            'reservations' => $result['processed'],
        ]);
    }

    /**
     * List reservation reminder settings.
     */
    public function listReminderSettings(): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $workflows = $this->getActiveReminderWorkflows(refresh: true)
            ->map(fn (ReservationReminderWorkflow $workflow) => $this->transformReminderWorkflow($workflow))
            ->values();

        $settings = collect($workflows)
            ->flatMap(fn (array $workflow) => $workflow['steps'])
            ->values();

        return response()->json([
            'success' => true,
            'workflows' => $workflows,
            'settings' => $settings,
        ]);
    }

    public function listReminderWorkflows(): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $workflows = ReservationReminderWorkflow::with(['steps' => function ($query) {
            $query->orderBy('step_order');
        }])->orderByDesc('created_at')->get()
            ->map(fn (ReservationReminderWorkflow $workflow) => $this->transformReminderWorkflow($workflow))
            ->values();

        return response()->json([
            'success' => true,
            'workflows' => $workflows,
        ]);
    }

    public function createReminderWorkflow(Request $request): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:150',
            'description' => 'nullable|string|max:500',
            'status' => 'nullable|string|in:draft,active,archived',
            'target_statuses' => 'nullable|array',
            'target_statuses.*' => 'in:pending,accepted,in_progress,completed,cancelled',
            'target_roles' => 'nullable|array',
            'target_roles.*' => 'in:student,teacher',
            'meta' => 'nullable|array',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $data = $validator->validated();
        $slug = Str::slug($data['name']) ?: Str::random(10);

        if (ReservationReminderWorkflow::where('slug', $slug)->exists()) {
            $slug .= '-' . Str::random(4);
        }

        $workflow = ReservationReminderWorkflow::create([
            'name' => $data['name'],
            'slug' => $slug,
            'description' => $data['description'] ?? null,
            'status' => $data['status'] ?? 'active',
            'target_statuses' => $this->sanitizeReminderStatuses($data['target_statuses'] ?? null),
            'target_roles' => $this->sanitizeReminderRoles($data['target_roles'] ?? null),
            'meta' => $data['meta'] ?? [],
            'created_by' => $admin->id,
            'updated_by' => $admin->id,
        ]);

        AuditLog::createLog(
            $admin->id,
            'reservation_reminder_workflow_created',
            ReservationReminderWorkflow::class,
            $workflow->id,
            $workflow->toArray(),
            $request->ip(),
            $request->userAgent()
        );

        $this->clearReminderSettingsCache();

        return response()->json([
            'success' => true,
            'workflow' => $this->transformReminderWorkflow($workflow),
        ], 201);
    }

    public function updateReminderWorkflow(
        Request $request,
        ReservationReminderWorkflow $reminderWorkflow
    ): JsonResponse {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|required|string|max:150',
            'description' => 'sometimes|nullable|string|max:500',
            'status' => 'sometimes|string|in:draft,active,archived',
            'target_statuses' => 'sometimes|array',
            'target_statuses.*' => 'in:pending,accepted,in_progress,completed,cancelled',
            'target_roles' => 'sometimes|array',
            'target_roles.*' => 'in:student,teacher',
            'meta' => 'sometimes|array',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $payload = $validator->validated();

        if (array_key_exists('name', $payload) && $payload['name'] !== $reminderWorkflow->name) {
            $slug = Str::slug($payload['name']) ?: Str::random(10);

            if (ReservationReminderWorkflow::where('slug', $slug)->where('id', '!=', $reminderWorkflow->id)->exists()) {
                $slug .= '-' . Str::random(4);
            }

            $reminderWorkflow->slug = $slug;
            $reminderWorkflow->name = $payload['name'];
        }

        if (array_key_exists('description', $payload)) {
            $reminderWorkflow->description = $payload['description'];
        }

        if (array_key_exists('status', $payload)) {
            $reminderWorkflow->status = $payload['status'];
        }

        if (array_key_exists('target_statuses', $payload)) {
            $reminderWorkflow->target_statuses = $this->sanitizeReminderStatuses($payload['target_statuses']);
        }

        if (array_key_exists('target_roles', $payload)) {
            $reminderWorkflow->target_roles = $this->sanitizeReminderRoles($payload['target_roles']);
        }

        if (array_key_exists('meta', $payload)) {
            $reminderWorkflow->meta = $payload['meta'];
        }

        $reminderWorkflow->updated_by = $admin->id;
        $reminderWorkflow->save();

        AuditLog::createLog(
            $admin->id,
            'reservation_reminder_workflow_updated',
            ReservationReminderWorkflow::class,
            $reminderWorkflow->id,
            $reminderWorkflow->toArray(),
            $request->ip(),
            $request->userAgent()
        );

        $this->clearReminderSettingsCache();

        return response()->json([
            'success' => true,
            'workflow' => $this->transformReminderWorkflow($reminderWorkflow),
        ]);
    }

    public function deleteReminderWorkflow(
        Request $request,
        ReservationReminderWorkflow $reminderWorkflow
    ): JsonResponse {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        if ($reminderWorkflow->slug === Str::slug('Varsayılan Hatırlatma Akışı')) {
            return response()->json([
                'error' => [
                    'code' => 'DEFAULT_WORKFLOW_PROTECTED',
                    'message' => 'Varsayılan hatırlatma akışı silinemez.',
                ],
            ], 422);
        }

        $workflowData = $reminderWorkflow->toArray();
        $reminderWorkflow->delete();

        AuditLog::createLog(
            $admin->id,
            'reservation_reminder_workflow_deleted',
            ReservationReminderWorkflow::class,
            $workflowData['id'] ?? null,
            $workflowData,
            $request->ip(),
            $request->userAgent()
        );

        $this->clearReminderSettingsCache();

        return response()->json([
            'success' => true,
            'message' => 'Hatırlatma akışı silindi',
        ]);
    }

    public function createReminderWorkflowStep(
        Request $request,
        ReservationReminderWorkflow $reminderWorkflow
    ): JsonResponse {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:150',
            'offset_minutes' => 'required|integer|min:0|max:20160',
            'offset_direction' => 'nullable|in:before,after',
            'send_window' => 'nullable|integer|min:1|max:1440',
            'step_order' => 'nullable|integer|min:1',
            'enabled' => 'sometimes|boolean',
            'stop_on_success' => 'sometimes|boolean',
            'channels' => 'nullable|array',
            'channels.student.push.enabled' => 'sometimes|boolean',
            'channels.student.push.template_id' => 'nullable|integer|exists:notification_templates,id',
            'channels.student.email.enabled' => 'sometimes|boolean',
            'channels.student.email.template_id' => 'nullable|integer|exists:notification_templates,id',
            'channels.student.sms.enabled' => 'sometimes|boolean',
            'channels.student.sms.template_id' => 'nullable|integer|exists:notification_templates,id',
            'channels.teacher.push.enabled' => 'sometimes|boolean',
            'channels.teacher.push.template_id' => 'nullable|integer|exists:notification_templates,id',
            'channels.teacher.email.enabled' => 'sometimes|boolean',
            'channels.teacher.email.template_id' => 'nullable|integer|exists:notification_templates,id',
            'channels.teacher.sms.enabled' => 'sometimes|boolean',
            'channels.teacher.sms.template_id' => 'nullable|integer|exists:notification_templates,id',
            'metadata' => 'nullable|array',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $data = $validator->validated();
        $channels = $this->sanitizeReminderChannelPayload($data['channels'] ?? null);
        $flags = $this->deriveReminderChannelFlags($channels);

        $nextOrder = array_key_exists('step_order', $data)
            ? (int) $data['step_order']
            : (($reminderWorkflow->steps()->max('step_order') ?? 0) + 1);

        $step = ReservationReminderSetting::create([
            'workflow_id' => $reminderWorkflow->id,
            'step_order' => $nextOrder,
            'name' => $data['name'],
            'offset_minutes' => $data['offset_minutes'],
            'offset_direction' => $data['offset_direction'] ?? 'before',
            'send_window' => $data['send_window'] ?? 10,
            'enabled' => $data['enabled'] ?? true,
            'stop_on_success' => $data['stop_on_success'] ?? true,
            'notify_student' => $flags['notify_student'],
            'notify_teacher' => $flags['notify_teacher'],
            'send_email' => $flags['send_email'],
            'channels' => $channels,
            'metadata' => $data['metadata'] ?? [],
        ]);

        AuditLog::createLog(
            $admin->id,
            'reservation_reminder_step_created',
            ReservationReminderSetting::class,
            $step->id,
            $step->toArray(),
            $request->ip(),
            $request->userAgent()
        );

        $this->clearReminderSettingsCache();

        return response()->json([
            'success' => true,
            'step' => $this->transformReminderSetting($step),
        ], 201);
    }

    public function updateReminderWorkflowStep(
        Request $request,
        ReservationReminderWorkflow $reminderWorkflow,
        ReservationReminderSetting $reminderSetting
    ): JsonResponse {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        if ($reminderSetting->workflow_id !== $reminderWorkflow->id) {
            return response()->json([
                'error' => [
                    'code' => 'STEP_NOT_IN_WORKFLOW',
                    'message' => 'Adım belirtilen hatırlatma akışına ait değil',
                ],
            ], 404);
        }

        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|required|string|max:150',
            'offset_minutes' => 'sometimes|required|integer|min:0|max:20160',
            'offset_direction' => 'sometimes|in:before,after',
            'send_window' => 'sometimes|integer|min:1|max:1440',
            'step_order' => 'sometimes|integer|min:1',
            'enabled' => 'sometimes|boolean',
            'stop_on_success' => 'sometimes|boolean',
            'channels' => 'sometimes|array',
            'channels.student.push.enabled' => 'sometimes|boolean',
            'channels.student.push.template_id' => 'nullable|integer|exists:notification_templates,id',
            'channels.student.email.enabled' => 'sometimes|boolean',
            'channels.student.email.template_id' => 'nullable|integer|exists:notification_templates,id',
            'channels.student.sms.enabled' => 'sometimes|boolean',
            'channels.student.sms.template_id' => 'nullable|integer|exists:notification_templates,id',
            'channels.teacher.push.enabled' => 'sometimes|boolean',
            'channels.teacher.push.template_id' => 'nullable|integer|exists:notification_templates,id',
            'channels.teacher.email.enabled' => 'sometimes|boolean',
            'channels.teacher.email.template_id' => 'nullable|integer|exists:notification_templates,id',
            'channels.teacher.sms.enabled' => 'sometimes|boolean',
            'channels.teacher.sms.template_id' => 'nullable|integer|exists:notification_templates,id',
            'metadata' => 'sometimes|array',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $payload = $validator->validated();

        if (array_key_exists('name', $payload)) {
            $reminderSetting->name = $payload['name'];
        }

        if (array_key_exists('offset_minutes', $payload)) {
            $reminderSetting->offset_minutes = (int) $payload['offset_minutes'];
        }

        if (array_key_exists('offset_direction', $payload)) {
            $reminderSetting->offset_direction = $payload['offset_direction'];
        }

        if (array_key_exists('send_window', $payload)) {
            $reminderSetting->send_window = (int) $payload['send_window'];
        }

        if (array_key_exists('step_order', $payload)) {
            $reminderSetting->step_order = (int) $payload['step_order'];
        }

        if (array_key_exists('enabled', $payload)) {
            $reminderSetting->enabled = (bool) $payload['enabled'];
        }

        if (array_key_exists('stop_on_success', $payload)) {
            $reminderSetting->stop_on_success = (bool) $payload['stop_on_success'];
        }

        if (array_key_exists('channels', $payload)) {
            $channels = $this->sanitizeReminderChannelPayload($payload['channels'], $reminderSetting->channel_config);
            $flags = $this->deriveReminderChannelFlags($channels);

            $reminderSetting->channels = $channels;
            $reminderSetting->notify_student = $flags['notify_student'];
            $reminderSetting->notify_teacher = $flags['notify_teacher'];
            $reminderSetting->send_email = $flags['send_email'];
        }

        if (array_key_exists('metadata', $payload)) {
            $reminderSetting->metadata = $payload['metadata'];
        }

        $reminderSetting->save();

        AuditLog::createLog(
            $admin->id,
            'reservation_reminder_step_updated',
            ReservationReminderSetting::class,
            $reminderSetting->id,
            $reminderSetting->toArray(),
            $request->ip(),
            $request->userAgent()
        );

        $this->clearReminderSettingsCache();

        return response()->json([
            'success' => true,
            'step' => $this->transformReminderSetting($reminderSetting),
        ]);
    }

    public function deleteReminderWorkflowStep(
        Request $request,
        ReservationReminderWorkflow $reminderWorkflow,
        ReservationReminderSetting $reminderSetting
    ): JsonResponse {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        if ($reminderSetting->workflow_id !== $reminderWorkflow->id) {
            return response()->json([
                'error' => [
                    'code' => 'STEP_NOT_IN_WORKFLOW',
                    'message' => 'Adım belirtilen hatırlatma akışına ait değil',
                ],
            ], 404);
        }

        $stepData = $reminderSetting->toArray();
        $reminderSetting->delete();

        AuditLog::createLog(
            $admin->id,
            'reservation_reminder_step_deleted',
            ReservationReminderSetting::class,
            $stepData['id'] ?? null,
            $stepData,
            $request->ip(),
            $request->userAgent()
        );

        $this->clearReminderSettingsCache();

        return response()->json([
            'success' => true,
            'message' => 'Hatırlatma adımı silindi',
        ]);
    }

    public function reorderReminderWorkflowSteps(
        Request $request,
        ReservationReminderWorkflow $reminderWorkflow
    ): JsonResponse {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'order' => 'required|array|min:1',
            'order.*' => 'integer',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $order = $validator->validated()['order'];
        $steps = $reminderWorkflow->steps()->whereIn('id', $order)->get()->keyBy('id');

        DB::transaction(function () use ($order, $steps) {
            foreach ($order as $index => $stepId) {
                if (!$steps->has($stepId)) {
                    continue;
                }

                /** @var ReservationReminderSetting $step */
                $step = $steps->get($stepId);
                $step->step_order = $index + 1;
                $step->save();
            }
        });

        $this->clearReminderSettingsCache();

        return response()->json([
            'success' => true,
            'workflow' => $this->transformReminderWorkflow($reminderWorkflow->fresh('steps')),
        ]);
    }

    /**
     * Create a new reservation reminder setting.
     */
    public function createReminderSetting(Request $request): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:150',
            'offset_minutes' => 'required|integer|min:5|max:20160', // up to 14 days
            'enabled' => 'sometimes|boolean',
            'notify_student' => 'sometimes|boolean',
            'notify_teacher' => 'sometimes|boolean',
            'send_email' => 'sometimes|boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $workflow = $this->getOrCreateDefaultReminderWorkflow($admin);
        $nextOrder = ($workflow->steps()->max('step_order') ?? 0) + 1;

        $notifyStudent = $request->boolean('notify_student', true);
        $notifyTeacher = $request->boolean('notify_teacher', true);
        $sendEmail = $request->boolean('send_email', false);

        $setting = ReservationReminderSetting::create([
            'workflow_id' => $workflow->id,
            'step_order' => $nextOrder,
            'name' => $request->input('name'),
            'offset_minutes' => $request->integer('offset_minutes'),
            'offset_direction' => 'before',
            'send_window' => 10,
            'enabled' => $request->boolean('enabled', true),
            'stop_on_success' => true,
            'notify_student' => $notifyStudent,
            'notify_teacher' => $notifyTeacher,
            'send_email' => $sendEmail,
            'channels' => $this->serializeBasicReminderChannels($notifyStudent, $notifyTeacher, $sendEmail),
        ]);

        AuditLog::createLog(
            $admin->id,
            'reservation_reminder_setting_created',
            ReservationReminderSetting::class,
            $setting->id,
            $setting->toArray(),
            $request->ip(),
            $request->userAgent()
        );

        $this->clearReminderSettingsCache();

        return response()->json([
            'success' => true,
            'setting' => $this->transformReminderSetting($setting),
        ], 201);
    }

    /**
     * Update an existing reservation reminder setting.
     */
    public function updateReminderSetting(
        Request $request,
        ReservationReminderSetting $reminderSetting
    ): JsonResponse {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|required|string|max:150',
            'offset_minutes' => 'sometimes|required|integer|min:5|max:20160',
            'enabled' => 'sometimes|boolean',
            'notify_student' => 'sometimes|boolean',
            'notify_teacher' => 'sometimes|boolean',
            'send_email' => 'sometimes|boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $payload = $validator->validated();

        if (array_key_exists('name', $payload)) {
            $reminderSetting->name = $payload['name'];
        }

        if (array_key_exists('offset_minutes', $payload)) {
            $reminderSetting->offset_minutes = (int) $payload['offset_minutes'];
        }

        if (array_key_exists('enabled', $payload)) {
            $reminderSetting->enabled = (bool) $payload['enabled'];
        }

        $notifyStudent = array_key_exists('notify_student', $payload)
            ? (bool) $payload['notify_student']
            : $reminderSetting->notify_student;

        $notifyTeacher = array_key_exists('notify_teacher', $payload)
            ? (bool) $payload['notify_teacher']
            : $reminderSetting->notify_teacher;

        $sendEmail = array_key_exists('send_email', $payload)
            ? (bool) $payload['send_email']
            : $reminderSetting->send_email;

        $reminderSetting->notify_student = $notifyStudent;
        $reminderSetting->notify_teacher = $notifyTeacher;
        $reminderSetting->send_email = $sendEmail;
        $reminderSetting->channels = $this->serializeBasicReminderChannels($notifyStudent, $notifyTeacher, $sendEmail);

        $reminderSetting->save();

        AuditLog::createLog(
            $admin->id,
            'reservation_reminder_setting_updated',
            ReservationReminderSetting::class,
            $reminderSetting->id,
            $reminderSetting->toArray(),
            $request->ip(),
            $request->userAgent()
        );

        $this->clearReminderSettingsCache();

        return response()->json([
            'success' => true,
            'setting' => $this->transformReminderSetting($reminderSetting),
        ]);
    }

    /**
     * Delete a reservation reminder setting.
     */
    public function deleteReminderSetting(Request $request, ReservationReminderSetting $reminderSetting): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $settingData = $reminderSetting->toArray();
        $reminderSetting->delete();

        AuditLog::createLog(
            $admin->id,
            'reservation_reminder_setting_deleted',
            ReservationReminderSetting::class,
            $settingData['id'],
            $settingData,
            $request->ip(),
            $request->userAgent()
        );

        $this->clearReminderSettingsCache();

        return response()->json([
            'success' => true,
            'message' => 'Hatırlatma ayarı silindi',
        ]);
    }

    /**
     * Undo a previous bulk reservation action.
     */
    public function bulkUndoReservationActions(Request $request): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'items' => 'required|array|min:1|max:100',
            'items.*.reservation_id' => 'required|integer|exists:reservations,id',
            'items.*.previous_status' => 'required|string|in:pending,accepted,in_progress,completed,cancelled',
            'items.*.previous_cancelled_reason' => 'nullable|string|max:500',
            'items.*.previous_cancelled_at' => 'nullable|date',
            'items.*.previous_cancelled_by_id' => 'nullable|integer',
            'items.*.previous_admin_notes' => 'nullable|string|max:1000',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $data = $validator->validated();
        $items = $data['items'];

        $reservationIds = array_values(array_unique(array_column($items, 'reservation_id')));
        $payload = [];

        foreach ($items as $item) {
            $payload[$item['reservation_id']] = $item;
        }

        try {
            $result = DB::transaction(function () use ($reservationIds, $payload, $admin, $request) {
                $reservations = Reservation::with(['student', 'teacher', 'category', 'payments', 'lessons.teacher', 'lessons.student', 'reminderLogs.setting'])
                    ->lockForUpdate()
                    ->whereIn('id', $reservationIds)
                    ->get();

                if ($reservations->isEmpty()) {
                    throw new \RuntimeException('RESERVATIONS_NOT_FOUND');
                }

                $restored = [];
                $foundIds = [];

                foreach ($reservations as $reservation) {
                    $data = $payload[$reservation->id] ?? null;

                    if (!$data) {
                        continue;
                    }

                    $foundIds[] = $reservation->id;

                    $currentStatus = $reservation->status;

                    $reservation->status = $data['previous_status'];

                    if (Schema::hasColumn('reservations', 'admin_notes')) {
                        $reservation->admin_notes = $data['previous_admin_notes'] ?? null;
                    }

                    if ($data['previous_status'] === 'cancelled') {
                        $reservation->cancelled_reason = $data['previous_cancelled_reason'] ?? null;
                        $reservation->cancelled_by_id = $data['previous_cancelled_by_id'] ?? null;
                        $reservation->cancelled_at = !empty($data['previous_cancelled_at'])
                            ? Carbon::parse($data['previous_cancelled_at'])
                            : null;
                    } else {
                        $reservation->cancelled_reason = null;
                        $reservation->cancelled_by_id = null;
                        $reservation->cancelled_at = null;
                    }

                    $reservation->save();
                    $reservation->load(['student', 'teacher', 'category', 'payments']);

                    AuditLog::createLog(
                        $admin->id,
                        'reservation_bulk_action_undone',
                        Reservation::class,
                        $reservation->id,
                        [
                            'restored_to' => $reservation->status,
                            'previous_status' => $currentStatus,
                        ],
                        $request->ip(),
                        $request->userAgent()
                    );

                    $restored[] = $this->transformReservationForAdmin($reservation);
                }

                $missing = array_values(array_diff($reservationIds, $foundIds));

                return [
                    'restored' => $restored,
                    'missing' => $missing,
                ];
            });
        } catch (\RuntimeException $exception) {
            if ($exception->getMessage() === 'RESERVATIONS_NOT_FOUND') {
                return response()->json([
                    'error' => [
                        'code' => 'RESERVATIONS_NOT_FOUND',
                        'message' => 'Seçilen rezervasyonlar bulunamadı',
                    ],
                ], 404);
            }

            throw $exception;
        } catch (\Throwable $throwable) {
            Log::error('Admin bulk undo failed', [
                'error' => $throwable->getMessage(),
                'admin_id' => $admin->id,
                'reservation_ids' => $reservationIds,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'BULK_UNDO_ERROR',
                    'message' => 'Geri alma işlemi sırasında bir hata oluştu',
                ],
            ], 500);
        }

        if (empty($result['restored'])) {
            return response()->json([
                'error' => [
                    'code' => 'NO_RESERVATIONS_RESTORED',
                    'message' => 'Geri alınacak rezervasyon bulunamadı',
                ],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Toplu işlem geri alındı',
            'restored_count' => count($result['restored']),
            'reservations' => $result['restored'],
            'missing' => $result['missing'],
        ]);
    }

    /**
     * @OA\Post(
     *     path="/admin/notifications/send",
     *     tags={"Admin"},
     *     summary="Toplu bildirim gönder",
     *     description="Admin paneli için toplu bildirim gönderir",
     *     security={{"bearerAuth":{}}},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             @OA\Property(property="title", type="string"),
     *             @OA\Property(property="message", type="string"),
     *             @OA\Property(property="target_users", type="array", @OA\Items(type="string", enum={"all", "students", "teachers"})),
     *             @OA\Property(property="type", type="string", enum={"info", "warning", "success", "error"})
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Bildirim başarıyla gönderildi"
     *     )
     * )
     */
    public function sendNotification(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'title' => 'required|string|max:255',
            'message' => 'required|string|max:1000',
            'target_users' => 'required|array',
            'target_users.*' => 'in:all,students,teachers',
            'type' => 'required|in:info,warning,success,error',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $targetUsers = $request->target_users;
        $userQuery = User::query();

        if (!in_array('all', $targetUsers)) {
            $userQuery->whereIn('role', $targetUsers);
        }

        $users = $userQuery->get();

        $notifications = [];
        foreach ($users as $user) {
            $notifications[] = [
                'user_id' => $user->id,
                'title' => $request->title,
                'message' => $request->message,
                'type' => $request->type,
                'data' => json_encode(['admin_notification' => true]),
                'created_at' => now(),
                'updated_at' => now(),
            ];
        }

        \DB::table('notifications')->insert($notifications);

        // Audit log
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'bulk_notification_sent',
            'target_type' => 'notification',
            'target_id' => null,
            'details' => [
                'title' => $request->title,
                'target_users' => $targetUsers,
                'user_count' => count($users),
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Bildirim başarıyla gönderildi',
            'sent_count' => count($users),
        ]);
    }

    /**
     * Get real-time analytics
     */
    public function getRealTimeAnalytics(): JsonResponse
    {
        try {
            $realTimeStats = $this->analyticsService->getRealTimeStats();
            
            return response()->json([
                'success' => true,
                'analytics' => $realTimeStats,
                'timestamp' => now()->toISOString(),
            ]);
        } catch (\Exception $e) {
            \Log::error('Real-time analytics error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => 'Real-time analytics yüklenirken hata oluştu',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Clear analytics cache
     */
    public function clearAnalyticsCache(): JsonResponse
    {
        try {
            $this->analyticsService->clearCache();
            
            return response()->json([
                'success' => true,
                'message' => 'Analytics cache temizlendi',
            ]);
        } catch (\Exception $e) {
            \Log::error('Clear analytics cache error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => 'Cache temizlenirken hata oluştu',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Send bulk notification
     */
    public function sendBulkNotification(Request $request): JsonResponse
    {
        try {
            $result = $this->adminNotificationService->sendBulkNotification($request->all());
            
            return response()->json([
                'success' => true,
                'message' => 'Toplu bildirim başarıyla gönderildi',
                'result' => $result,
            ]);
        } catch (\Exception $e) {
            \Log::error('Bulk notification error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => 'Toplu bildirim gönderilirken hata oluştu',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get notification history
     */
    public function getNotifications(Request $request): JsonResponse
    {
        try {
            $query = Notification::with('user')->orderByDesc('created_at');

            if ($request->filled('type')) {
                $query->where('type', $request->get('type'));
            }

            if ($request->filled('status')) {
                if ($request->get('status') === 'read') {
                    $query->where('is_read', true);
                } elseif ($request->get('status') === 'unread') {
                    $query->where('is_read', false);
                }
            }

            if ($request->filled('search')) {
                $search = $request->get('search');
                $query->where(function ($q) use ($search) {
                    $q->where('title', 'like', "%{$search}%")
                        ->orWhere('message', 'like', "%{$search}%")
                        ->orWhereHas('user', function ($userQuery) use ($search) {
                            $userQuery->where('name', 'like', "%{$search}%")
                                ->orWhere('email', 'like', "%{$search}%");
                        });
                });
            }

            $notifications = $query->paginate($request->get('per_page', 20));

            return response()->json([
                'success' => true,
                'notifications' => $notifications->items(),
                'pagination' => [
                    'current_page' => $notifications->currentPage(),
                    'last_page' => $notifications->lastPage(),
                    'per_page' => $notifications->perPage(),
                    'total' => $notifications->total(),
                ],
            ]);
        } catch (\Exception $e) {
            \Log::error('Notifications history error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => 'Bildirim geçmişi alınırken hata oluştu',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Send notification to a specific user
     */
    public function sendUserNotification(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'user_id' => 'required|exists:users,id',
            'title' => 'required|string|max:255',
            'message' => 'required|string|max:1000',
            'type' => 'required|in:info,warning,success,error',
            'priority' => 'nullable|in:low,normal,high,urgent',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 400);
        }

        try {
            $result = $this->adminNotificationService->sendUserNotification(
                (int) $request->user_id,
                [
                    'title' => $request->title,
                    'message' => $request->message,
                    'type' => $request->type,
                    'priority' => $request->priority ?? 'normal',
                ],
            );

            if (!$result) {
                return response()->json([
                    'success' => false,
                    'message' => 'Bildirim gönderilemedi',
                ], 500);
            }

            return response()->json([
                'success' => true,
                'message' => 'Bildirim başarıyla gönderildi',
            ]);
        } catch (\Exception $e) {
            \Log::error('User notification error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => 'Bildirim gönderilirken hata oluştu',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * List scheduled notifications.
     */
    public function listScheduledNotifications(Request $request): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $filters = $request->only(['status', 'target_type', 'from', 'to']);
        $notifications = $this->scheduledNotificationService->list($filters);

        return response()->json([
            'success' => true,
            'notifications' => $notifications
                ->map(fn (ScheduledNotification $notification) => $this->transformScheduledNotification($notification))
                ->all(),
        ]);
    }

    /**
     * Create a scheduled notification (draft or scheduled).
     */
    public function createScheduledNotification(Request $request): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'title' => 'required_without:template_id|string|max:255',
            'message' => 'required_without:template_id|string|max:2000',
            'type' => 'required|in:info,warning,success,error',
            'priority' => 'nullable|in:low,normal,high,urgent',
            'target_type' => 'nullable|in:all,students,teachers,admins',
            'channels' => 'nullable|array',
            'channels.push' => 'boolean',
            'channels.email' => 'boolean',
            'channels.in_app' => 'boolean',
            'template_id' => 'nullable|exists:notification_templates,id',
            'scheduled_at' => 'nullable|date',
            'timezone' => 'nullable|string|max:64',
            'status' => 'nullable|in:draft,scheduled',
            'meta' => 'nullable|array',
            'meta.placeholders' => 'nullable|array',
            'meta.placeholders.*' => 'string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        try {
            $channels = $this->normalizeNotificationChannels($request->input('channels', []));

            $data = $validator->validated();
            $data['channels'] = $channels;
            $data['template_id'] = $request->input('template_id');

            if (!array_key_exists('meta', $data)) {
                $data['meta'] = null;
            }

            if (!array_key_exists('message', $data) || empty($data['message'])) {
                if (!empty($data['template_id'])) {
                    $template = NotificationTemplate::find($data['template_id']);
                    if ($template) {
                        $placeholders = is_array($data['meta']) ? ($data['meta']['placeholders'] ?? []) : [];
                        $data['message'] = $this->notificationTemplateService->render($template, $placeholders);
                        if (empty($data['title']) && !empty($template->subject)) {
                            $data['title'] = $template->subject;
                        }
                    }
                }
            }

            if (!array_key_exists('message', $data) || empty($data['message'])) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => ['message' => ['Şablon içeriğinden mesaj oluşturulamadı.']],
                    ],
                ], 422);
            }

            $notification = $this->scheduledNotificationService->create($data);

            return response()->json([
                'success' => true,
                'notification' => $this->transformScheduledNotification($notification),
            ], 201);
        } catch (\Throwable $throwable) {
            Log::error('Scheduled notification create failed', [
                'error' => $throwable->getMessage(),
            ]);

            return response()->json([
                'error' => [
                    'code' => 'SCHEDULE_CREATE_ERROR',
                    'message' => 'Bildirim oluşturulurken bir hata oluştu',
                ],
            ], 500);
        }
    }

    /**
     * Update scheduled notification.
     */
    public function updateScheduledNotification(
        Request $request,
        ScheduledNotification $scheduledNotification
    ): JsonResponse {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'title' => 'sometimes|required_without:template_id|string|max:255',
            'message' => 'sometimes|required_without:template_id|string|max:2000',
            'type' => 'sometimes|required|in:info,warning,success,error',
            'priority' => 'sometimes|in:low,normal,high,urgent',
            'target_type' => 'sometimes|in:all,students,teachers,admins',
            'channels' => 'sometimes|array',
            'channels.push' => 'boolean',
            'channels.email' => 'boolean',
            'channels.in_app' => 'boolean',
            'template_id' => 'sometimes|nullable|exists:notification_templates,id',
            'scheduled_at' => 'sometimes|nullable|date',
            'timezone' => 'sometimes|nullable|string|max:64',
            'status' => 'sometimes|in:draft,scheduled,queued,cancelled',
            'meta' => 'sometimes|nullable|array',
            'meta.placeholders' => 'sometimes|nullable|array',
            'meta.placeholders.*' => 'string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        try {
            $data = $validator->validated();

            if (array_key_exists('channels', $data)) {
                $data['channels'] = $this->normalizeNotificationChannels($data['channels'] ?? []);
            }

            if (array_key_exists('template_id', $data) && $data['template_id'] === null) {
                $data['template_id'] = null;
            }

            if (
                (!array_key_exists('message', $data) || empty($data['message'])) &&
                (!empty($data['template_id']) || $scheduledNotification->template_id)
            ) {
                $templateId = $data['template_id'] ?? $scheduledNotification->template_id;
                $template = $templateId ? NotificationTemplate::find($templateId) : null;
                if ($template) {
                    $meta = $data['meta'] ?? $scheduledNotification->meta ?? [];
                    $placeholders = is_array($meta) ? ($meta['placeholders'] ?? []) : [];
                    $data['message'] = $this->notificationTemplateService->render($template, $placeholders);
                    if (empty($data['title']) && !empty($template->subject)) {
                        $data['title'] = $template->subject;
                    }
                }
            }

            if (array_key_exists('template_id', $data) && empty($data['template_id'])) {
                $data['template_id'] = null;
            }

            $notification = $this->scheduledNotificationService->update($scheduledNotification, $data);

            return response()->json([
                'success' => true,
                'notification' => $this->transformScheduledNotification($notification),
            ]);
        } catch (\Throwable $throwable) {
            Log::error('Scheduled notification update failed', [
                'scheduled_notification_id' => $scheduledNotification->id,
                'error' => $throwable->getMessage(),
            ]);

            return response()->json([
                'error' => [
                    'code' => 'SCHEDULE_UPDATE_ERROR',
                    'message' => $throwable->getMessage(),
                ],
            ], 500);
        }
    }

    /**
     * Schedule draft notification.
     */
    public function scheduleScheduledNotification(
        Request $request,
        ScheduledNotification $scheduledNotification
    ): JsonResponse {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'scheduled_at' => 'required|date|after:now',
            'timezone' => 'nullable|string|max:64',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        try {
            $data = $validator->validated();
            $scheduledAt = Carbon::parse($data['scheduled_at'], $data['timezone'] ?? null)->setTimezone('UTC');

            $notification = $this->scheduledNotificationService->schedule(
                $scheduledNotification,
                $scheduledAt,
                $data['timezone'] ?? null
            );

            return response()->json([
                'success' => true,
                'notification' => $this->transformScheduledNotification($notification),
            ]);
        } catch (\Throwable $throwable) {
            Log::error('Scheduled notification schedule failed', [
                'scheduled_notification_id' => $scheduledNotification->id,
                'error' => $throwable->getMessage(),
            ]);

            return response()->json([
                'error' => [
                    'code' => 'SCHEDULE_SET_ERROR',
                    'message' => $throwable->getMessage(),
                ],
            ], 500);
        }
    }

    /**
     * Send scheduled notification immediately.
     */
    public function sendScheduledNotificationNow(
        ScheduledNotification $scheduledNotification
    ): JsonResponse {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        try {
            $this->scheduledNotificationService->sendNow($scheduledNotification);

            return response()->json([
                'success' => true,
                'notification' => $this->transformScheduledNotification($scheduledNotification->fresh()),
            ]);
        } catch (\Throwable $throwable) {
            Log::error('Scheduled notification send-now failed', [
                'scheduled_notification_id' => $scheduledNotification->id,
                'error' => $throwable->getMessage(),
            ]);

            return response()->json([
                'error' => [
                    'code' => 'SCHEDULE_SEND_ERROR',
                    'message' => $throwable->getMessage(),
                ],
            ], 500);
        }
    }

    /**
     * Cancel scheduled notification.
     */
    public function cancelScheduledNotification(
        ScheduledNotification $scheduledNotification
    ): JsonResponse {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        try {
            $notification = $this->scheduledNotificationService->cancel($scheduledNotification);

            return response()->json([
                'success' => true,
                'notification' => $this->transformScheduledNotification($notification),
            ]);
        } catch (\Throwable $throwable) {
            Log::error('Scheduled notification cancel failed', [
                'scheduled_notification_id' => $scheduledNotification->id,
                'error' => $throwable->getMessage(),
            ]);

            return response()->json([
                'error' => [
                    'code' => 'SCHEDULE_CANCEL_ERROR',
                    'message' => $throwable->getMessage(),
                ],
            ], 500);
        }
    }

    /**
     * Get scheduled notification logs.
     */
    public function getScheduledNotificationLogs(
        ScheduledNotification $scheduledNotification
    ): JsonResponse {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $logs = $scheduledNotification->logs()
            ->orderByDesc('created_at')
            ->limit(50)
            ->get();

        return response()->json([
            'success' => true,
            'logs' => $logs->map(fn (ScheduledNotificationLog $log) => [
                'id' => $log->id,
                'status' => $log->status,
                'sent_count' => $log->sent_count,
                'fail_count' => $log->fail_count,
                'started_at' => $log->started_at?->toIso8601String(),
                'finished_at' => $log->finished_at?->toIso8601String(),
                'error_message' => $log->error_message,
                'meta' => $log->meta,
                'created_at' => $log->created_at?->toIso8601String(),
            ]),
        ]);
    }

    /**
     * List notification templates.
     */
    public function listNotificationTemplates(Request $request): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $filters = $request->only(['channel', 'status', 'search']);
        $templates = $this->notificationTemplateService->list($filters);

        return response()->json([
            'success' => true,
            'templates' => $templates->map(fn (NotificationTemplate $template) => $this->transformNotificationTemplate($template))->all(),
        ]);
    }

    public function getNotificationTemplate(NotificationTemplate $notificationTemplate): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        return response()->json([
            'success' => true,
            'template' => $this->transformNotificationTemplate($notificationTemplate),
        ]);
    }

    public function getNotificationTemplateVariables(Request $request): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $catalog = $this->notificationTemplateService->getVariableCatalog();

        return response()->json([
            'success' => true,
            'groups' => $catalog,
        ]);
    }

    public function getNotificationIntegrationStatus(Request $request): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $emailDetails = [
            'driver' => config('mail.default'),
            'host' => config('mail.mailers.smtp.host'),
            'port' => config('mail.mailers.smtp.port'),
            'username' => config('mail.mailers.smtp.username'),
            'encryption' => config('mail.mailers.smtp.encryption'),
            'from_address' => config('mail.from.address'),
            'from_name' => config('mail.from.name'),
            'password_set' => !empty(config('mail.mailers.smtp.password')),
        ];

        $emailMissing = [];
        foreach (['driver', 'host', 'port', 'username', 'encryption', 'from_address', 'from_name'] as $field) {
            if (empty($emailDetails[$field])) {
                $emailMissing[] = $field;
            }
        }
        if (!$emailDetails['password_set']) {
            $emailMissing[] = 'password';
        }

        $pushStatus = $this->pushNotificationService->getStatus();
        $smsStatus = $this->smsService->getStatus();

        return response()->json([
            'success' => true,
            'email' => [
                'configured' => $this->mailService->isMailConfigured(),
                'details' => $emailDetails,
                'missing' => array_values(array_unique($emailMissing)),
            ],
            'push' => $pushStatus,
            'sms' => $smsStatus,
            'supported_sms_providers' => ['twilio', 'mock'],
        ]);
    }

    public function updateNotificationIntegrations(Request $request): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'email' => 'nullable|array',
            'email.driver' => 'nullable|string|max:64',
            'email.host' => 'nullable|string|max:191',
            'email.port' => 'nullable|string|max:10',
            'email.username' => 'nullable|string|max:191',
            'email.password' => 'nullable|string|max:191',
            'email.encryption' => 'nullable|string|max:10',
            'email.from_address' => 'nullable|string|max:191',
            'email.from_name' => 'nullable|string|max:191',
            'push' => 'nullable|array',
            'push.server_key' => 'nullable|string',
            'push.sender_id' => 'nullable|string|max:191',
            'sms' => 'nullable|array',
            'sms.provider' => 'nullable|string|in:twilio,mock',
            'sms.twilio_account_sid' => 'nullable|string|max:191',
            'sms.twilio_auth_token' => 'nullable|string|max:191',
            'sms.twilio_from' => 'nullable|string|max:50',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $payload = $validator->validated();
        $envUpdates = [];
        $updatedSections = [];

        if (!empty($payload['email']) && is_array($payload['email'])) {
            $email = $payload['email'];
            $updatedSections[] = 'email';

            if (array_key_exists('driver', $email) && $email['driver'] !== null) {
                $envUpdates['MAIL_MAILER'] = $email['driver'];
                config()->set('mail.default', $email['driver']);
            }
            if (array_key_exists('host', $email) && $email['host'] !== null) {
                $envUpdates['MAIL_HOST'] = $email['host'];
                config()->set('mail.mailers.smtp.host', $email['host']);
            }
            if (array_key_exists('port', $email) && $email['port'] !== null) {
                $envUpdates['MAIL_PORT'] = $email['port'];
                config()->set('mail.mailers.smtp.port', $email['port']);
            }
            if (array_key_exists('username', $email) && $email['username'] !== null) {
                $envUpdates['MAIL_USERNAME'] = $email['username'];
                config()->set('mail.mailers.smtp.username', $email['username']);
            }
            if (array_key_exists('password', $email) && $email['password'] !== null) {
                $envUpdates['MAIL_PASSWORD'] = $email['password'];
                config()->set('mail.mailers.smtp.password', $email['password']);
            }
            if (array_key_exists('encryption', $email) && $email['encryption'] !== null) {
                $envUpdates['MAIL_ENCRYPTION'] = $email['encryption'];
                config()->set('mail.mailers.smtp.encryption', $email['encryption']);
            }
            if (array_key_exists('from_address', $email) && $email['from_address'] !== null) {
                $envUpdates['MAIL_FROM_ADDRESS'] = $email['from_address'];
                config()->set('mail.from.address', $email['from_address']);
            }
            if (array_key_exists('from_name', $email) && $email['from_name'] !== null) {
                $envUpdates['MAIL_FROM_NAME'] = $email['from_name'];
                config()->set('mail.from.name', $email['from_name']);
            }
        }

        if (!empty($payload['push']) && is_array($payload['push'])) {
            $push = $payload['push'];
            $updatedSections[] = 'push';

            if (array_key_exists('server_key', $push) && $push['server_key'] !== null) {
                $envUpdates['FCM_SERVER_KEY'] = $push['server_key'];
                config()->set('services.fcm.server_key', $push['server_key']);
            }
            if (array_key_exists('sender_id', $push) && $push['sender_id'] !== null) {
                $envUpdates['FCM_SENDER_ID'] = $push['sender_id'];
                config()->set('services.fcm.sender_id', $push['sender_id']);
            }
        }

        if (!empty($payload['sms']) && is_array($payload['sms'])) {
            $sms = $payload['sms'];
            $updatedSections[] = 'sms';

            if (array_key_exists('provider', $sms) && $sms['provider'] !== null) {
                $envUpdates['SMS_PROVIDER'] = $sms['provider'];
                config()->set('services.sms.provider', $sms['provider']);
            }
            if (array_key_exists('twilio_account_sid', $sms) && $sms['twilio_account_sid'] !== null) {
                $envUpdates['SMS_TWILIO_ACCOUNT_SID'] = $sms['twilio_account_sid'];
                config()->set('services.sms.twilio.account_sid', $sms['twilio_account_sid']);
            }
            if (array_key_exists('twilio_auth_token', $sms) && $sms['twilio_auth_token'] !== null) {
                $envUpdates['SMS_TWILIO_AUTH_TOKEN'] = $sms['twilio_auth_token'];
                config()->set('services.sms.twilio.auth_token', $sms['twilio_auth_token']);
            }
            if (array_key_exists('twilio_from', $sms) && $sms['twilio_from'] !== null) {
                $envUpdates['SMS_TWILIO_FROM'] = $sms['twilio_from'];
                config()->set('services.sms.twilio.from', $sms['twilio_from']);
            }
        }

        if (!empty($envUpdates)) {
            $this->environmentService->update($envUpdates);
        }

        if (!empty($updatedSections)) {
            AuditLog::create([
                'user_id' => $admin->id,
                'action' => 'notification_integration_update',
                'target_type' => 'NotificationIntegration',
                'target_id' => 0,
                'meta' => [
                    'sections' => $updatedSections,
                ],
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
            ]);
        }

        return $this->getNotificationIntegrationStatus($request);
    }

    public function renderNotificationTemplate(Request $request, NotificationTemplate $notificationTemplate): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'placeholders' => 'nullable|array',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $placeholders = $request->input('placeholders', []);

        if (!is_array($placeholders)) {
            $placeholders = [];
        }

        $rendered = $this->notificationTemplateService->render($notificationTemplate, $placeholders);

        return response()->json([
            'success' => true,
            'preview' => [
                'channel' => $notificationTemplate->channel,
                'subject' => $notificationTemplate->subject ?? $notificationTemplate->name,
                'body' => $rendered,
            ],
        ]);
    }

    public function createNotificationTemplate(Request $request): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:150',
            'slug' => 'sometimes|string|max:150|alpha_dash',
            'channel' => 'required|in:email,push,sms,in_app',
            'subject' => 'nullable|string|max:255',
            'body' => 'required|string',
            'variables' => 'nullable|array',
            'variables.*' => 'string',
            'action_url' => 'nullable|string|max:255',
            'action_text' => 'nullable|string|max:100',
            'is_default' => 'nullable|boolean',
            'status' => 'nullable|in:draft,published,archived',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        try {
            $template = $this->notificationTemplateService->create($validator->validated());

            AuditLog::createLog(
                $admin->id,
                'notification_template_created',
                NotificationTemplate::class,
                $template->id,
                $template->toArray(),
                $request->ip(),
                $request->userAgent()
            );

            return response()->json([
                'success' => true,
                'template' => $this->transformNotificationTemplate($template),
            ], 201);
        } catch (\Throwable $throwable) {
            Log::error('Notification template create failed', [
                'error' => $throwable->getMessage(),
            ]);

            return response()->json([
                'error' => [
                    'code' => 'TEMPLATE_CREATE_ERROR',
                    'message' => 'Şablon oluşturulurken bir hata oluştu',
                ],
            ], 500);
        }
    }

    public function updateNotificationTemplate(Request $request, NotificationTemplate $notificationTemplate): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|required|string|max:150',
            'channel' => 'sometimes|required|in:email,push,sms,in_app',
            'subject' => 'nullable|string|max:255',
            'body' => 'sometimes|required|string',
            'variables' => 'nullable|array',
            'variables.*' => 'string',
            'action_url' => 'nullable|string|max:255',
            'action_text' => 'nullable|string|max:100',
            'is_default' => 'nullable|boolean',
            'status' => 'nullable|in:draft,published,archived',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        try {
            $template = $this->notificationTemplateService->update($notificationTemplate, $validator->validated());

            AuditLog::createLog(
                $admin->id,
                'notification_template_updated',
                NotificationTemplate::class,
                $template->id,
                $template->toArray(),
                $request->ip(),
                $request->userAgent()
            );

            return response()->json([
                'success' => true,
                'template' => $this->transformNotificationTemplate($template),
            ]);
        } catch (\Throwable $throwable) {
            Log::error('Notification template update failed', [
                'notification_template_id' => $notificationTemplate->id,
                'error' => $throwable->getMessage(),
            ]);

            return response()->json([
                'error' => [
                    'code' => 'TEMPLATE_UPDATE_ERROR',
                    'message' => $throwable->getMessage(),
                ],
            ], 500);
        }
    }

    public function publishNotificationTemplate(Request $request, NotificationTemplate $notificationTemplate): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $template = $this->notificationTemplateService->publish($notificationTemplate);

        AuditLog::createLog(
            $admin->id,
            'notification_template_published',
            NotificationTemplate::class,
            $template->id,
            $template->toArray(),
            $request->ip(),
            $request->userAgent()
        );

        return response()->json([
            'success' => true,
            'template' => $this->transformNotificationTemplate($template),
        ]);
    }

    public function archiveNotificationTemplate(Request $request, NotificationTemplate $notificationTemplate): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $template = $this->notificationTemplateService->archive($notificationTemplate);

        AuditLog::createLog(
            $admin->id,
            'notification_template_archived',
            NotificationTemplate::class,
            $template->id,
            $template->toArray(),
            $request->ip(),
            $request->userAgent()
        );

        return response()->json([
            'success' => true,
            'template' => $this->transformNotificationTemplate($template),
        ]);
    }

    public function duplicateNotificationTemplate(Request $request, NotificationTemplate $notificationTemplate): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $template = $this->notificationTemplateService->duplicate($notificationTemplate);

        AuditLog::createLog(
            $admin->id,
            'notification_template_duplicated',
            NotificationTemplate::class,
            $template->id,
            $template->toArray(),
            $request->ip(),
            $request->userAgent()
        );

        return response()->json([
            'success' => true,
            'template' => $this->transformNotificationTemplate($template),
        ]);
    }

    public function testSendNotificationTemplate(Request $request, NotificationTemplate $notificationTemplate): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'channel' => 'required|in:email,push,sms,in_app',
            'recipient' => 'nullable|string|max:255',
            'user_id' => 'nullable|integer|exists:users,id',
            'placeholders' => 'nullable|array',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $payload = $validator->validated();

        $placeholders = isset($payload['placeholders']) && is_array($payload['placeholders'])
            ? $payload['placeholders']
            : [];

        try {
            $placeholders = $this->notificationTemplateService->sanitizePlaceholderPayload($notificationTemplate, $placeholders);
        } catch (ValidationException $exception) {
            return response()->json([
                'error' => [
                    'code' => 'PLACEHOLDER_VALIDATION_ERROR',
                    'message' => $exception->getMessage(),
                ],
            ], 422);
        }

        $channel = $payload['channel'];
        $recipient = $payload['recipient'] ?? null;
        $userId = $payload['user_id'] ?? null;

        $subject = $notificationTemplate->subject
            ? $this->notificationTemplateService->renderString($notificationTemplate->subject, $placeholders)
            : ($notificationTemplate->name ?? 'Test Bildirimi');
        $rendered = $this->notificationTemplateService->render($notificationTemplate, $placeholders);

        $channelResponse = null;
        $successMessage = null;

        try {
            switch ($channel) {
                case 'email':
                    if (!$recipient) {
                        return response()->json([
                            'error' => [
                                'code' => 'MISSING_RECIPIENT',
                                'message' => 'Test e-postası gönderimi için alıcı e-postası gereklidir.',
                            ],
                        ], 422);
                    }

                    if (!$this->mailService->isMailConfigured()) {
                        return response()->json([
                            'error' => [
                                'code' => 'MAIL_NOT_CONFIGURED',
                                'message' => 'Mail ayarları yapılandırılmamış. Lütfen önce SMTP bilgilerini kaydedin.',
                            ],
                        ], 409);
                    }

                    Mail::mailer(config('mail.default', 'smtp'))->html($rendered, function ($message) use ($recipient, $subject) {
                        $message->to($recipient)
                            ->subject(sprintf('[Test] %s', $subject));
                    });

                    $channelResponse = [
                        'recipient' => $recipient,
                    ];
                    $successMessage = 'Test e-postası başarıyla gönderildi.';
                    break;

                case 'push':
                    $metadata = [
                        'template_id' => $notificationTemplate->id,
                        'template_slug' => $notificationTemplate->slug,
                        'test_send' => true,
                    ];

                    if ($userId) {
                        /** @var User|null $user */
                        $user = User::find($userId);
                        if (!$user) {
                            return response()->json([
                                'error' => [
                                    'code' => 'USER_NOT_FOUND',
                                    'message' => 'Belirtilen kullanıcı bulunamadı.',
                                ],
                            ], 404);
                        }

                        if (empty($user->fcm_tokens)) {
                            return response()->json([
                                'error' => [
                                    'code' => 'NO_FCM_TOKENS',
                                    'message' => 'Kullanıcıya kayıtlı cihaz bildirimi bulunamadı.',
                                ],
                            ], 409);
                        }

                        SendPushNotification::dispatchSync($user, $subject, strip_tags($rendered), $metadata);
                        $channelResponse = [
                            'mode' => 'user',
                            'user_id' => $user->id,
                            'token_count' => count($user->fcm_tokens),
                        ];
                        $successMessage = 'Push bildirimi kullanıcıya gönderilmek üzere işlendi.';
                    } elseif ($recipient) {
                        $pushResult = $this->pushNotificationService->sendToToken($recipient, $subject, strip_tags($rendered), $metadata);
                        if (!$pushResult['success']) {
                            return response()->json([
                                'error' => [
                                    'code' => 'PUSH_SEND_FAILED',
                                    'message' => $pushResult['error'] ?? 'Push bildirimi gönderilirken bir sorun oluştu.',
                                ],
                            ], 500);
                        }

                        $channelResponse = array_merge(['mode' => 'token'], $pushResult);
                        $successMessage = 'Push bildirimi başarılı şekilde gönderildi.';
                    } else {
                        return response()->json([
                            'error' => [
                                'code' => 'MISSING_TARGET',
                                'message' => 'Push testi için kullanıcı ID veya cihaz tokenı gereklidir.',
                            ],
                        ], 422);
                    }
                    break;

                case 'sms':
                    if (!$recipient) {
                        return response()->json([
                            'error' => [
                                'code' => 'MISSING_RECIPIENT',
                                'message' => 'SMS gönderimi için alıcı telefon numarası gereklidir.',
                            ],
                        ], 422);
                    }

                    if (!$this->smsService->isConfigured()) {
                        return response()->json([
                            'error' => [
                                'code' => 'SMS_NOT_CONFIGURED',
                                'message' => 'SMS sağlayıcısı yapılandırılmamış. Lütfen SMS ayarlarını kaydedin.',
                            ],
                        ], 409);
                    }

                    $smsResult = $this->smsService->send($recipient, trim(strip_tags($rendered)));
                    if (!$smsResult['success']) {
                        return response()->json([
                            'error' => [
                                'code' => 'SMS_SEND_FAILED',
                                'message' => $smsResult['error'] ?? 'SMS gönderimi başarısız oldu.',
                            ],
                        ], 500);
                    }

                    $channelResponse = $smsResult;
                    $successMessage = 'SMS testi başarıyla gönderildi.';
                    break;

                case 'in_app':
                    if (!$userId) {
                        return response()->json([
                            'error' => [
                                'code' => 'MISSING_USER',
                                'message' => 'In-app bildirimi için kullanıcı ID gereklidir.',
                            ],
                        ], 422);
                    }

                    /** @var User|null $user */
                    $user = User::find($userId);
                    if (!$user) {
                        return response()->json([
                            'error' => [
                                'code' => 'USER_NOT_FOUND',
                                'message' => 'Belirtilen kullanıcı bulunamadı.',
                            ],
                        ], 404);
                    }

                    Notification::create([
                        'user_id' => $user->id,
                        'title' => $subject,
                        'message' => strip_tags($rendered),
                        'type' => 'info',
                        'priority' => 'normal',
                        'data' => json_encode([
                            'template_id' => $notificationTemplate->id,
                            'test_send' => true,
                        ]),
                    ]);

                    $channelResponse = [
                        'mode' => 'in_app',
                        'user_id' => $user->id,
                    ];
                    $successMessage = 'In-app bildirimi kullanıcı hesabına iletildi.';
                    break;

                default:
                    return response()->json([
                        'error' => [
                            'code' => 'UNSUPPORTED_CHANNEL',
                            'message' => 'Desteklenmeyen bildirim kanalı seçildi.',
                        ],
                    ], 422);
            }

            AuditLog::create([
                'user_id' => $admin->id,
                'action' => 'notification_template_test_send',
                'target_type' => NotificationTemplate::class,
                'target_id' => $notificationTemplate->id,
                'meta' => [
                    'channel' => $channel,
                    'recipient' => $recipient,
                    'user_id' => $userId,
                ],
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
            ]);
        } catch (\Throwable $exception) {
            Log::error('Notification template test send failed', [
                'template_id' => $notificationTemplate->id,
                'channel' => $channel,
                'error' => $exception->getMessage(),
            ]);

            return response()->json([
                'error' => [
                    'code' => 'TEST_SEND_FAILED',
                    'message' => 'Test gönderimi sırasında bir hata oluştu: ' . $exception->getMessage(),
                ],
            ], 500);
        }

        return response()->json([
            'success' => true,
            'message' => $successMessage,
            'preview' => [
                'channel' => $channel,
                'subject' => $subject,
                'body' => $rendered,
            ],
            'channel_response' => $channelResponse,
        ]);
    }

    /**
     * Get notification statistics
     */
    public function getNotificationStats(): JsonResponse
    {
        try {
            $stats = $this->adminNotificationService->getNotificationStats();
            
            return response()->json([
                'success' => true,
                'stats' => $stats,
            ]);
        } catch (\Exception $e) {
            \Log::error('Notification stats error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => 'Bildirim istatistikleri yüklenirken hata oluştu',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get notification analytics
     */
    public function getNotificationAnalytics(): JsonResponse
    {
        try {
            $analytics = $this->adminNotificationService->getNotificationAnalytics();
            
            return response()->json([
                'success' => true,
                'analytics' => $analytics,
            ]);
        } catch (\Exception $e) {
            \Log::error('Notification analytics error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => 'Bildirim analitikleri yüklenirken hata oluştu',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Mark notifications as read
     */
    public function markNotificationsAsRead(Request $request): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'notification_ids' => 'required|array',
                'notification_ids.*' => 'integer|exists:notifications,id',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => $validator->errors()
                    ]
                ], 400);
            }

            $result = $this->adminNotificationService->markNotificationsAsRead($request->notification_ids);
            
            return response()->json([
                'success' => $result,
                'message' => $result ? 'Bildirimler okundu olarak işaretlendi' : 'Bildirimler işaretlenirken hata oluştu',
            ]);
        } catch (\Exception $e) {
            \Log::error('Mark notifications as read error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => 'Bildirimler işaretlenirken hata oluştu',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Cleanup old notifications
     */
    public function cleanupOldNotifications(Request $request): JsonResponse
    {
        try {
            $daysOld = $request->get('days_old', 90);
            $deletedCount = $this->adminNotificationService->cleanupOldNotifications($daysOld);
            
            return response()->json([
                'success' => true,
                'message' => "{$deletedCount} eski bildirim temizlendi",
                'deleted_count' => $deletedCount,
            ]);
        } catch (\Exception $e) {
            \Log::error('Cleanup old notifications error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => 'Eski bildirimler temizlenirken hata oluştu',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get user segmentation analytics
     */
    public function getUserSegmentation(Request $request): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        try {
            $filters = $request->only(['role', 'status']);
            $segmentation = $this->analyticsService->getUserSegmentation($filters);

            return response()->json([
                'success' => true,
                'segmentation' => $segmentation,
            ]);
        } catch (\Throwable $exception) {
            Log::error('User segmentation analytics failed', [
                'error' => $exception->getMessage(),
                'filters' => $request->all(),
            ]);

            return response()->json([
                'error' => [
                    'code' => 'ANALYTICS_ERROR',
                    'message' => 'Kullanıcı segmentasyonu verileri alınırken bir hata oluştu.',
                ],
            ], 500);
        }
    }

    /**
     * Get teacher benchmark analytics
     */
    public function getTeacherBenchmark(Request $request): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        try {
            $benchmark = $this->analyticsService->getTeacherBenchmark();

            return response()->json([
                'success' => true,
                'benchmark' => $benchmark,
            ]);
        } catch (\Throwable $exception) {
            Log::error('Teacher benchmark analytics failed', [
                'error' => $exception->getMessage(),
            ]);

            return response()->json([
                'error' => [
                    'code' => 'ANALYTICS_ERROR',
                    'message' => 'Öğretmen performans verileri alınırken bir hata oluştu.',
                ],
            ], 500);
        }
    }

    /**
     * Generate system report
     */
    public function generateSystemReport(Request $request): JsonResponse
    {
        try {
            $filters = $request->only(['date_from', 'date_to', 'type']);
            $report = $this->reportService->generateSystemReport($filters);
            
            return response()->json([
                'success' => true,
                'report' => $report,
            ]);
        } catch (\Exception $e) {
            \Log::error('Generate system report error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => 'Sistem raporu oluşturulurken hata oluştu',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Export report to CSV
     */
    public function exportReportToCsv(Request $request): JsonResponse
    {
        try {
            $filters = $request->only(['date_from', 'date_to', 'type']);
            $report = $this->reportService->generateSystemReport($filters);
            $filename = $request->get('filename');
            $filepath = $this->reportService->exportToCsv($report, $filename);
            
            return response()->json([
                'success' => true,
                'message' => 'Rapor CSV olarak dışa aktarıldı',
                'filepath' => $filepath,
                'filename' => basename($filepath),
            ]);
        } catch (\Exception $e) {
            \Log::error('Export report to CSV error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => 'Rapor dışa aktarılırken hata oluştu',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Create database backup
     */
    public function createDatabaseBackup(): JsonResponse
    {
        try {
            $admin = Auth::user();
            $result = $this->backupService->createDatabaseBackup([
                'source' => 'manual',
                'initiated_by' => $admin?->id,
                'initiated_by_name' => $admin?->name,
                'trigger' => 'admin_ui',
            ]);
            
            return response()->json($result);
        } catch (\Exception $e) {
            \Log::error('Create database backup error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => 'Veritabanı yedeği oluşturulurken hata oluştu',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Create filesystem backup
     */
    public function createFilesystemBackup(): JsonResponse
    {
        try {
            $admin = Auth::user();
            $result = $this->backupService->createFileSystemBackup([
                'source' => 'manual',
                'initiated_by' => $admin?->id,
                'initiated_by_name' => $admin?->name,
                'trigger' => 'admin_ui',
            ]);
            
            return response()->json($result);
        } catch (\Exception $e) {
            \Log::error('Create filesystem backup error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => 'Dosya sistemi yedeği oluşturulurken hata oluştu',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Create full backup
     */
    public function createFullBackup(): JsonResponse
    {
        try {
            $admin = Auth::user();
            $result = $this->backupService->createFullBackup([
                'source' => 'manual',
                'initiated_by' => $admin?->id,
                'initiated_by_name' => $admin?->name,
                'trigger' => 'admin_ui',
            ]);
            
            return response()->json($result);
        } catch (\Exception $e) {
            \Log::error('Create full backup error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => 'Tam yedek oluşturulurken hata oluştu',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * List backups
     */
    public function listBackups(): JsonResponse
    {
        try {
            $backups = $this->backupService->listBackups();
            
            return response()->json([
                'success' => true,
                'backups' => $backups,
            ]);
        } catch (\Exception $e) {
            \Log::error('List backups error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => 'Yedekler listelenirken hata oluştu',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get backup statistics
     */
    public function getBackupStats(): JsonResponse
    {
        try {
            $stats = $this->backupService->getBackupStats();
            
            return response()->json([
                'success' => true,
                'stats' => $stats,
            ]);
        } catch (\Exception $e) {
            \Log::error('Get backup stats error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => 'Yedek istatistikleri yüklenirken hata oluştu',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Restore from backup
     */
    public function restoreFromBackup(Request $request): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'filename' => 'required|string',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => $validator->errors()
                    ]
                ], 400);
            }

            $admin = Auth::user();
            $result = $this->backupService->restoreFromBackup($request->filename, [
                'source' => 'manual',
                'initiated_by' => $admin?->id,
                'initiated_by_name' => $admin?->name,
                'trigger' => 'admin_ui',
            ]);
            
            return response()->json($result);
        } catch (\Exception $e) {
            \Log::error('Restore from backup error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => 'Yedekten geri yüklenirken hata oluştu',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Delete backup
     */
    public function deleteBackup(Request $request): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'filename' => 'required|string',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => $validator->errors()
                    ]
                ], 400);
            }

            $result = $this->backupService->deleteBackup($request->filename);
            
            return response()->json($result);
        } catch (\Exception $e) {
            \Log::error('Delete backup error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => 'Yedek silinirken hata oluştu',
                'message' => $e->getMessage(),
            ], 500);
        }
    }
}
