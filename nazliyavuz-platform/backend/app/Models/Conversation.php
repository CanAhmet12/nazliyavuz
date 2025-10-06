<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Conversation extends Model
{
    use HasFactory;

    protected $fillable = [
        'user1_id',
        'user2_id',
        'reservation_id',
        'last_message_at',
        'last_message',
        'user1_deleted',
        'user2_deleted',
    ];

    protected $casts = [
        'user1_deleted' => 'boolean',
        'user2_deleted' => 'boolean',
        'last_message_at' => 'datetime',
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
     * Get the reservation
     */
    public function reservation()
    {
        return $this->belongsTo(Reservation::class);
    }

    /**
      * Get all messages in this conversation
     */
    public function messages()
    {
        return $this->hasMany(Message::class, 'chat_id');
    }

    /**
     * Get the other user in the conversation
     */
    public function getOtherUser(int $userId): ?User
    {
        if ($this->user1_id === $userId) {
            return $this->user2;
        } elseif ($this->user2_id === $userId) {
            return $this->user1;
        }
        
        return null;
    }

    /**
     * Update last message info
     */
    public function updateLastMessage(Message $message): void
    {
        $this->update([
            'last_message_at' => $message->created_at,
            'last_message' => $message->content,
        ]);
    }

    /**
     * Get conversation title for display
     */
    public function getTitleForUser(int $userId): string
    {
        $otherUser = $this->getOtherUser($userId);
        
        if (!$otherUser) {
            return 'Bilinmeyen Kullanıcı';
        }

        // If other user is a teacher, show their name
        if ($otherUser->role === 'teacher') {
            return $otherUser->name;
        }

        // If other user is a student, show their name
        return $otherUser->name;
    }

    /**
     * Get conversation avatar for display
     */
    public function getAvatarForUser(int $userId): ?string
    {
        $otherUser = $this->getOtherUser($userId);
        
        if (!$otherUser) {
            return null;
        }

        return $otherUser->profile_photo_url;
    }

    /**
     * Get message type label
     */
    public function getMessageTypeLabel(string $messageType): string
    {
        $typeLabels = [
            'text' => 'Mesaj',
            'image' => '📷 Resim',
            'file' => '📎 Dosya',
            'audio' => '🎵 Ses',
            'video' => '🎥 Video',
        ];
        
        return $typeLabels[$messageType] ?? 'Mesaj';
    }

    /**
     * Get unread message count for a user
     */
    public function getUnreadCountForUser(int $userId): int
    {
        return Message::where(function ($query) use ($userId) {
            $query->where('sender_id', $this->user1_id)
                  ->where('receiver_id', $this->user2_id)
                  ->orWhere('sender_id', $this->user2_id)
                  ->where('receiver_id', $this->user1_id);
        })
        ->where('receiver_id', $userId)
        ->where('is_read', false)
        ->where('is_deleted', false)
        ->count();
    }

    /**
     * Mark all messages as read for a user
     */
    public function markAllAsReadForUser(int $userId): void
    {
        Message::where(function ($query) use ($userId) {
            $query->where('sender_id', $this->user1_id)
                  ->where('receiver_id', $this->user2_id)
                  ->orWhere('sender_id', $this->user2_id)
                  ->where('receiver_id', $this->user1_id);
        })
        ->where('receiver_id', $userId)
        ->where('is_read', false)
        ->update([
            'is_read' => true,
            'read_at' => now(),
        ]);
    }

    /**
     * Soft delete conversation for a user
     */
    public function deleteForUser(int $userId): void
    {
        if ($this->user1_id === $userId) {
            $this->update(['user1_deleted' => true]);
        } elseif ($this->user2_id === $userId) {
            $this->update(['user2_deleted' => true]);
        }
    }

    /**
     * Check if conversation is deleted for user
     */
    public function isDeletedForUser(int $userId): bool
    {
        if ($this->user1_id === $userId) {
            return $this->user1_deleted;
        } elseif ($this->user2_id === $userId) {
            return $this->user2_deleted;
        }
        
        return false;
    }

    /**
     * Scope to get conversations for a user
     */
    public function scopeForUser($query, int $userId)
    {
        return $query->where(function ($q) use ($userId) {
            $q->where('user1_id', $userId)->where('user1_deleted', false)
              ->orWhere('user2_id', $userId)->where('user2_deleted', false);
        })->orderBy('last_message_at', 'desc');
    }
}