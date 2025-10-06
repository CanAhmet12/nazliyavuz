<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AuditLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'action',
        'target_type',
        'target_id',
        'meta',
        'ip_address',
        'user_agent',
    ];

    protected function casts(): array
    {
        return [
            'meta' => 'array',
        ];
    }

    /**
     * Get the user that performed the action
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Get the target model
     */
    public function target()
    {
        return $this->morphTo('target', 'target_type', 'target_id');
    }

    /**
     * Scope for specific action
     */
    public function scopeAction($query, $action)
    {
        return $query->where('action', $action);
    }

    /**
     * Scope for specific target type
     */
    public function scopeTargetType($query, $targetType)
    {
        return $query->where('target_type', $targetType);
    }

    /**
     * Scope for specific user
     */
    public function scopeForUser($query, $userId)
    {
        return $query->where('user_id', $userId);
    }

    /**
     * Scope for recent logs
     */
    public function scopeRecent($query, $days = 7)
    {
        return $query->where('created_at', '>=', now()->subDays($days));
    }

    /**
     * Get formatted action
     */
    public function getFormattedActionAttribute()
    {
        $actions = [
            'created' => 'Oluşturuldu',
            'updated' => 'Güncellendi',
            'deleted' => 'Silindi',
            'login' => 'Giriş Yapıldı',
            'logout' => 'Çıkış Yapıldı',
            'registered' => 'Kayıt Olundu',
        ];

        return $actions[$this->action] ?? $this->action;
    }

    /**
     * Get formatted target type
     */
    public function getFormattedTargetTypeAttribute()
    {
        $types = [
            'App\Models\User' => 'Kullanıcı',
            'App\Models\Teacher' => 'Öğretmen',
            'App\Models\Reservation' => 'Rezervasyon',
            'App\Models\Category' => 'Kategori',
            'App\Models\Rating' => 'Değerlendirme',
        ];

        return $types[$this->target_type] ?? $this->target_type;
    }

    /**
     * Create a new audit log entry
     */
    public static function createLog(
        ?int $userId,
        string $action,
        string $targetType,
        int $targetId,
        ?array $meta = null,
        ?string $ipAddress = null,
        ?string $userAgent = null
    ): self {
        return self::create([
            'user_id' => $userId,
            'action' => $action,
            'target_type' => $targetType,
            'target_id' => $targetId,
            'meta' => $meta,
            'ip_address' => $ipAddress,
            'user_agent' => $userAgent,
        ]);
    }

    /**
     * Get formatted action description
     */
    public function getFormattedAction(): string
    {
        $actions = [
            'create_user' => 'Kullanıcı Oluşturuldu',
            'update_user' => 'Kullanıcı Güncellendi',
            'delete_user' => 'Kullanıcı Silindi',
            'update_user_status' => 'Kullanıcı Durumu Güncellendi',
            'create_teacher' => 'Öğretmen Profili Oluşturuldu',
            'update_teacher' => 'Öğretmen Profili Güncellendi',
            'create_reservation' => 'Rezervasyon Oluşturuldu',
            'update_reservation' => 'Rezervasyon Güncellendi',
            'create_category' => 'Kategori Oluşturuldu',
            'update_category' => 'Kategori Güncellendi',
            'delete_category' => 'Kategori Silindi',
            'create_rating' => 'Değerlendirme Oluşturuldu',
            'update_rating' => 'Değerlendirme Güncellendi',
            'delete_rating' => 'Değerlendirme Silindi',
            'login' => 'Giriş Yapıldı',
            'logout' => 'Çıkış Yapıldı',
            'password_reset' => 'Şifre Sıfırlandı',
            'email_verified' => 'E-posta Doğrulandı',
        ];

        return $actions[$this->action] ?? $this->action;
    }

    /**
     * Get formatted target description
     */
    public function getFormattedTarget(): string
    {
        $targets = [
            'User' => 'Kullanıcı',
            'Teacher' => 'Öğretmen',
            'Reservation' => 'Rezervasyon',
            'Category' => 'Kategori',
            'Rating' => 'Değerlendirme',
        ];

        return $targets[$this->target_type] ?? $this->target_type;
    }
}