<?php

namespace App\Services;

use App\Models\ScheduledNotification;
use App\Models\ScheduledNotificationLog;
use App\Models\NotificationTemplate;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;

class ScheduledNotificationService
{
    public function __construct(
        protected AdminNotificationService $adminNotificationService,
        protected NotificationTemplateService $notificationTemplateService
    ) {
    }

    public function list(array $filters = []): Collection
    {
        $query = ScheduledNotification::query()
            ->with(['creator', 'updater', 'template'])
            ->orderByDesc('created_at');

        if (!empty($filters['status'])) {
            $query->where('status', $filters['status']);
        }

        if (!empty($filters['target_type'])) {
            $query->where('target_type', $filters['target_type']);
        }

        if (!empty($filters['from'])) {
            $query->where('scheduled_at', '>=', $filters['from']);
        }

        if (!empty($filters['to'])) {
            $query->where('scheduled_at', '<=', $filters['to']);
        }

        return $query->get();
    }

    public function create(array $data): ScheduledNotification
    {
        return DB::transaction(function () use ($data) {
            $meta = $data['meta'] ?? null;
            $template = null;

            if (!empty($data['template_id'])) {
                $template = NotificationTemplate::findOrFail($data['template_id']);

                $placeholders = [];
                if (isset($data['meta']['placeholders']) && is_array($data['meta']['placeholders'])) {
                    $placeholders = $data['meta']['placeholders'];
                }

                $sanitizedPlaceholders = $this->notificationTemplateService->sanitizePlaceholderPayload($template, $placeholders);
                $meta = array_merge($meta ?? [], ['placeholders' => $sanitizedPlaceholders]);
            }

            $notification = ScheduledNotification::create([
                'title' => $data['title'],
                'message' => $data['message'],
                'type' => $data['type'] ?? 'info',
                'priority' => $data['priority'] ?? 'normal',
                'target_type' => $data['target_type'] ?? 'all',
                'target_filters' => $data['target_filters'] ?? null,
                'channels' => $data['channels'] ?? [
                    'push' => true,
                    'email' => false,
                    'in_app' => true,
                ],
                'template_id' => $data['template_id'] ?? null,
                'scheduled_at' => $data['scheduled_at'] ?? null,
                'timezone' => $data['timezone'] ?? null,
                'status' => $data['status'] ?? 'draft',
                'meta' => $meta,
                'created_by' => Auth::id(),
                'updated_by' => Auth::id(),
            ]);

            return $notification->fresh(['creator', 'template']);
        });
    }

    public function update(ScheduledNotification $notification, array $data): ScheduledNotification
    {
        return DB::transaction(function () use ($notification, $data) {
            if ($notification->status === 'sent' || $notification->status === 'sending') {
                throw new \RuntimeException('Gönderilmiş bildirim düzenlenemez.');
            }

            $meta = $data['meta'] ?? $notification->meta ?? [];

            $templateId = $data['template_id'] ?? $notification->template_id;
            if ($templateId) {
                $template = NotificationTemplate::findOrFail($templateId);
                $placeholders = [];

                if (isset($data['meta']['placeholders']) && is_array($data['meta']['placeholders'])) {
                    $placeholders = $data['meta']['placeholders'];
                } elseif (isset($notification->meta['placeholders']) && is_array($notification->meta['placeholders'])) {
                    $placeholders = $notification->meta['placeholders'];
                }

                $sanitized = $this->notificationTemplateService->sanitizePlaceholderPayload($template, $placeholders);
                $meta = array_merge($meta ?? [], ['placeholders' => $sanitized]);
            } elseif (isset($meta['placeholders'])) {
                unset($meta['placeholders']);
            }

            $notification->fill([
                'title' => $data['title'] ?? $notification->title,
                'message' => $data['message'] ?? $notification->message,
                'type' => $data['type'] ?? $notification->type,
                'priority' => $data['priority'] ?? $notification->priority,
                'target_type' => $data['target_type'] ?? $notification->target_type,
                'target_filters' => $data['target_filters'] ?? $notification->target_filters,
                'channels' => $data['channels'] ?? $notification->channels,
                'scheduled_at' => $data['scheduled_at'] ?? $notification->scheduled_at,
                'timezone' => $data['timezone'] ?? $notification->timezone,
                'meta' => $meta,
                'status' => $data['status'] ?? $notification->status,
                'template_id' => $data['template_id'] ?? $notification->template_id,
                'updated_by' => Auth::id(),
            ]);

            $notification->save();

            return $notification->fresh(['template']);
        });
    }

