<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ReservationReminderSetting extends Model
{
    use HasFactory;

    protected $fillable = [
        'workflow_id',
        'name',
        'offset_minutes',
        'offset_direction',
        'send_window',
        'step_order',
        'enabled',
        'stop_on_success',
        'notify_student',
        'notify_teacher',
        'send_email',
        'channels',
        'metadata',
    ];

    protected $casts = [
        'enabled' => 'boolean',
        'stop_on_success' => 'boolean',
        'notify_student' => 'boolean',
        'notify_teacher' => 'boolean',
        'send_email' => 'boolean',
        'channels' => 'array',
        'metadata' => 'array',
    ];

    public function workflow(): BelongsTo
    {
        return $this->belongsTo(ReservationReminderWorkflow::class, 'workflow_id');
    }

    public function logs(): HasMany
    {
        return $this->hasMany(ReservationReminderLog::class, 'reminder_setting_id');
    }

    public function scopeOrdered($query)
    {
        return $query->orderBy('step_order');
    }

    public function getChannelConfigAttribute(): array
    {
        $channels = $this->channels ?? [];

        $default = [
            'student' => [
                'push' => [
                    'enabled' => (bool) $this->notify_student,
                    'template_id' => null,
                ],
                'email' => [
                    'enabled' => (bool) $this->send_email,
                    'template_id' => null,
                ],
                'sms' => [
                    'enabled' => false,
                    'template_id' => null,
                ],
            ],
            'teacher' => [
                'push' => [
                    'enabled' => (bool) $this->notify_teacher,
                    'template_id' => null,
                ],
                'email' => [
                    'enabled' => false,
                    'template_id' => null,
                ],
                'sms' => [
                    'enabled' => false,
                    'template_id' => null,
                ],
            ],
        ];

        if (!is_array($channels) || empty($channels)) {
            return $default;
        }

        return [
            'student' => array_replace_recursive($default['student'], $channels['student'] ?? []),
            'teacher' => array_replace_recursive($default['teacher'], $channels['teacher'] ?? []),
        ];
    }
}

