<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Chat extends Model
{
    use HasFactory;

    protected $fillable = [
        'user1_id',
        'user2_id',
        'last_message_id',
        'last_message_at',
        'user1_deleted',
        'user2_deleted',
        'updated_at',
    ];

    /**
     * Get the first user
     */
    public function user1()
    {
        return $this->belongsTo(User::class, 'user1_id');
    }

    /**
     * Get the second user
     */
    public function user2()
    {
        return $this->belongsTo(User::class, 'user2_id');
    }

    /**
     * Get the messages for this chat
     */
    public function messages()
    {
        return $this->hasMany(Message::class, 'chat_id')->orderBy('created_at', 'asc');
    }

    /**
     * Get the last message
     */
    public function lastMessage()
    {
        return $this->belongsTo(Message::class, 'last_message_id');
    }

    /**
     * Check if user is part of this chat
     */
    public function hasUser($userId)
    {
        return $this->user1_id === $userId || $this->user2_id === $userId;
    }

    /**
     * Get the other user in the chat
     */
    public function getOtherUser($userId)
    {
        if ($this->user1_id === $userId) {
            return $this->user2;
        } elseif ($this->user2_id === $userId) {
            return $this->user1;
        }
        
        return null;
    }
}
