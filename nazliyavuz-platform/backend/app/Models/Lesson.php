<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Reservation;

class Lesson extends Model
{
    use HasFactory;

    protected $fillable = [
        'reservation_id',
        'teacher_id',
        'student_id',
        'scheduled_at',
        'started_at',
        'ended_at',
        'duration_minutes',
        'status',
        'notes',
        'rating',
        'feedback',
        'rated_at',
    ];

    protected function casts(): array
    {
        return [
            'scheduled_at' => 'datetime',
            'started_at' => 'datetime',
            'ended_at' => 'datetime',
            'rated_at' => 'datetime',
        ];
    }

    /**
     * Get the reservation for this lesson
     */
    public function reservation()
    {
        return $this->belongsTo(Reservation::class);
    }

    /**
     * Get the teacher for this lesson
     */
    public function teacher()
    {
        return $this->belongsTo(User::class, 'teacher_id');
    }

    /**
     * Get the student for this lesson
     */
    public function student()
    {
        return $this->belongsTo(User::class, 'student_id');
    }

    /**
     * Scope for scheduled lessons
     */
    public function scopeScheduled($query)
    {
        return $query->where('status', 'scheduled');
    }

    /**
     * Scope for in progress lessons
     */
    public function scopeInProgress($query)
    {
        return $query->where('status', 'in_progress');
    }

    /**
     * Scope for completed lessons
     */
    public function scopeCompleted($query)
    {
        return $query->where('status', 'completed');
    }

    /**
     * Scope for cancelled lessons
     */
    public function scopeCancelled($query)
    {
        return $query->where('status', 'cancelled');
    }

    /**
     * Scope for upcoming lessons
     */
    public function scopeUpcoming($query)
    {
        return $query->where('scheduled_at', '>', now());
    }

    /**
     * Scope for past lessons
     */
    public function scopePast($query)
    {
        return $query->where('scheduled_at', '<', now());
    }

    /**
     * Get formatted duration
     */
    public function getFormattedDurationAttribute()
    {
        if (!$this->duration_minutes) {
            return 'N/A';
        }

        $hours = floor($this->duration_minutes / 60);
        $minutes = $this->duration_minutes % 60;

        if ($hours > 0) {
            return $hours . 'sa ' . $minutes . 'dk';
        }

        return $minutes . 'dk';
    }

    /**
     * Check if lesson is overdue
     */
    public function getIsOverdueAttribute()
    {
        return $this->status === 'scheduled' && $this->scheduled_at < now();
    }

    /**
     * Check if lesson can be started
     */
    public function getCanBeStartedAttribute()
    {
        return $this->status === 'scheduled' && $this->scheduled_at <= now()->addMinutes(15);
    }

    /**
     * Check if lesson can be rated
     */
    public function getCanBeRatedAttribute()
    {
        return $this->status === 'completed' && !$this->rating;
    }
}