    public function schedule(ScheduledNotification $notification, \DateTimeInterface $scheduledAt, ?string $timezone = null): ScheduledNotification
    {
        return $this->update($notification, [
            'scheduled_at' => $scheduledAt,
            'timezone' => $timezone,
            'status' => 'scheduled',
        ]);
    }

    public function cancel(ScheduledNotification $notification): ScheduledNotification
    {
        if (!in_array($notification->status, ['draft', 'scheduled', 'queued'])) {
            throw new \RuntimeException('Yalnızca bekleyen bildirimler iptal edilebilir.');
        }

        return $this->update($notification, [
            'status' => 'cancelled',
        ]);
    }

    public function queue(ScheduledNotification $notification): void
    {
        if ($notification->status === 'draft') {
            throw new \RuntimeException('Taslak durumundaki bildirim kuyruğa alınamaz.');
        }

        $notification->update([
            'status' => 'queued',
        ]);

        dispatch(new \App\Jobs\DispatchScheduledNotificationJob($notification));
    }

    public function sendNow(ScheduledNotification $notification): void
    {
        $notification->update([
            'scheduled_at' => now(),
            'status' => 'queued',
        ]);

        dispatch(new \App\Jobs\DispatchScheduledNotificationJob($notification));
    }

    public function handleDispatch(ScheduledNotification $notification): void
    {
        $log = ScheduledNotificationLog::create([
            'scheduled_notification_id' => $notification->id,
            'status' => 'processing',
            'started_at' => now(),
        ]);

        try {
            $notification->update([
                'status' => 'sending',
                'last_attempt_at' => now(),
            ]);

            $targets = $this->resolveTargets($notification);

            if ($targets->isEmpty()) {
                throw new \RuntimeException('Hedef kullanıcı bulunamadı.');
            }

            $payload = [];
            if (isset($notification->meta['placeholders']) && is_array($notification->meta['placeholders'])) {
                $payload = $notification->meta['placeholders'];
            }
            $message = $notification->message;
            $title = $notification->title;

            if ($notification->template_id) {
                $template = $notification->template ?: NotificationTemplate::find($notification->template_id);
                if ($template) {
                    $sanitizedPayload = $this->notificationTemplateService->sanitizePlaceholderPayload($template, $payload);
                    $message = $this->notificationTemplateService->render($template, $sanitizedPayload);
                    if (!empty($template->subject)) {
                        $title = $this->notificationTemplateService->renderString($template->subject, $sanitizedPayload);
                    }
                    $payload = $sanitizedPayload;
                }
            }

            $data = [
                'title' => $title,
                'message' => $message,
                'type' => $notification->type,
                'priority' => $notification->priority,
                'target_users' => [$notification->target_type],
            ];

            $result = $this->adminNotificationService->sendBulkNotification($data);

            $notification->update([
                'status' => 'sent',
                'sent_count' => $notification->sent_count + ($result['sent_count'] ?? 0),
                'fail_count' => $notification->fail_count + ($result['failed_count'] ?? 0),
            ]);

            $log->update([
                'status' => 'sent',
                'sent_count' => $result['sent_count'] ?? 0,
                'fail_count' => $result['failed_count'] ?? 0,
                'finished_at' => now(),
            ]);
        } catch (ValidationException $exception) {
            Log::error('Scheduled notification placeholder validation failed', [
                'scheduled_notification_id' => $notification->id,
                'error' => $exception->getMessage(),
            ]);

            $notification->update([
                'status' => 'failed',
            ]);

            $log->update([
                'status' => 'failed',
                'error_message' => $exception->getMessage(),
                'finished_at' => now(),
            ]);
        } catch (\Throwable $throwable) {
            Log::error('Scheduled notification dispatch failed', [
                'scheduled_notification_id' => $notification->id,
                'error' => $throwable->getMessage(),
            ]);

            $notification->update([
                'status' => 'failed',
            ]);

            $log->update([
                'status' => 'failed',
                'error_message' => $throwable->getMessage(),
                'finished_at' => now(),
            ]);
        }
    }

    private function resolveTargets(ScheduledNotification $notification): Collection
    {
        $query = User::query();

        switch ($notification->target_type) {
            case 'students':
            case 'teachers':
            case 'admins':
                $query->where('role', $notification->target_type);
                break;
            case 'all':
            default:
                break;
        }

        return $query->get();
    }
}

