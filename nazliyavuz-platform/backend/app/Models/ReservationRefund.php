<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ReservationRefund extends Model
{
    use HasFactory;

    protected $fillable = [
        'reservation_id',
        'payment_id',
        'amount',
        'currency',
        'status',
        'reason',
        'notify_participants',
        'cancel_reservation',
        'attempts',
        'max_attempts',
        'last_attempt_at',
        'processed_at',
        'failure_code',
        'failure_message',
        'provider_name',
        'provider_reference',
        'provider_payload',
        'provider_response',
        'meta',
        'created_by',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'notify_participants' => 'boolean',
            'cancel_reservation' => 'boolean',
            'attempts' => 'integer',
            'max_attempts' => 'integer',
            'provider_payload' => 'array',
            'provider_response' => 'array',
            'meta' => 'array',
            'last_attempt_at' => 'datetime',
            'processed_at' => 'datetime',
        ];
    }

    public function reservation(): BelongsTo
    {
        return $this->belongsTo(Reservation::class);
    }

    public function payment(): BelongsTo
    {
        return $this->belongsTo(Payment::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}

