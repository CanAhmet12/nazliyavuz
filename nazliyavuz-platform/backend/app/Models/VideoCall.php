<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class VideoCall extends Model
{
    use HasFactory;

    protected $fillable = [
        'call_id',
        'caller_id',
        'receiver_id',
        'call_type',
        'subject',
        'reservation_id',
        'status',
        'started_at',
        'answered_at',
        'ended_at',
        'duration_seconds',
        'end_reason',
        'call_quality_metrics',
        'is_recorded',
        'recording_url',
        'screen_shared',
        'metadata',
    ];

    protected $casts = [
        'started_at' => 'datetime',
        'answered_at' => 'datetime',
        'ended_at' => 'datetime',
        'call_quality_metrics' => 'array',
        'is_recorded' => 'boolean',
        'screen_shared' => 'boolean',
        'metadata' => 'array',
    ];

    /**
     * Get the caller user
     */
    public function caller(): BelongsTo
    {
        return $this->belongsTo(User::class, 'caller_id');
    }

    /**
     * Get the receiver user
     */
    public function receiver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'receiver_id');
    }

    /**
     * Get the reservation
     */
    public function reservation(): BelongsTo
    {
        return $this->belongsTo(Reservation::class);
    }

    /**
     * Get the participants
     */
    public function participants(): HasMany
    {
        return $this->hasMany(VideoCallParticipant::class);
    }

    /**
     * Get the recording
     */
    public function recording(): HasOne
    {
        return $this->hasOne(VideoCallRecording::class);
    }

    /**
     * Check if call is active
     */
    public function isActive(): bool
    {
        return $this->status === 'active';
    }

    /**
     * Check if call is ended
     */
    public function isEnded(): bool
    {
        return in_array($this->status, ['ended', 'rejected', 'missed']);
    }

    /**
     * Get formatted duration
     */
    public function getFormattedDurationAttribute(): string
    {
        if (!$this->duration_seconds) {
            return '00:00';
        }

        $hours = floor($this->duration_seconds / 3600);
        $minutes = floor(($this->duration_seconds % 3600) / 60);
        $seconds = $this->duration_seconds % 60;

        if ($hours > 0) {
            return sprintf('%02d:%02d:%02d', $hours, $minutes, $seconds);
        }

        return sprintf('%02d:%02d', $minutes, $seconds);
    }

    /**
     * Get call quality score
     */
    public function getQualityScoreAttribute(): float
    {
        if (!$this->call_quality_metrics) {
            return 0.0;
        }

        $metrics = $this->call_quality_metrics;
        $scores = [];

        if (isset($metrics['video_quality'])) {
            $scores[] = $metrics['video_quality'];
        }

        if (isset($metrics['audio_quality'])) {
            $scores[] = $metrics['audio_quality'];
        }

        if (isset($metrics['connection_stability'])) {
            $scores[] = $metrics['connection_stability'];
        }

        return empty($scores) ? 0.0 : array_sum($scores) / count($scores);
    }

    /**
     * Scope for active calls
     */
    public function scopeActive($query)
    {
        return $query->where('status', 'active');
    }

    /**
     * Scope for ended calls
     */
    public function scopeEnded($query)
    {
        return $query->whereIn('status', ['ended', 'rejected', 'missed']);
    }

    /**
     * Scope for video calls
     */
    public function scopeVideo($query)
    {
        return $query->where('call_type', 'video');
    }

    /**
     * Scope for audio calls
     */
    public function scopeAudio($query)
    {
        return $query->where('call_type', 'audio');
    }

    /**
     * Scope for calls by user
     */
    public function scopeByUser($query, int $userId)
    {
        return $query->where(function ($q) use ($userId) {
            $q->where('caller_id', $userId)
              ->orWhere('receiver_id', $userId);
        });
    }

    /**
     * Scope for calls between users
     */
    public function scopeBetweenUsers($query, int $user1Id, int $user2Id)
    {
        return $query->where(function ($q) use ($user1Id, $user2Id) {
            $q->where(function ($subQ) use ($user1Id, $user2Id) {
                $subQ->where('caller_id', $user1Id)
                     ->where('receiver_id', $user2Id);
            })->orWhere(function ($subQ) use ($user1Id, $user2Id) {
                $subQ->where('caller_id', $user2Id)
                     ->where('receiver_id', $user1Id);
            });
        });
    }
}
