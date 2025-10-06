<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;
use Carbon\Carbon;

class EmailVerification extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'token',
        'verification_code',
        'expires_at',
        'verified_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'verified_at' => 'datetime',
    ];

    /**
     * Get the user that owns the verification
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Create a new verification token for user
     */
    public static function createForUser(User $user): self
    {
        // Eski tokenları temizle
        self::where('user_id', $user->id)->delete();

        // 6 haneli doğrulama kodu oluştur
        $verificationCode = str_pad(random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        return self::create([
            'user_id' => $user->id,
            'token' => Str::random(64),
            'verification_code' => $verificationCode,
            'expires_at' => Carbon::now()->addMinutes(15), // 15 dakika geçerli
        ]);
    }

    /**
     * Verify the token
     */
    public function verify(): bool
    {
        if ($this->isExpired() || $this->verified_at) {
            return false;
        }

        $this->update(['verified_at' => Carbon::now()]);
        
        // User'ın email_verified_at'ini güncelle
        $this->user->update(['email_verified_at' => Carbon::now()]);

        return true;
    }

    /**
     * Check if token is expired
     */
    public function isExpired(): bool
    {
        return $this->expires_at->isPast();
    }

    /**
     * Check if token is verified
     */
    public function isVerified(): bool
    {
        return !is_null($this->verified_at);
    }

    /**
     * Verify with 6-digit code
     */
    public function verifyWithCode(string $code): bool
    {
        \Log::info("🔍 EmailVerification::verifyWithCode called with code: " . $code);
        \Log::info("🔍 Current verification_code: " . $this->verification_code);
        \Log::info("🔍 Is expired: " . ($this->isExpired() ? 'YES' : 'NO'));
        \Log::info("🔍 Already verified: " . ($this->verified_at ? 'YES' : 'NO'));
        
        if ($this->isExpired()) {
            \Log::error("❌ Verification code expired");
            return false;
        }

        if ($this->verification_code !== $code) {
            \Log::error("❌ Verification code mismatch");
            return false;
        }

        // Zaten doğrulanmışsa da true döndür
        if ($this->verified_at) {
            \Log::info("✅ Already verified, updating user email_verified_at");
            // User'ın email_verified_at'ini kontrol et ve güncelle
            if (!$this->user->email_verified_at) {
                $this->user->update(['email_verified_at' => Carbon::now()]);
                $this->user->refresh(); // User model'ini yeniden yükle
                \Log::info("✅ User email_verified_at updated");
            }
            return true;
        }

        \Log::info("🔄 Updating verification record");
        $this->update(['verified_at' => Carbon::now()]);
        
        \Log::info("🔄 Updating user email_verified_at");
        // User'ın email_verified_at'ini güncelle
        $this->user->update(['email_verified_at' => Carbon::now()]);
        $this->user->refresh(); // User model'ini yeniden yükle
        
        \Log::info("✅ Verification completed successfully");

        return true;
    }

    /**
     * Find verification by code
     */
    public static function findByCode(string $code): ?self
    {
        return self::where('verification_code', $code)
            ->where('expires_at', '>', Carbon::now())
            ->first(); // verified_at kontrolünü kaldırdık
    }
}
