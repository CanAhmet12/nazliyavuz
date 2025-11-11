<?php

namespace App\Services;

use App\Models\NotificationTemplate;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class NotificationTemplateService
{
    public function list(array $filters = []): Collection
    {
        $query = NotificationTemplate::query()
            ->with(['creator', 'updater'])
            ->orderByDesc('updated_at');

        if (!empty($filters['channel'])) {
            $query->where('channel', $filters['channel']);
        }

        if (!empty($filters['status'])) {
            $query->where('status', $filters['status']);
        }

        if (!empty($filters['search'])) {
            $query->where(function ($q) use ($filters) {
                $q->where('name', 'like', '%' . $filters['search'] . '%')
                    ->orWhere('slug', 'like', '%' . $filters['search'] . '%');
            });
        }

        return $query->get();
    }

    public function create(array $data): NotificationTemplate
    {
        $slug = $data['slug'] ?? Str::slug($data['name']);

        if (NotificationTemplate::where('slug', $slug)->exists()) {
            $slug .= '-' . Str::random(4);
        }

        $placeholders = $this->collectPlaceholders(
            $data['subject'] ?? null,
            $data['body'] ?? '',
            $data['action_text'] ?? null,
            $data['action_url'] ?? null
        );
        $variables = $this->prepareVariables($data['variables'] ?? null, $placeholders);

        return DB::transaction(function () use ($data, $slug, $variables) {
            $template = NotificationTemplate::create([
                'name' => $data['name'],
                'slug' => $slug,
                'channel' => $data['channel'],
                'subject' => $data['subject'] ?? null,
                'body' => $data['body'],
                'variables' => $variables,
                'action_url' => $data['action_url'] ?? null,
                'action_text' => $data['action_text'] ?? null,
                'is_default' => $data['is_default'] ?? false,
                'status' => $data['status'] ?? 'draft',
                'meta' => $data['meta'] ?? null,
                'created_by' => Auth::id(),
                'updated_by' => Auth::id(),
            ]);

            if ($template->is_default) {
                NotificationTemplate::where('channel', $template->channel)
                    ->where('id', '!=', $template->id)
                    ->update(['is_default' => false]);
            }

            return $template->fresh(['creator']);
        });
    }

    public function update(NotificationTemplate $template, array $data): NotificationTemplate
    {
        $subject = array_key_exists('subject', $data) ? $data['subject'] : $template->subject;
        $body = array_key_exists('body', $data) ? $data['body'] : $template->body;
        $actionText = array_key_exists('action_text', $data) ? $data['action_text'] : $template->action_text;

        $actionUrl = array_key_exists('action_url', $data) ? $data['action_url'] : $template->action_url;

        $placeholders = $this->collectPlaceholders($subject, $body, $actionText, $actionUrl);
        $currentVariables = array_key_exists('variables', $data) ? $data['variables'] : $template->variables;
        $preparedVariables = $this->prepareVariables($currentVariables, $placeholders);
        $data['variables'] = $preparedVariables;

        return DB::transaction(function () use ($template, $data) {
            if (isset($data['name'])) {
                $template->name = $data['name'];
            }

            if (isset($data['channel'])) {
                $template->channel = $data['channel'];
            }

            if (array_key_exists('subject', $data)) {
                $template->subject = $data['subject'];
            }

            if (isset($data['body'])) {
                $template->body = $data['body'];
            }

            if (isset($data['variables'])) {
                $template->variables = $data['variables'];
            }

            if (array_key_exists('action_url', $data)) {
                $template->action_url = $data['action_url'];
            }

            if (array_key_exists('action_text', $data)) {
                $template->action_text = $data['action_text'];
            }

            if (array_key_exists('meta', $data)) {
                $template->meta = $data['meta'];
            }

            if (array_key_exists('is_default', $data)) {
                $template->is_default = (bool) $data['is_default'];
            }

            if (isset($data['status'])) {
                $template->status = $data['status'];
            }

            $template->updated_by = Auth::id();
            $template->save();

            if ($template->is_default) {
                NotificationTemplate::where('channel', $template->channel)
                    ->where('id', '!=', $template->id)
                    ->update(['is_default' => false]);
            }

            return $template->fresh();
        });
    }

    public function publish(NotificationTemplate $template): NotificationTemplate
    {
        return $this->update($template, [
            'status' => 'published',
        ]);
    }

    public function archive(NotificationTemplate $template): NotificationTemplate
    {
        return $this->update($template, [
            'status' => 'archived',
        ]);
    }

    public function duplicate(NotificationTemplate $template): NotificationTemplate
    {
        $data = $template->toArray();
        $data['name'] = $template->name . ' (Kopya)';
        $data['status'] = 'draft';
        $data['is_default'] = false;

        unset($data['id'], $data['slug'], $data['created_at'], $data['updated_at'], $data['created_by'], $data['updated_by']);

        return $this->create($data);
    }

    public function render(NotificationTemplate $template, array $payload = []): string
    {
        return $this->renderString($template->body, $payload);
    }

    public function getTemplatePlaceholders(NotificationTemplate $template): array
    {
        return $this->collectPlaceholders($template->subject, $template->body, $template->action_text, $template->action_url);
    }

    /**
     * Validate and sanitize placeholder payload values for a template.
     *
     * @param array<string, mixed> $payload
     * @return array<string, string>
     */
    public function sanitizePlaceholderPayload(NotificationTemplate $template, array $payload): array
    {
        $placeholders = $this->getTemplatePlaceholders($template);

        if (empty($placeholders)) {
            return [];
        }

        $missing = [];
        $sanitized = [];

        foreach ($placeholders as $placeholder) {
            if (!array_key_exists($placeholder, $payload)) {
                $missing[] = $placeholder;
                continue;
            }

            $value = $payload[$placeholder];

            if (is_bool($value)) {
                $stringValue = $value ? '1' : '0';
            } elseif (is_scalar($value)) {
                $stringValue = (string) $value;
            } elseif (is_object($value) && method_exists($value, '__toString')) {
                $stringValue = (string) $value;
            } else {
                $missing[] = $placeholder;
                continue;
            }

            if (trim($stringValue) === '') {
                $missing[] = $placeholder;
                continue;
            }

            $sanitized[$placeholder] = $stringValue;
        }

        if (!empty($missing)) {
            throw ValidationException::withMessages([
                'placeholders' => 'Eksik placeholder değerleri: ' . implode(', ', $missing),
            ]);
        }

        $extra = Arr::only($payload, array_diff(array_keys($payload), $placeholders));

        return array_merge($sanitized, $extra);
    }

    public function renderString(string $text, array $payload = []): string
    {
        $rendered = $text;

        foreach ($payload as $key => $value) {
            if (is_scalar($value)) {
                $rendered = str_replace('{{' . $key . '}}', (string) $value, $rendered);
            }
        }

        return preg_replace('/\{\{[^}]+\}\}/', '', $rendered);
    }

    public function getVariableCatalog(): array
    {
        return [
            'user' => [
                'user.name',
                'user.full_name',
                'user.email',
                'user.phone',
                'user.id',
            ],
            'reservation' => [
                'reservation.id',
                'reservation.code',
                'reservation.date',
                'reservation.start_time',
                'reservation.end_time',
                'reservation.status',
            ],
            'teacher' => [
                'teacher.name',
                'teacher.email',
                'teacher.phone',
                'teacher.profile_url',
            ],
            'student' => [
                'student.name',
                'student.email',
                'student.phone',
            ],
            'system' => [
                'system.app_name',
                'system.dashboard_url',
                'system.support_email',
                'system.support_phone',
            ],
        ];
    }

    private function collectPlaceholders(?string $subject, ?string $body, ?string $actionText, ?string $actionUrl = null): array
    {
        $placeholders = array_merge(
            $this->extractPlaceholdersFromString($subject),
            $this->extractPlaceholdersFromString($body ?? ''),
            $this->extractPlaceholdersFromString($actionText),
            $this->extractPlaceholdersFromString($actionUrl)
        );

        $placeholders = array_map(static fn ($placeholder) => trim($placeholder), $placeholders);

        return array_values(array_unique(array_filter($placeholders)));
    }

    private function extractPlaceholdersFromString(?string $value): array
    {
        if ($value === null || $value === '') {
            return [];
        }

        preg_match_all('/\{\{\s*([^}\s]+)\s*\}\}/', $value, $matches);

        return $matches[1] ?? [];
    }

    private function prepareVariables(?array $variables, array $placeholders): array
    {
        $variables = $variables ?? [];
        $variables = array_values(array_unique(array_filter(array_map('trim', $variables))));

        $catalogVariables = collect($this->getVariableCatalog())
            ->flatten()
            ->filter()
            ->values()
            ->all();

        $allowed = array_merge($variables, $catalogVariables);

        $invalid = [];
        foreach ($placeholders as $placeholder) {
            if (!in_array($placeholder, $allowed, true)) {
                $invalid[] = $placeholder;
            } else {
                $variables[] = $placeholder;
            }
        }

        if (!empty($invalid)) {
            throw ValidationException::withMessages([
                'body' => [
                    'Şablon gövdesinde tanımlanmamış değişkenler kullanılıyor: ' . implode(', ', $invalid),
                ],
            ]);
        }

        return array_values(array_unique($variables));
    }
}

