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
        'payment_status',
        'payment_method',
        'payment_transaction_id',
        'paid_at',
        'refund_amount',
        'refund_reason',
        'refunded_at',
        'cancelled_by_id',
        'cancelled_reason',
        'cancelled_at',
        'cancellation_fee',
        'reminder_sent',
        'reminder_sent_at',
        'reminder_count',
        'rating_id',
        'rated_at',
        'rating_requested_at',
    ];

    protected function casts(): array
    {
        return [
            'proposed_datetime' => 'datetime',
            'price' => 'decimal:2',
            'paid_at' => 'datetime',
            'refunded_at' => 'datetime',
            'cancelled_at' => 'datetime',
            'reminder_sent' => 'boolean',
            'reminder_sent_at' => 'datetime',
            'rated_at' => 'datetime',
            'rating_requested_at' => 'datetime',
            'refund_amount' => 'decimal:2',
            'cancellation_fee' => 'decimal:2',
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
        return $this->belongsTo(User::class, 'teacher_id');
    }

    /**
     * Get the category for the reservation
     */
    public function category()
    {
        return $this->belongsTo(Category::class);
    }

    /**
     * Get payments associated with the reservation
     */
    public function payments()
    {
        return $this->hasMany(Payment::class);
    }

    /**
     * Get refunds associated with the reservation
     */
    public function refunds()
    {
        return $this->hasMany(ReservationRefund::class);
    }

    /**
     * Get lessons associated with the reservation
     */
    public function lessons()
    {
        return $this->hasMany(Lesson::class);
    }

    /**
     * Get reminder logs associated with the reservation
     */
    public function reminderLogs()
    {
        return $this->hasMany(ReservationReminderLog::class);
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

    /**
     * Get the user who cancelled the reservation
     */
    public function cancelledBy()
    {
        return $this->belongsTo(User::class, 'cancelled_by_id');
    }

    /**
     * Get the rating for this reservation
     */
    public function rating()
    {
        return $this->belongsTo(Rating::class);
    }

    /**
     * Check if payment is completed
     */
    public function isPaid(): bool
    {
        return $this->payment_status === 'paid';
    }

    /**
     * Check if refunded
     */
    public function isRefunded(): bool
    {
        return in_array($this->payment_status, ['refunded', 'partial_refund']);
    }

    /**
     * Check if rated
     */
    public function isRated(): bool
    {
        return !is_null($this->rating_id) && !is_null($this->rated_at);
    }

    /**
     * Calculate cancellation fee based on policy
     * - 24+ hours before: No fee (full refund)
     * - 6-24 hours: 50% fee
     * - <6 hours: 100% fee (no refund)
     */
    public function calculateCancellationFee(): array
    {
        if ($this->status !== 'cancelled' && !$this->isUpcoming()) {
            return ['fee' => 0, 'refund' => 0, 'policy' => 'no_refund'];
        }

        $hoursUntilStart = now()->diffInHours($this->proposed_datetime, false);

        if ($hoursUntilStart >= 24) {
            // Full refund
            return [
                'fee' => 0,
                'refund' => $this->price,
                'refund_percentage' => 100,
                'policy' => 'full_refund'
            ];
        } elseif ($hoursUntilStart >= 6) {
            // 50% refund
            $fee = $this->price * 0.5;
            $refund = $this->price * 0.5;
            return [
                'fee' => $fee,
                'refund' => $refund,
                'refund_percentage' => 50,
                'policy' => 'partial_refund'
            ];
        } else {
            // No refund
            return [
                'fee' => $this->price,
                'refund' => 0,
                'refund_percentage' => 0,
                'policy' => 'no_refund'
            ];
        }
    }
}