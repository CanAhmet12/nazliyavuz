<?php

namespace App\Http\Controllers;

use App\Models\Message;
use App\Models\User;
use App\Models\Chat;
use App\Services\RealTimeChatService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\DB;

class ChatController extends Controller
{
    private $realTimeChatService;

    public function __construct(RealTimeChatService $realTimeChatService)
    {
        $this->realTimeChatService = $realTimeChatService;
    }

    /**
     * Get user's chats
     */
    public function index(): JsonResponse
    {
        $user = auth()->user();
        
        $chats = Chat::where(function ($query) use ($user) {
            $query->where('user1_id', $user->id)
                  ->orWhere('user2_id', $user->id);
        })
        ->with(['user1', 'user2'])
        ->orderBy('updated_at', 'desc')
        ->get()
        ->map(function ($chat) use ($user) {
            $otherUser = $chat->user1_id === $user->id ? $chat->user2 : $chat->user1;
            $unreadCount = Message::where(function ($query) use ($chat, $user) {
                    $query->where(function ($q) use ($chat, $user) {
                            $q->where('sender_id', $chat->user1_id == $user->id ? $chat->user2_id : $chat->user1_id)
                              ->where('receiver_id', $user->id);
                        });
                })
                ->where('is_read', false)
                ->count();
            
            return [
                'id' => $chat->id,
                'other_user' => [
                    'id' => $otherUser->id,
                    'name' => $otherUser->name,
                    'email' => $otherUser->email,
                    'profile_photo_url' => $otherUser->profile_photo_url,
                    'role' => $otherUser->role,
                ],
                'last_message' => $chat->lastMessage() ? [
                    'id' => $chat->lastMessage()->id,
                    'content' => $chat->lastMessage()->content,
                    'message_type' => $chat->lastMessage()->message_type,
                    'sender_id' => $chat->lastMessage()->sender_id,
                    'created_at' => $chat->lastMessage()->created_at,
                ] : null,
                'unread_count' => $unreadCount,
                'created_at' => $chat->created_at,
                'updated_at' => $chat->updated_at,
            ];
        });

        return response()->json([
            'chats' => $chats
        ]);
    }

