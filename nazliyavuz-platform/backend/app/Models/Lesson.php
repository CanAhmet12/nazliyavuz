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
     * Get the teacher profile for this lesson
     */
    public function teacherProfile()
    {
        return $this->belongsTo(Teacher::class, 'teacher_id', 'user_id');
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

    /**
     * Get status text in Turkish
     */
    public function getStatusTextAttribute()
    {
        $statuses = [
            'scheduled' => 'Planlandı',
            'in_progress' => 'Devam Ediyor',
            'completed' => 'Tamamlandı',
            'cancelled' => 'İptal Edildi',
        ];

        return $statuses[$this->status] ?? 'Bilinmiyor';
    }

    /**
     * Check if lesson is completed
     */
    public function getIsCompletedAttribute()
    {
        return $this->status === 'completed';
    }

    /**
     * Check if lesson is rated
     */
    public function getIsRatedAttribute()
    {
        return !is_null($this->rating);
    }

    /**
     * Get teacher name
     */
    public function getTeacherNameAttribute()
    {
        return $this->teacher ? $this->teacher->name : null;
    }

    /**
     * Get student name
     */
    public function getStudentNameAttribute()
    {
        return $this->student ? $this->student->name : null;
    }

    /**
     * Get subject from reservation
     */
    public function getSubjectAttribute()
    {
        return $this->reservation ? $this->reservation->subject : null;
    }
}