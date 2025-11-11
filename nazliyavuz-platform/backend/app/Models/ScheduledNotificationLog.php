<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ScheduledNotificationLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'scheduled_notification_id',
        'status',
        'sent_count',
        'fail_count',
        'started_at',
        'finished_at',
        'error_message',
        'meta',
    ];

    protected $casts = [
        'started_at' => 'datetime',
        'finished_at' => 'datetime',
        'meta' => 'array',
    ];

    public function scheduledNotification(): BelongsTo
    {
        return $this->belongsTo(ScheduledNotification::class);
    }
}

