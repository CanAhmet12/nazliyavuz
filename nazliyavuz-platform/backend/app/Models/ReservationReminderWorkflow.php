<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ReservationReminderWorkflow extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'slug',
        'description',
        'status',
        'target_statuses',
        'target_roles',
        'meta',
        'created_by',
        'updated_by',
    ];

    protected $casts = [
        'target_statuses' => 'array',
        'target_roles' => 'array',
        'meta' => 'array',
    ];

    public function steps(): HasMany
    {
        return $this->hasMany(ReservationReminderSetting::class, 'workflow_id')
            ->orderBy('step_order');
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function updater(): BelongsTo
    {
        return $this->belongsTo(User::class, 'updated_by');
    }
}

