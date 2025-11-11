<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class MessageMention extends Model
{
    use HasFactory;

    protected $fillable = [
        'message_id',
        'mentioned_user_id',
        'position',
    ];

    /**
     * Get the message that owns the mention.
     */
    public function message()
    {
        return $this->belongsTo(Message::class);
    }

    /**
     * Get the mentioned user.
     */
    public function mentionedUser()
    {
        return $this->belongsTo(User::class, 'mentioned_user_id');
    }

    /**
     * Scope for mentions by user.
     */
    public function scopeForUser($query, $userId)
    {
        return $query->where('mentioned_user_id', $userId);
    }

    /**
     * Scope for mentions in message.
     */
    public function scopeInMessage($query, $messageId)
    {
        return $query->where('message_id', $messageId);
    }
}
