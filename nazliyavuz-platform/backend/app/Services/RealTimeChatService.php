<?php

namespace App\Services;

use Pusher\Pusher;
use App\Models\Message;
use App\Models\User;
use Illuminate\Support\Facades\Log;

class RealTimeChatService
{
    protected ?Pusher $pusher = null;

    public function __construct()
    {
        // Check if Pusher is configured
        $key = config('broadcasting.connections.pusher.key');
        $secret = config('broadcasting.connections.pusher.secret');
        $appId = config('broadcasting.connections.pusher.app_id');
        
        if (!$key || !$secret || !$appId) {
            Log::warning('Pusher not configured, using mock service');
            // Pusher will remain null for development
            return;
        }
        
        $this->pusher = new Pusher(
            $key,
            $secret,
            $appId,
            [
                'cluster' => config('broadcasting.connections.pusher.options.cluster', 'mt1'),
                'useTLS' => true,
            ]
        );
    }

    /**
     * Send new message event
     */
    public function sendMessage(Message $message): void
    {
        try {
            if (!$this->pusher) {
                Log::info('Pusher not available, skipping real-time message');
                return;
            }
            
            $channel = $this->getConversationChannel($message->sender_id, $message->receiver_id);
            
            // Load sender relationship to avoid N+1 queries
            $message->load('sender');
            
            $this->pusher->trigger($channel, 'new-message', [
                'message' => [
                    'id' => $message->id,
                    'sender_id' => $message->sender_id,
                    'receiver_id' => $message->receiver_id,
                    'content' => $message->content,
                    'message_type' => $message->message_type,
                    'file_url' => $message->file_url,
                    'file_name' => $message->file_name,
                    'file_size' => $message->file_size,
                    'file_type' => $message->file_type,
                    'is_read' => $message->is_read,
                    'created_at' => $message->created_at->toISOString(),
                    'sender' => [
                        'id' => $message->sender->id,
                        'name' => $message->sender->name,
                        'profile_photo_url' => $message->sender->profile_photo_url,
                    ],
                ],
            ]);

            // Update conversation list for both users (simplified)
            try {
                $this->updateConversationList($message->sender_id, $message->receiver_id, $message);
            } catch (\Exception $e) {
                Log::warning('Failed to update conversation list: ' . $e->getMessage());
            }
        } catch (\Exception $e) {
            Log::error('Error in sendMessage: ' . $e->getMessage(), [
                'message_id' => $message->id,
                'error' => $e->getTraceAsString()
            ]);
            // Don't throw the exception, just log it
        }
    }

    /**
     * Send typing indicator
     */
    public function sendTypingIndicator(int $senderId, int $receiverId, bool $isTyping): void
    {
        if (!$this->pusher) return;
        
        $channel = $this->getConversationChannel($senderId, $receiverId);
        
        $this->pusher->trigger($channel, 'typing', [
            'sender_id' => $senderId,
            'receiver_id' => $receiverId,
            'is_typing' => $isTyping,
            'timestamp' => now()->toISOString(),
        ]);
    }

    /**
     * Send message read status
     */
    public function sendMessageRead(int $messageId, int $readerId): void
    {
        $message = Message::find($messageId);
        if (!$message) return;

        $channel = $this->getConversationChannel($message->sender_id, $message->receiver_id);
        
        $this->pusher->trigger($channel, 'message-read', [
            'message_id' => $messageId,
            'reader_id' => $readerId,
            'read_at' => now()->toISOString(),
        ]);
    }

    /**
     * Send message reaction
     */
    public function sendMessageReaction(int $messageId, int $userId, string $reaction): void
    {
        $message = Message::find($messageId);
        if (!$message) return;

        $channel = $this->getConversationChannel($message->sender_id, $message->receiver_id);
        
        $this->pusher->trigger($channel, 'message-reaction', [
            'message_id' => $messageId,
            'user_id' => $userId,
            'reaction' => $reaction,
            'timestamp' => now()->toISOString(),
        ]);
    }

    /**
     * Send user online status
     */
    public function sendUserStatus(int $userId, bool $isOnline): void
    {
        $user = User::find($userId);
        if (!$user) return;

        // Get all conversations for this user
        $conversations = \App\Models\Conversation::where('user1_id', $userId)
            ->orWhere('user2_id', $userId)
            ->get();

        foreach ($conversations as $conversation) {
            $otherUserId = $conversation->user1_id === $userId 
                ? $conversation->user2_id 
                : $conversation->user1_id;

            $channel = $this->getConversationChannel($userId, $otherUserId);
            
            $this->pusher->trigger($channel, 'user-status', [
                'user_id' => $userId,
                'is_online' => $isOnline,
                'timestamp' => now()->toISOString(),
            ]);
        }
    }

