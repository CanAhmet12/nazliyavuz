<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Tymon\JWTAuth\Contracts\JWTSubject;

class User extends Authenticatable implements JWTSubject
{
    use HasFactory, Notifiable;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
        'role',
        'phone',
        'bio',
        'profile_photo_url',
        'verified_at',
        'email_verified_at',
        'fcm_tokens',
        'suspended_at',
        'suspended_until',
        'suspension_reason',
        'last_login_at',
        'teacher_status',
        'admin_notes',
        'approved_by',
        'approved_at',
        'rejection_reason',
        'status',
        'email_notifications',
        'push_notifications',
        'lesson_reminders',
        'marketing_emails',
        'suspended_reason',
        'suspended_by',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'verified_at' => 'datetime',
            'suspended_at' => 'datetime',
            'suspended_until' => 'datetime',
            'last_login_at' => 'datetime',
            'approved_at' => 'datetime',
            'password' => 'hashed',
            'fcm_tokens' => 'array',
        ];
    }

    /**
     * Get the identifier that will be stored in the subject claim of the JWT.
     */
    public function getJWTIdentifier()
    {
        return $this->getKey();
    }

    /**
     * Return a key value array, containing any custom claims to be added to the JWT.
     */
    public function getJWTCustomClaims()
    {
        return [];
    }

    /**
     * Check if user is a teacher
     */
    public function isTeacher(): bool
    {
        return $this->role === 'teacher';
    }

    /**
     * Check if user is a student
     */
    public function isStudent(): bool
    {
        return $this->role === 'student';
    }

    /**
     * Check if user is an admin
     */
    public function isAdmin(): bool
    {
        return $this->role === 'admin';
    }

    /**
     * Determine if the user can perform admin actions
     */
    public function canAdmin(): bool
    {
        return $this->isAdmin();
    }

    /**
     * Get the teacher profile
     */
    public function teacher()
    {
        return $this->hasOne(Teacher::class, 'user_id');
    }

    /**
     * Get reservations as student
     */
    public function studentReservations()
    {
        return $this->hasMany(Reservation::class, 'student_id');
    }

    /**
     * Get reservations as teacher
     */
    public function teacherReservations()
    {
        return $this->hasMany(Reservation::class, 'teacher_id');
    }

    /**
     * Get all reservations for user (as student or teacher)
     */
    public function reservations()
    {
        return Reservation::where(function ($query) {
            $query->where('student_id', $this->id)
                  ->orWhere('teacher_id', $this->id);
        });
    }

    /**
     * Get social accounts
     */
    public function socialAccounts()
    {
        return $this->hasMany(SocialAccount::class);
    }

    /**
     * Check if user is suspended
     */
    public function isSuspended(): bool
    {
        if (!$this->suspended_at) {
            return false;
        }

        if ($this->suspended_until && $this->suspended_until->isPast()) {
            // Auto-unsuspend if suspension period has expired
            $this->update([
                'suspended_at' => null,
                'suspended_until' => null,
                'suspension_reason' => null,
            ]);
            return false;
        }

        return true;
    }

    /**
     * Check if teacher is approved
     */
    public function isTeacherApproved(): bool
    {
        return $this->role === 'teacher' && $this->teacher_status === 'approved';
    }

    /**
     * Check if teacher is pending approval
     */
    public function isTeacherPending(): bool
    {
        return $this->role === 'teacher' && $this->teacher_status === 'pending';
    }

    /**
     * Check if teacher is rejected
     */
    public function isTeacherRejected(): bool
    {
        return $this->role === 'teacher' && $this->teacher_status === 'rejected';
    }

    /**
     * Approve teacher
     */
    public function approveTeacher(int $adminId, ?string $notes = null): void
    {
        $this->update([
            'teacher_status' => 'approved',
            'approved_by' => $adminId,
            'approved_at' => now(),
            'admin_notes' => $notes,
        ]);

        // Teacher tablosunu da güncelle (sadece approved_at ve approved_by)
        if ($this->teacher) {
            $this->teacher->update([
                'approved_at' => now(),
                'approved_by' => $adminId,
            ]);
        }
    }

    /**
     * Reject teacher
     */
    public function rejectTeacher(int $adminId, string $reason, ?string $notes = null): void
    {
        $this->update([
            'teacher_status' => 'rejected',
            'approved_by' => $adminId,
            'approved_at' => now(),
            'rejection_reason' => $reason,
            'admin_notes' => $notes,
        ]);
    }

    /**
     * Check if user is active (not suspended and verified)
     */
    public function isActive(): bool
    {
        return $this->verified_at && !$this->isSuspended();
    }

    /**
     * Get favorite teachers
     */
    public function favoriteTeachers()
    {
        return $this->belongsToMany(User::class, 'favorites', 'user_id', 'teacher_id')
                    ->withTimestamps();
    }

    /**
     * Get notifications
     */
    public function notifications()
    {
        return $this->hasMany(Notification::class);
    }

    /**
     * Get audit logs
     */
    public function auditLogs()
    {
        return $this->hasMany(AuditLog::class);
    }

}
