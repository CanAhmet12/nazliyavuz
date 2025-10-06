<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Assignment extends Model
{
    use HasFactory;

    protected $fillable = [
        'teacher_id',
        'student_id',
        'reservation_id',
        'title',
        'description',
        'due_date',
        'difficulty',
        'status',
        'grade',
        'feedback',
        'submission_notes',
        'submission_file_path',
        'submission_file_name',
        'submitted_at',
        'graded_at',
    ];

    protected function casts(): array
    {
        return [
            'due_date' => 'datetime',
            'submitted_at' => 'datetime',
            'graded_at' => 'datetime',
        ];
    }

    /**
     * Get the teacher who assigned this assignment
     */
    public function teacher()
    {
        return $this->belongsTo(User::class, 'teacher_id');
    }

    /**
     * Get the student who received this assignment
     */
    public function student()
    {
        return $this->belongsTo(User::class, 'student_id');
    }

    /**
     * Get the reservation associated with this assignment
     */
    public function reservation()
    {
        return $this->belongsTo(Reservation::class);
    }

    /**
     * Scope for pending assignments
     */
    public function scopePending($query)
    {
        return $query->where('status', 'pending');
    }

    /**
     * Scope for submitted assignments
     */
    public function scopeSubmitted($query)
    {
        return $query->where('status', 'submitted');
    }

    /**
     * Scope for graded assignments
     */
    public function scopeGraded($query)
    {
        return $query->where('status', 'graded');
    }

    /**
     * Scope for overdue assignments
     */
    public function scopeOverdue($query)
    {
        return $query->where('status', 'pending')
                    ->where('due_date', '<', now());
    }

    /**
     * Scope for assignments by difficulty
     */
    public function scopeByDifficulty($query, string $difficulty)
    {
        return $query->where('difficulty', $difficulty);
    }

    /**
     * Scope for assignments given by specific teacher
     */
    public function scopeByTeacher($query, int $teacherId)
    {
        return $query->where('teacher_id', $teacherId);
    }

    /**
     * Scope for assignments given to specific student
     */
    public function scopeByStudent($query, int $studentId)
    {
        return $query->where('student_id', $studentId);
    }

    /**
     * Check if assignment is overdue
     */
    public function getIsOverdueAttribute(): bool
    {
        return $this->status === 'pending' && $this->due_date->isPast();
    }

    /**
     * Check if assignment is submitted
     */
    public function getIsSubmittedAttribute(): bool
    {
        return in_array($this->status, ['submitted', 'graded']);
    }

    /**
     * Check if assignment is graded
     */
    public function getIsGradedAttribute(): bool
    {
        return $this->status === 'graded' && !is_null($this->grade);
    }

    /**
     * Get difficulty in Turkish
     */
    public function getDifficultyInTurkishAttribute(): string
    {
        $difficulties = [
            'easy' => 'Kolay',
            'medium' => 'Orta',
            'hard' => 'Zor',
        ];

        return $difficulties[$this->difficulty] ?? $this->difficulty;
    }

    /**
     * Get status in Turkish
     */
    public function getStatusInTurkishAttribute(): string
    {
        $statuses = [
            'pending' => 'Bekliyor',
            'submitted' => 'Teslim Edildi',
            'graded' => 'Değerlendirildi',
            'overdue' => 'Gecikti',
        ];

        return $statuses[$this->status] ?? $this->status;
    }

    /**
     * Get time until due date
     */
    public function getTimeUntilDueAttribute(): ?string
    {
        if ($this->is_submitted || $this->is_graded) {
            return null;
        }

        $now = now();
        $dueDate = $this->due_date;

        if ($dueDate->isPast()) {
            return 'Gecikti';
        }

        $diff = $dueDate->diff($now);

        if ($diff->days > 0) {
            return "{$diff->days} gün kaldı";
        } elseif ($diff->h > 0) {
            return "{$diff->h} saat kaldı";
        } else {
            return "{$diff->i} dakika kaldı";
        }
    }

    /**
     * Get grade color
     */
    public function getGradeColorAttribute(): string
    {
        if (!$this->grade) {
            return 'grey';
        }

        $gradeColors = [
            'A+' => 'green',
            'A' => 'green',
            'B+' => 'lightgreen',
            'B' => 'lightgreen',
            'C+' => 'orange',
            'C' => 'orange',
            'D+' => 'red',
            'D' => 'red',
            'F' => 'darkred',
        ];

        return $gradeColors[$this->grade] ?? 'grey';
    }

    /**
     * Get time since assignment was created
     */
    public function getTimeSinceCreatedAttribute(): string
    {
        return $this->created_at->diffForHumans();
    }

    /**
     * Get time since assignment was submitted
     */
    public function getTimeSinceSubmittedAttribute(): ?string
    {
        return $this->submitted_at ? $this->submitted_at->diffForHumans() : null;
    }

    /**
     * Get time since assignment was graded
     */
    public function getTimeSinceGradedAttribute(): ?string
    {
        return $this->graded_at ? $this->graded_at->diffForHumans() : null;
    }

    /**
     * Update status to overdue if past due date
     */
    public function updateOverdueStatus(): void
    {
        if ($this->status === 'pending' && $this->due_date->isPast()) {
            $this->update(['status' => 'overdue']);
        }
    }
}