    /**
     * Send voice message
     */
    public function sendVoiceMessage(Message $message): void
    {
        $channel = $this->getConversationChannel($message->sender_id, $message->receiver_id);
        
        $this->pusher->trigger($channel, 'voice-message', [
            'message' => [
                'id' => $message->id,
                'sender_id' => $message->sender_id,
                'receiver_id' => $message->receiver_id,
                'content' => $message->content,
                'message_type' => $message->message_type,
                'file_url' => $message->file_url,
                'file_name' => $message->file_name,
                'file_size' => $message->file_size,
                'duration' => $message->file_size, // Duration in seconds for voice
                'created_at' => $message->created_at->toISOString(),
                'sender' => [
                    'id' => $message->sender->id,
                    'name' => $message->sender->name,
                    'profile_photo_url' => $message->sender->profile_photo_url,
                ],
            ],
        ]);
    }

    /**
     * Send video call invitation
     */
    public function sendVideoCallInvitation(int $callerId, int $receiverId, string $callType = 'video'): void
    {
        $channel = $this->getConversationChannel($callerId, $receiverId);
        
        $this->pusher->trigger($channel, 'video-call', [
            'caller_id' => $callerId,
            'receiver_id' => $receiverId,
            'call_type' => $callType, // 'video' or 'audio'
            'call_id' => uniqid('call_'),
            'timestamp' => now()->toISOString(),
        ]);
    }

    /**
     * Send video call response
     */
    public function sendVideoCallResponse(int $callerId, int $receiverId, string $response, string $callId): void
    {
        $channel = $this->getConversationChannel($callerId, $receiverId);
        
        $this->pusher->trigger($channel, 'video-call-response', [
            'caller_id' => $callerId,
            'receiver_id' => $receiverId,
            'response' => $response, // 'accepted', 'rejected', 'busy'
            'call_id' => $callId,
            'timestamp' => now()->toISOString(),
        ]);
    }

    /**
     * Send message deletion
     */
    public function sendMessageDeleted(int $messageId, int $senderId, int $receiverId): void
    {
        $channel = $this->getConversationChannel($senderId, $receiverId);
        
        $this->pusher->trigger($channel, 'message-deleted', [
            'message_id' => $messageId,
            'deleted_at' => now()->toISOString(),
        ]);
    }

    /**
     * Send signaling message for WebRTC
     */
    public function sendSignalingMessage(int $receiverId, string $type, array $data, ?string $callId = null): void
    {
        if (!$this->pusher) return;
        
        $senderId = auth()->id();
        $channel = $this->getConversationChannel($senderId, $receiverId);
        
        $this->pusher->trigger($channel, 'signaling', [
            'sender_id' => $senderId,
            'receiver_id' => $receiverId,
            'type' => $type, // 'offer', 'answer', 'ice-candidate', 'hangup'
            'data' => $data,
            'call_id' => $callId,
            'timestamp' => now()->toISOString(),
        ]);
    }

    /**
     * Send conversation updated
     */
    public function sendConversationUpdated(int $user1Id, int $user2Id, array $conversationData): void
    {
        $channel = $this->getConversationChannel($user1Id, $user2Id);
        
        $this->pusher->trigger($channel, 'conversation-updated', [
            'conversation' => $conversationData,
            'timestamp' => now()->toISOString(),
        ]);
    }

    /**
     * Get conversation channel name
     */
    private function getConversationChannel(int $user1Id, int $user2Id): string
    {
        $minId = min($user1Id, $user2Id);
        $maxId = max($user1Id, $user2Id);
        
        return "conversation-{$minId}-{$maxId}";
    }

    /**
     * Update conversation list for both users
     */
    private function updateConversationList(int $user1Id, int $user2Id, Message $message): void
    {
        // Simplified conversation list update
        // Just send a basic conversation update event
        $this->pusher->trigger("user-{$user1Id}", 'conversation-updated', [
            'conversation' => [
                'other_user_id' => $user2Id,
                'last_message' => $message->content,
                'last_message_at' => $message->created_at->toISOString(),
            ],
        ]);

        $this->pusher->trigger("user-{$user2Id}", 'conversation-updated', [
            'conversation' => [
                'other_user_id' => $user1Id,
                'last_message' => $message->content,
                'last_message_at' => $message->created_at->toISOString(),
            ],
        ]);
    }

    /**
     * Generate authentication token for private channels
     */
    public function authenticateChannel(string $channelName, string $socketId, int $userId): array
    {
        $auth = $this->pusher->authorizeChannel($channelName, $socketId);
        
        return [
            'auth' => $auth['auth'],
            'channel_data' => json_encode([
                'user_id' => $userId,
            ]),
        ];
    }

    /**
     * Send system notification
     */
    public function sendSystemNotification(int $userId, string $title, string $message, array $data = []): void
    {
        $this->pusher->trigger("user-{$userId}", 'system-notification', [
            'title' => $title,
            'message' => $message,
            'data' => $data,
            'timestamp' => now()->toISOString(),
        ]);
    }
}
