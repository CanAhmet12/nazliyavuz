<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class MessageTranslation extends Model
{
    use HasFactory;

    protected $fillable = [
        'message_id',
        'language_code',
        'translated_content',
        'translation_service',
        'confidence_score',
    ];

    protected $casts = [
        'confidence_score' => 'decimal:2',
    ];

    /**
     * Get the message that owns the translation.
     */
    public function message()
    {
        return $this->belongsTo(Message::class);
    }

    /**
     * Scope for specific language.
     */
    public function scopeForLanguage($query, $languageCode)
    {
        return $query->where('language_code', $languageCode);
    }

    /**
     * Scope for high confidence translations.
     */
    public function scopeHighConfidence($query, $threshold = 0.8)
    {
        return $query->where('confidence_score', '>=', $threshold);
    }

    /**
     * Get available languages for a message.
     */
    public static function getAvailableLanguages($messageId)
    {
        return self::where('message_id', $messageId)
            ->pluck('language_code')
            ->toArray();
    }

    /**
     * Translate message content.
     */
    public static function translateMessage($messageId, $targetLanguage, $content)
    {
        // This would integrate with translation services like Google Translate
        // For now, return a placeholder
        return self::create([
            'message_id' => $messageId,
            'language_code' => $targetLanguage,
            'translated_content' => "Translated: " . $content,
            'translation_service' => 'google_translate',
            'confidence_score' => 0.95,
        ]);
    }
}
