<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ScheduledNotification extends Model
{
    use HasFactory;

    protected $fillable = [
        'title',
        'message',
        'type',
        'priority',
        'target_type',
        'target_filters',
        'channels',
        'scheduled_at',
        'timezone',
        'status',
        'sent_count',
        'fail_count',
        'last_attempt_at',
        'meta',
        'created_by',
        'updated_by',
        'template_id',
    ];

    protected $casts = [
        'target_filters' => 'array',
        'channels' => 'array',
        'scheduled_at' => 'datetime',
        'meta' => 'array',
        'last_attempt_at' => 'datetime',
    ];

    public function logs(): HasMany
    {
        return $this->hasMany(ScheduledNotificationLog::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function updater(): BelongsTo
    {
        return $this->belongsTo(User::class, 'updated_by');
    }

    public function template(): BelongsTo
    {
        return $this->belongsTo(NotificationTemplate::class, 'template_id');
    }

    public function scopeScheduled($query)
    {
        return $query->where('status', 'scheduled');
    }

    public function scopeDue($query)
    {
        return $query->whereIn('status', ['scheduled', 'queued'])
            ->whereNotNull('scheduled_at')
            ->where('scheduled_at', '<=', now());
    }
}

