<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Carbon\Carbon;

class TeacherCertification extends Model
{
    use HasFactory;

    protected $fillable = [
        'teacher_id',
        'title',
        'issuer',
        'issue_date',
        'expiry_date',
        'certificate_url',
        'status',
        'verified_at',
    ];

    protected $casts = [
        'issue_date' => 'date',
        'expiry_date' => 'date',
        'verified_at' => 'datetime',
    ];

    /**
     * Get the teacher that owns the certification
     */
    public function teacher(): BelongsTo
    {
        return $this->belongsTo(User::class, 'teacher_id');
    }

    /**
     * Check if certification is verified
     */
    public function isVerified(): bool
    {
        return $this->status === 'verified' && !is_null($this->verified_at);
    }

    /**
     * Check if certification is expired
     */
    public function isExpired(): bool
    {
        return $this->expiry_date && $this->expiry_date instanceof Carbon && $this->expiry_date->isPast();
    }

    /**
     * Verify certification
     */
    public function verify(): void
    {
        $this->update([
            'status' => 'verified',
            'verified_at' => now(),
        ]);
    }

    /**
     * Reject certification
     */
    public function reject(): void
    {
        $this->update([
            'status' => 'rejected',
            'verified_at' => null,
        ]);
    }
}
