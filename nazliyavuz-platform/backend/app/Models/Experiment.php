<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Experiment extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'key',
        'status',
        'type',
        'traffic_allocation',
        'target_filters',
        'hypothesis',
        'success_metric',
        'starts_at',
        'ends_at',
        'meta',
        'created_by',
        'updated_by',
    ];

    protected function casts(): array
    {
        return [
            'traffic_allocation' => 'integer',
            'target_filters' => 'array',
            'meta' => 'array',
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
        ];
    }

    public function variants(): HasMany
    {
        return $this->hasMany(ExperimentVariant::class);
    }

    public function assignments(): HasMany
    {
        return $this->hasMany(ExperimentAssignment::class);
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

