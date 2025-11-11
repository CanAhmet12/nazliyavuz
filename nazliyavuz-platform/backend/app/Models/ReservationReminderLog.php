<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ReservationReminderLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'reservation_id',
        'reminder_setting_id',
        'channels',
        'source',
        'sent_at',
    ];

    protected $casts = [
        'channels' => 'array',
        'sent_at' => 'datetime',
    ];

    public function reservation(): BelongsTo
    {
        return $this->belongsTo(Reservation::class);
    }

    public function setting(): BelongsTo
    {
        return $this->belongsTo(ReservationReminderSetting::class, 'reminder_setting_id');
    }
}

