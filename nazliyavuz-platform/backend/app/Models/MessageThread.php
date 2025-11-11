<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class MessageThread extends Model
{
    use HasFactory;

    protected $fillable = [
        'chat_id',
        'root_message_id',
        'thread_title',
        'is_active',
        'message_count',
        'last_activity_at',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'last_activity_at' => 'datetime',
    ];

    /**
     * Get the chat that owns the thread.
     */
    public function chat()
    {
        return $this->belongsTo(Chat::class);
    }

    /**
     * Get the root message of the thread.
     */
    public function rootMessage()
    {
        return $this->belongsTo(Message::class, 'root_message_id');
    }

    /**
     * Get all messages in this thread.
     */
    public function messages()
    {
        return $this->hasMany(Message::class, 'thread_id', 'id')
            ->orderBy('created_at');
    }

    /**
     * Get the latest message in the thread.
     */
    public function latestMessage()
    {
        return $this->hasOne(Message::class, 'thread_id', 'id')
            ->latest();
    }

    /**
     * Scope for active threads.
     */
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    /**
     * Update thread activity.
     */
    public function updateActivity()
    {
        $this->update([
            'last_activity_at' => now(),
            'message_count' => $this->messages()->count(),
        ]);
    }
}
