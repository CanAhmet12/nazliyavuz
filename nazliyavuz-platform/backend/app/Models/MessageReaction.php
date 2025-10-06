<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class MessageReaction extends Model
{
    use HasFactory;

    protected $fillable = [
        'message_id',
        'user_id',
        'reaction_type',
        'emoji',
    ];

    /**
     * Get the message this reaction belongs to
     */
    public function message()
    {
        return $this->belongsTo(Message::class);
    }

    /**
     * Get the user who made this reaction
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Scope for reactions by type
     */
    public function scopeByType($query, $type)
    {
        return $query->where('reaction_type', $type);
    }

    /**
     * Scope for reactions by emoji
     */
    public function scopeByEmoji($query, $emoji)
    {
        return $query->where('emoji', $emoji);
    }
}