    /**
     * Get or create chat between two users
     */
    public function getOrCreateChat(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'other_user_id' => 'required|exists:users,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $user = auth()->user();
        $otherUserId = $request->other_user_id;

        if ($user->id === $otherUserId) {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_REQUEST',
                    'message' => 'Kendinizle chat oluşturamazsınız'
                ]
            ], 400);
        }

        // Check if chat already exists
        $chat = Chat::where(function ($query) use ($user, $otherUserId) {
            $query->where('user1_id', $user->id)
                  ->where('user2_id', $otherUserId);
        })->orWhere(function ($query) use ($user, $otherUserId) {
            $query->where('user1_id', $otherUserId)
                  ->where('user2_id', $user->id);
        })->first();

        if (!$chat) {
            // Create new chat
            $chat = Chat::create([
                'user1_id' => min($user->id, $otherUserId),
                'user2_id' => max($user->id, $otherUserId),
            ]);
        }

        $otherUser = $chat->user1_id === $user->id ? $chat->user2 : $chat->user1;

        // Get messages
        $messages = Message::where(function ($query) use ($chat) {
                $query->where(function ($q) use ($chat) {
                        $q->where('sender_id', $chat->user1_id)
                          ->where('receiver_id', $chat->user2_id);
                    })
                    ->orWhere(function ($q) use ($chat) {
                        $q->where('sender_id', $chat->user2_id)
                          ->where('receiver_id', $chat->user1_id);
                    });
            })
            ->orderBy('created_at', 'asc')
            ->get()
            ->map(function ($message) {
                return [
                    'id' => $message->id,
                    'content' => $message->content,
                    'message_type' => $message->message_type,
                    'sender_id' => $message->sender_id,
                    'is_read' => $message->is_read,
                    'created_at' => $message->created_at,
                ];
            });

        return response()->json([
            'chat' => [
                'id' => $chat->id,
                'other_user' => [
                    'id' => $otherUser->id,
                    'name' => $otherUser->name,
                    'email' => $otherUser->email,
                    'profile_photo_url' => $otherUser->profile_photo_url,
                    'role' => $otherUser->role,
                ],
                'messages' => $messages,
                'created_at' => $chat->created_at,
                'updated_at' => $chat->updated_at,
            ]
        ]);
    }

    /**
     * Send message
     */
    public function sendMessage(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'chat_id' => 'required|exists:chats,id',
            'content' => 'required|string|max:1000',
            'type' => 'sometimes|in:text,image,file',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $user = auth()->user();
        $chatId = $request->input('chat_id');
        $content = $request->input('content');
        $type = $request->input('type', 'text');

        // Verify user is part of this chat
        $chat = Chat::where('id', $chatId)
            ->where(function ($query) use ($user) {
                $query->where('user1_id', $user->id)
                      ->orWhere('user2_id', $user->id);
            })
            ->first();

        if (!$chat) {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu chat\'e erişim yetkiniz yok'
                ]
            ], 403);
        }

        DB::beginTransaction();
        try {
            // Create message
            $message = Message::create([
                'chat_id' => $chatId,
                'sender_id' => $user->id,
                'receiver_id' => $chat->user1_id === $user->id ? $chat->user2_id : $chat->user1_id,
                'content' => $content,
                'message_type' => $type,
                'is_read' => false,
            ]);

            // Update chat timestamp
            $chat->update(['updated_at' => now()]);

            // Get other user
            $otherUser = $chat->user1_id === $user->id ? $chat->user2 : $chat->user1;

            // Send real-time notification
            $this->realTimeChatService->sendMessage($message);

            DB::commit();

            return response()->json([
                'message' => [
                    'id' => $message->id,
                    'content' => $message->content,
                    'message_type' => $message->message_type,
                    'sender_id' => $message->sender_id,
                    'is_read' => $message->is_read,
                    'created_at' => $message->created_at,
                ]
            ], 201);

        } catch (\Exception $e) {
            DB::rollback();
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Mesaj gönderilirken hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Mark messages as read
     */
    public function markAsRead(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'chat_id' => 'required|exists:chats,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $user = auth()->user();
        $chatId = $request->input('chat_id');

        // Verify user is part of this chat
        $chat = Chat::where('id', $chatId)
            ->where(function ($query) use ($user) {
                $query->where('user1_id', $user->id)
                      ->orWhere('user2_id', $user->id);
            })
            ->first();

        if (!$chat) {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu chat\'e erişim yetkiniz yok'
                ]
            ], 403);
        }

        // Mark messages as read
        Message::where('receiver_id', $user->id)
            ->where('sender_id', $chat->user1_id == $user->id ? $chat->user2_id : $chat->user1_id)
            ->where('is_read', false)
            ->update(['is_read' => true, 'read_at' => now()]);

        return response()->json([
            'message' => 'Mesajlar okundu olarak işaretlendi'
        ]);
    }

    /**
     * Get chat messages
     */
    public function getMessages(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'chat_id' => 'required|exists:chats,id',
            'page' => 'sometimes|integer|min:1',
            'per_page' => 'sometimes|integer|min:1|max:100',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $user = auth()->user();
        $chatId = $request->input('chat_id');
        $page = $request->input('page', 1);
        $perPage = $request->input('per_page', 50);

        // Verify user is part of this chat
        $chat = Chat::where('id', $chatId)
            ->where(function ($query) use ($user) {
                $query->where('user1_id', $user->id)
                      ->orWhere('user2_id', $user->id);
            })
            ->first();

        if (!$chat) {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu chat\'e erişim yetkiniz yok'
                ]
            ], 403);
        }

        $messages = Message::where(function ($query) use ($chat) {
                $query->where(function ($q) use ($chat) {
                        $q->where('sender_id', $chat->user1_id)
                          ->where('receiver_id', $chat->user2_id);
                    })
                    ->orWhere(function ($q) use ($chat) {
                        $q->where('sender_id', $chat->user2_id)
                          ->where('receiver_id', $chat->user1_id);
                    });
            })
            ->orderBy('created_at', 'desc')
            ->paginate($perPage, ['*'], 'page', $page);

        return response()->json([
            'messages' => $messages->items(),
            'meta' => [
                'current_page' => $messages->currentPage(),
                'last_page' => $messages->lastPage(),
                'per_page' => $messages->perPage(),
                'total' => $messages->total(),
            ]
        ]);
    }

    /**
     * Send signaling message for WebRTC
     */
    public function sendSignalingMessage(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'receiver_id' => 'required|exists:users,id',
            'type' => 'required|string|in:offer,answer,ice-candidate,hangup,call-request',
            'data' => 'required|array',
            'call_id' => 'sometimes|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        try {
            $user = auth()->user();
            $receiverId = $request->receiver_id;
            $type = $request->type;
            $data = $request->data;
            $callId = $request->call_id;

            // Send signaling message via real-time service
            $this->realTimeChatService->sendSignalingMessage($receiverId, $type, $data, $callId);

            return response()->json([
                'success' => true,
                'message' => 'Signaling mesajı gönderildi.',
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'error' => [
                    'code' => 'SIGNALING_ERROR',
                    'message' => 'Signaling mesajı gönderilirken bir hata oluştu'
                ]
            ], 500);
        }
    }
}