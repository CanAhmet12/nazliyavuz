<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Carbon\Carbon;

/**
 * TeacherException Model
 * 
 * Öğretmenlerin özel günlerini ve istisnaları yönetir
 * - Tatil günleri
 * - İzinli günler
 * - Özel saatler (haftalık takvimi override eder)
 */
class TeacherException extends Model
{
    use HasFactory;

    protected $fillable = [
        'teacher_id',
        'exception_date',
        'type',
        'start_time',
        'end_time',
        'reason',
        'notes',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'exception_date' => 'date',
            'start_time' => 'datetime:H:i',
            'end_time' => 'datetime:H:i',
            'is_active' => 'boolean',
        ];
    }

    /**
     * Relationship: Teacher
     */
    public function teacher()
    {
        return $this->belongsTo(Teacher::class);
    }

    /**
     * Scope: Active exceptions
     */
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    /**
     * Scope: Unavailable days
     */
    public function scopeUnavailable($query)
    {
        return $query->where('type', 'unavailable');
    }

    /**
     * Scope: Custom hours days
     */
    public function scopeCustomHours($query)
    {
        return $query->where('type', 'custom_hours');
    }

    /**
     * Scope: Future exceptions
     */
    public function scopeFuture($query)
    {
        return $query->where('exception_date', '>=', Carbon::today());
    }

    /**
     * Scope: Past exceptions
     */
    public function scopePast($query)
    {
        return $query->where('exception_date', '<', Carbon::today());
    }

    /**
     * Scope: By date
     */
    public function scopeByDate($query, $date)
    {
        return $query->where('exception_date', $date);
    }

    /**
     * Check if this is an unavailable day
     */
    public function isUnavailable(): bool
    {
        return $this->type === 'unavailable' && $this->is_active;
    }

    /**
     * Check if this is a custom hours day
     */
    public function hasCustomHours(): bool
    {
        return $this->type === 'custom_hours' && $this->is_active;
    }

    /**
     * Get formatted date
     */
    public function getFormattedDateAttribute(): string
    {
        return $this->exception_date->format('d M Y');
    }

    /**
     * Get formatted time range (for custom hours)
     */
    public function getFormattedTimeRangeAttribute(): ?string
    {
        if ($this->type !== 'custom_hours') {
            return null;
        }

        return $this->start_time?->format('H:i') . ' - ' . $this->end_time?->format('H:i');
    }

    /**
     * Get display text
     */
    public function getDisplayTextAttribute(): string
    {
        if ($this->isUnavailable()) {
            return $this->reason ?? 'Müsait değil';
        }

        if ($this->hasCustomHours()) {
            return ($this->reason ?? 'Özel saatler') . ' (' . $this->formatted_time_range . ')';
        }

        return 'Özel durum';
    }
}

