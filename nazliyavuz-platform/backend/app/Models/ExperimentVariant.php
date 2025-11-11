<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ExperimentVariant extends Model
{
    use HasFactory;

    protected $fillable = [
        'experiment_id',
        'name',
        'key',
        'is_control',
        'traffic_allocation',
        'meta',
    ];

    protected function casts(): array
    {
        return [
            'is_control' => 'boolean',
            'traffic_allocation' => 'integer',
            'meta' => 'array',
        ];
    }

    public function experiment(): BelongsTo
    {
        return $this->belongsTo(Experiment::class);
    }

    public function assignments(): HasMany
    {
        return $this->hasMany(ExperimentAssignment::class, 'variant_id');
    }
}

