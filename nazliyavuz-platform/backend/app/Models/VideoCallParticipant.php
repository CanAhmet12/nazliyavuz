<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class VideoCallParticipant extends Model
{
    use HasFactory;

    protected $fillable = [
        'video_call_id',
        'user_id',
        'role',
        'status',
        'joined_at',
        'left_at',
        'is_muted',
        'video_enabled',
        'screen_sharing',
        'connection_quality',
    ];

    protected $casts = [
        'joined_at' => 'datetime',
        'left_at' => 'datetime',
        'is_muted' => 'boolean',
        'video_enabled' => 'boolean',
        'screen_sharing' => 'boolean',
        'connection_quality' => 'array',
    ];

    /**
     * Get the video call
     */
    public function videoCall(): BelongsTo
    {
        return $this->belongsTo(VideoCall::class);
    }

    /**
     * Get the user
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Check if participant is active
     */
    public function isActive(): bool
    {
        return $this->status === 'active';
    }

    /**
     * Check if participant has left
     */
    public function hasLeft(): bool
    {
        return in_array($this->status, ['left', 'disconnected']);
    }

    /**
     * Get connection quality score
     */
    public function getConnectionQualityScoreAttribute(): float
    {
        if (!$this->connection_quality) {
            return 0.0;
        }

        $quality = $this->connection_quality;
        $scores = [];

        if (isset($quality['bitrate'])) {
            $scores[] = min($quality['bitrate'] / 1000, 1.0); // Normalize to 0-1
        }

        if (isset($quality['latency'])) {
            $scores[] = max(0, 1 - ($quality['latency'] / 500)); // Normalize to 0-1
        }

        if (isset($quality['packet_loss'])) {
            $scores[] = max(0, 1 - $quality['packet_loss']); // Normalize to 0-1
        }

        return empty($scores) ? 0.0 : array_sum($scores) / count($scores);
    }

    /**
     * Get formatted connection quality
     */
    public function getFormattedConnectionQualityAttribute(): string
    {
        $score = $this->connection_quality_score;

        if ($score >= 0.8) {
            return 'Excellent';
        } elseif ($score >= 0.6) {
            return 'Good';
        } elseif ($score >= 0.4) {
            return 'Fair';
        } elseif ($score >= 0.2) {
            return 'Poor';
        } else {
            return 'Very Poor';
        }
    }

    /**
     * Scope for active participants
     */
    public function scopeActive($query)
    {
        return $query->where('status', 'active');
    }

    /**
     * Scope for callers
     */
    public function scopeCallers($query)
    {
        return $query->where('role', 'caller');
    }

    /**
     * Scope for receivers
     */
    public function scopeReceivers($query)
    {
        return $query->where('role', 'receiver');
    }
}
