<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ExperimentAssignment extends Model
{
    use HasFactory;

    protected $fillable = [
        'experiment_id',
        'variant_id',
        'user_id',
        'session_id',
        'context',
        'assigned_at',
        'converted_at',
        'conversion_value',
        'meta',
    ];

    protected function casts(): array
    {
        return [
            'assigned_at' => 'datetime',
            'converted_at' => 'datetime',
            'conversion_value' => 'decimal:2',
            'meta' => 'array',
        ];
    }

    public function experiment(): BelongsTo
    {
        return $this->belongsTo(Experiment::class);
    }

    public function variant(): BelongsTo
    {
        return $this->belongsTo(ExperimentVariant::class, 'variant_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}

