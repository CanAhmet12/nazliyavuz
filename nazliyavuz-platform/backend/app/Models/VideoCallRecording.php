<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class VideoCallRecording extends Model
{
    use HasFactory;

    protected $fillable = [
        'video_call_id',
        'recording_url',
        'recording_type',
        'duration_seconds',
        'file_size',
        'file_format',
        'is_processed',
        'thumbnail_url',
        'metadata',
    ];

    protected $casts = [
        'is_processed' => 'boolean',
        'metadata' => 'array',
    ];

    /**
     * Get the video call
     */
    public function videoCall(): BelongsTo
    {
        return $this->belongsTo(VideoCall::class);
    }

    /**
     * Get formatted file size
     */
    public function getFormattedFileSizeAttribute(): string
    {
        if (!$this->file_size) {
            return 'Unknown';
        }

        $bytes = (int) $this->file_size;
        $units = ['B', 'KB', 'MB', 'GB'];
        
        for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
            $bytes /= 1024;
        }
        
        return round($bytes, 2) . ' ' . $units[$i];
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
     * Check if recording is video
     */
    public function isVideo(): bool
    {
        return $this->recording_type === 'video';
    }

    /**
     * Check if recording is audio
     */
    public function isAudio(): bool
    {
        return $this->recording_type === 'audio';
    }

    /**
     * Scope for video recordings
     */
    public function scopeVideo($query)
    {
        return $query->where('recording_type', 'video');
    }

    /**
     * Scope for audio recordings
     */
    public function scopeAudio($query)
    {
        return $query->where('recording_type', 'audio');
    }

    /**
     * Scope for processed recordings
     */
    public function scopeProcessed($query)
    {
        return $query->where('is_processed', true);
    }

    /**
     * Scope for unprocessed recordings
     */
    public function scopeUnprocessed($query)
    {
        return $query->where('is_processed', false);
    }
}
