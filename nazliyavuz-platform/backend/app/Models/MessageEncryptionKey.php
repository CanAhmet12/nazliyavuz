<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class MessageEncryptionKey extends Model
{
    use HasFactory;

    protected $fillable = [
        'key_id',
        'chat_id',
        'public_key',
        'private_key_encrypted',
        'is_active',
        'expires_at',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'expires_at' => 'datetime',
    ];

    /**
     * Get the chat that owns the encryption key.
     */
    public function chat()
    {
        return $this->belongsTo(Chat::class);
    }

    /**
     * Scope for active keys.
     */
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    /**
     * Scope for non-expired keys.
     */
    public function scopeNotExpired($query)
    {
        return $query->where(function ($q) {
            $q->whereNull('expires_at')
              ->orWhere('expires_at', '>', now());
        });
    }

    /**
     * Check if key is expired.
     */
    public function isExpired()
    {
        return $this->expires_at && $this->expires_at->isPast();
    }

    /**
     * Generate new encryption key.
     */
    public static function generateKey($chatId)
    {
        $keyId = 'key_' . uniqid();
        
        // Generate RSA key pair (simplified)
        $config = [
            'digest_alg' => 'sha256',
            'private_key_bits' => 2048,
            'private_key_type' => OPENSSL_KEYTYPE_RSA,
        ];
        
        $res = openssl_pkey_new($config);
        openssl_pkey_export($res, $privateKey);
        $publicKey = openssl_pkey_get_details($res)['key'];
        
        return self::create([
            'key_id' => $keyId,
            'chat_id' => $chatId,
            'public_key' => $publicKey,
            'private_key_encrypted' => encrypt($privateKey),
            'is_active' => true,
            'expires_at' => now()->addDays(30),
        ]);
    }
}
