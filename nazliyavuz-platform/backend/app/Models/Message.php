<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Message extends Model
{
    use HasFactory;

    protected $fillable = [
        'chat_id',
        'sender_id',
        'receiver_id',
        'reservation_id',
        'content',
        'message_type',
        'file_url',
        'file_name',
        'file_size',
        'file_type',
        'is_read',
        'read_at',
        'is_deleted',
        'deleted_at',
        // Advanced features
        'parent_message_id',
        'thread_id',
        'mentions',
        'reply_to_message_id',
        'forwarded_from_message_id',
        'forwarded_from_user_id',
        'forwarded_at',
        'is_pinned',
        'pinned_at',
        'pinned_by',
        'original_content',
        'edited_at',
        'edit_count',
        'translations',
        'original_language',
        'is_encrypted',
        'encryption_key_id',
        'message_status',
        'delivered_at',
        'metadata',
    ];

    protected $visible = [
        'id',
        'chat_id',
        'sender_id',
        'receiver_id',
        'content',
        'message_type',
        'file_url',
        'file_name',
        'file_size',
        'file_type',
        'is_read',
        'read_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'is_read' => 'boolean',
        'is_deleted' => 'boolean',
        'read_at' => 'datetime',
        'deleted_at' => 'datetime',
        'mentions' => 'array',
        'forwarded_at' => 'datetime',
        'is_pinned' => 'boolean',
        'pinned_at' => 'datetime',
        'edited_at' => 'datetime',
        'translations' => 'array',
        'is_encrypted' => 'boolean',
        'delivered_at' => 'datetime',
        'metadata' => 'array',
    ];

    /**
     * Get the chat this message belongs to
     */
    public function chat()
    {
        return $this->belongsTo(Chat::class, 'chat_id');
    }

    /**
     * Get the user who sent this message
     */
    public function sender()
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    /**
     * Get the user who received this message
     */
    public function receiver()
    {
        return $this->belongsTo(User::class, 'receiver_id');
    }

    /**
     * Get the reservation this message belongs to
     */
    public function reservation()
    {
        return $this->belongsTo(Reservation::class);
    }

    /**
     * Get message reactions
     */
    public function reactions()
    {
        return $this->hasMany(MessageReaction::class);
    }

    /**
     * Get parent message (for threading)
     */
    public function parentMessage()
    {
        return $this->belongsTo(Message::class, 'parent_message_id');
    }

    /**
     * Get child messages (thread replies)
     */
    public function childMessages()
    {
        return $this->hasMany(Message::class, 'parent_message_id');
    }

    /**
     * Get thread messages
     */
    public function threadMessages()
    {
        return $this->hasMany(Message::class, 'thread_id', 'id');
    }

    /**
     * Get message mentions
     */
    public function mentions()
    {
        return $this->hasMany(MessageMention::class);
    }

    /**
     * Get mentioned users
     */
    public function mentionedUsers()
    {
        return $this->belongsToMany(User::class, 'message_mentions', 'message_id', 'mentioned_user_id');
    }

    /**
     * Get replied message
     */
    public function repliedMessage()
    {
        return $this->belongsTo(Message::class, 'reply_to_message_id');
    }

    /**
     * Get messages that reply to this message
     */
    public function replies()
    {
        return $this->hasMany(Message::class, 'reply_to_message_id');
    }

    /**
     * Get forwarded from message
     */
    public function forwardedFromMessage()
    {
        return $this->belongsTo(Message::class, 'forwarded_from_message_id');
    }

    /**
     * Get forwarded from user
     */
    public function forwardedFromUser()
    {
        return $this->belongsTo(User::class, 'forwarded_from_user_id');
    }

    /**
     * Get pinned by user
     */
    public function pinnedBy()
    {
        return $this->belongsTo(User::class, 'pinned_by');
    }

    /**
     * Get message translations
     */
    public function translations()
    {
        return $this->hasMany(MessageTranslation::class);
    }

    /**
     * Get encryption key
     */
    public function encryptionKey()
    {
        return $this->belongsTo(MessageEncryptionKey::class, 'encryption_key_id', 'key_id');
    }

    /**
     * Scope for unread messages
     */
    public function scopeUnread($query)
    {
        return $query->where('is_read', false);
    }

    /**
     * Scope for messages by type
     */
    public function scopeByType($query, $type)
    {
        return $query->where('message_type', $type);
    }

    /**
     * Scope for messages in a chat
     */
    public function scopeInChat($query, $chatId)
    {
        return $query->where('chat_id', $chatId);
    }

    /**
     * Scope for messages between users
     */
    public function scopeBetweenUsers($query, $user1Id, $user2Id)
    {
        return $query->where(function ($q) use ($user1Id, $user2Id) {
            $q->where('sender_id', $user1Id)->where('receiver_id', $user2Id)
              ->orWhere('sender_id', $user2Id)->where('receiver_id', $user1Id);
        });
    }

    /**
     * Mark message as read
     */
    public function markAsRead()
    {
        $this->update([
            'message_status' => 'read',
            'is_read' => true,
            'read_at' => now(),
        ]);
    }

    /**
     * Soft delete message
     */
    public function softDelete()
    {
        $this->update([
            'is_deleted' => true,
            'deleted_at' => now(),
        ]);
    }

    /**
     * Scope for pinned messages
     */
    public function scopePinned($query)
    {
        return $query->where('is_pinned', true);
    }

    /**
     * Scope for edited messages
     */
    public function scopeEdited($query)
    {
        return $query->whereNotNull('edited_at');
    }

    /**
     * Scope for forwarded messages
     */
    public function scopeForwarded($query)
    {
        return $query->whereNotNull('forwarded_from_message_id');
    }

    /**
     * Scope for encrypted messages
     */
    public function scopeEncrypted($query)
    {
        return $query->where('is_encrypted', true);
    }

    /**
     * Scope for messages in thread
     */
    public function scopeInThread($query, $threadId)
    {
        return $query->where('thread_id', $threadId);
    }

    /**
     * Scope for messages mentioning user
     */
    public function scopeMentioning($query, $userId)
    {
        return $query->whereJsonContains('mentions', $userId);
    }

    /**
     * Pin message
     */
    public function pin($userId)
    {
        $this->update([
            'is_pinned' => true,
            'pinned_at' => now(),
            'pinned_by' => $userId,
        ]);
    }

    /**
     * Unpin message
     */
    public function unpin()
    {
        $this->update([
            'is_pinned' => false,
            'pinned_at' => null,
            'pinned_by' => null,
        ]);
    }

    /**
     * Edit message
     */
    public function edit($newContent)
    {
        $this->update([
            'original_content' => $this->attributes['content'] ?? $this->getAttribute('content'),
            'content' => $newContent,
            'edited_at' => now(),
            'edit_count' => ($this->getAttribute('edit_count') ?? 0) + 1,
        ]);
    }

    /**
     * Forward message
     */
    public function forward($newChatId, $newSenderId, $newReceiverId)
    {
        return self::create([
            'chat_id' => $newChatId,
            'sender_id' => $newSenderId,
            'receiver_id' => $newReceiverId,
            'content' => $this->getAttribute('content'),
            'message_type' => $this->getAttribute('message_type'),
            'file_url' => $this->getAttribute('file_url'),
            'file_name' => $this->getAttribute('file_name'),
            'file_size' => $this->getAttribute('file_size'),
            'file_type' => $this->getAttribute('file_type'),
            'forwarded_from_message_id' => $this->getAttribute('id'),
            'forwarded_from_user_id' => $this->getAttribute('sender_id'),
            'forwarded_at' => now(),
        ]);
    }

    /**
     * Reply to message
     */
    public function reply($content, $senderId, $receiverId)
    {
        return self::create([
            'chat_id' => $this->chat_id,
            'sender_id' => $senderId,
            'receiver_id' => $receiverId,
            'content' => $content,
            'message_type' => 'text',
            'reply_to_message_id' => $this->id,
        ]);
    }

    /**
     * Create thread from message
     */
    public function createThread($title = null)
    {
        $thread = MessageThread::create([
            'chat_id' => $this->chat_id,
            'root_message_id' => $this->id,
            'thread_title' => $title,
        ]);

        $this->update(['thread_id' => $thread->id]);
        
        return $thread;
    }

    /**
     * Mark as delivered
     */
    public function markAsDelivered()
    {
        $this->update([
            'message_status' => 'delivered',
            'delivered_at' => now(),
        ]);
    }

}