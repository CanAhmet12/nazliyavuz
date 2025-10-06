<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Reservation extends Model
{
    use HasFactory;

    protected $fillable = [
        'student_id',
        'teacher_id',
        'category_id',
        'subject',
        'proposed_datetime',
        'duration_minutes',
        'price',
        'status',
        'notes',
        'teacher_notes',
        'admin_notes',
    ];

    protected function casts(): array
    {
        return [
            'proposed_datetime' => 'datetime',
            'price' => 'decimal:2',
        ];
    }

    /**
     * Get the student who made the reservation
     */
    public function student()
    {
        return $this->belongsTo(User::class, 'student_id');
    }

    /**
     * Get the teacher for the reservation
     */
    public function teacher()
    {
        return $this->belongsTo(Teacher::class, 'teacher_id', 'user_id');
    }

    /**
     * Get the category for the reservation
     */
    public function category()
    {
        return $this->belongsTo(Category::class);
    }

    /**
     * Scope for pending reservations
     */
    public function scopePending($query)
    {
        return $query->where('status', 'pending');
    }

    /**
     * Scope for accepted reservations
     */
    public function scopeAccepted($query)
    {
        return $query->where('status', 'accepted');
    }

    /**
     * Scope for completed reservations
     */
    public function scopeCompleted($query)
    {
        return $query->where('status', 'completed');
    }

    /**
     * Scope for upcoming reservations
     */
    public function scopeUpcoming($query)
    {
        return $query->where('proposed_datetime', '>', now());
    }

    /**
     * Scope for past reservations
     */
    public function scopePast($query)
    {
        return $query->where('proposed_datetime', '<', now());
    }

    /**
     * Get formatted duration
     */
    public function getFormattedDurationAttribute()
    {
        $hours = floor($this->duration_minutes / 60);
        $minutes = $this->duration_minutes % 60;
        
        if ($hours > 0) {
            return $minutes > 0 ? "{$hours}sa {$minutes}dk" : "{$hours}sa";
        }
        
        return "{$minutes}dk";
    }

    /**
     * Get formatted price
     */
    public function getFormattedPriceAttribute()
    {
        return number_format((float) $this->price, 2) . ' TL';
    }

    /**
     * Check if reservation is upcoming
     */
    public function isUpcoming(): bool
    {
        return $this->proposed_datetime > now();
    }

    /**
     * Check if reservation is past
     */
    public function isPast(): bool
    {
        return $this->proposed_datetime < now();
    }

    /**
     * Check if reservation can be cancelled
     */
    public function canBeCancelled(): bool
    {
        return in_array($this->status, ['pending', 'accepted']) && $this->isUpcoming();
    }
}