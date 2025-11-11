<?php

namespace App\Http\Controllers;

use App\Models\Message;
use App\Models\User;
use App\Models\Chat;
use App\Models\MessageThread;
use App\Models\MessageMention;
use App\Models\MessageEncryptionKey;
use App\Models\MessageTranslation;
use App\Services\RealTimeChatService;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class ChatController extends Controller
{
    private $realTimeChatService;
    protected NotificationService $notificationService;

    public function __construct(
        RealTimeChatService $realTimeChatService,
        NotificationService $notificationService
    ) {
        $this->realTimeChatService = $realTimeChatService;
        $this->notificationService = $notificationService;
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
        ->with(['user1', 'user2', 'lastMessage'])
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
                'last_message' => $chat->lastMessage ? [
                    'id' => $chat->lastMessage->id,
                    'content' => $chat->lastMessage->content,
                    'message_type' => $chat->lastMessage->message_type,
                    'sender_id' => $chat->lastMessage->sender_id,
                    'created_at' => $chat->lastMessage->created_at,
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
                    'file_url' => $message->file_url,
                    'file_name' => $message->file_name,
                    'file_size' => $message->file_size,
                    'file_type' => $message->file_type,
                    'voice_duration' => $message->message_type === 'audio' ? $message->file_size : null,
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
            'type' => 'sometimes|in:text,image,file,video,voice',
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
                'message_status' => 'sent',
            ]);

            // Update chat timestamp and last message
            $chat->update([
                'updated_at' => now(),
                'last_message_id' => $message->id,
                'last_message_at' => now(),
            ]);

            // Get other user
            $otherUser = $chat->user1_id === $user->id ? $chat->user2 : $chat->user1;

            // Send real-time notification (Pusher)
            $this->realTimeChatService->sendMessage($message);
            
            // Mark as delivered after successful send
            $message->markAsDelivered();

            // ✅ Send push notification (yeni!)
            try {
                $this->notificationService->sendNewMessageNotification(
                    $otherUser,
                    $user,
                    $content
                );
                Log::info('✅ Message notification sent', [
                    'sender_id' => $user->id,
                    'receiver_id' => $otherUser->id,
                    'message_id' => $message->id
                ]);
            } catch (\Exception $e) {
                Log::warning('Failed to send message notification: ' . $e->getMessage());
            }

            DB::commit();

            return response()->json([
                'message' => [
                    'id' => $message->id,
                    'content' => $message->getAttribute('content'),
                    'message_type' => $message->getAttribute('message_type'),
                    'sender_id' => $message->sender_id,
                    'is_read' => $message->is_read,
                    'created_at' => $message->created_at,
                ]
            ], 201);

        } catch (\Exception $e) {
            DB::rollback();
            Log::error('Send message error: ' . $e->getMessage(), [
                'trace' => $e->getTraceAsString(),
                'request' => $request->all()
            ]);
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Mesaj gönderilirken hata oluştu',
                    'details' => $e->getMessage()
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
        $messages = Message::where('receiver_id', $user->id)
            ->where('sender_id', $chat->user1_id == $user->id ? $chat->user2_id : $chat->user1_id)
            ->where('is_read', false)
            ->get();
            
        foreach ($messages as $message) {
            $message->markAsRead();
            // Send real-time read status update
            $this->realTimeChatService->sendMessageRead($message->id, $user->id);
        }

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

        $formattedMessages = $messages->items();
        foreach ($formattedMessages as $message) {
            $message->makeVisible(['file_url', 'file_name', 'file_size', 'file_type']);
            // Add voice_duration for audio messages
            if ($message->message_type === 'audio') {
                $message->voice_duration = $message->file_size;
            }
        }

        return response()->json([
            'messages' => $formattedMessages,
            'meta' => [
                'current_page' => $messages->currentPage(),
                'last_page' => $messages->lastPage(),
                'per_page' => $messages->perPage(),
                'total' => $messages->total(),
            ]
        ]);
    }

    /**
     * Send typing indicator
     */
    public function sendTypingIndicator(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'receiver_id' => 'required|exists:users,id',
            'is_typing' => 'required|boolean',
        ]);

        if ($validator->fails()) {
            Log::warning('chat.uploadMessageFile.validation_failed', [
                'errors' => $validator->errors()->toArray(),
                'type' => $request->input('type'),
                'mime' => $request->file('file')?->getMimeType(),
                'size' => $request->file('file')?->getSize(),
            ]);
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 422);
        }

        try {
            $user = auth()->user();
            
            $this->realTimeChatService->sendTypingIndicator(
                $user->id,
                $request->receiver_id,
                $request->is_typing
            );

            return response()->json([
                'success' => true,
                'message' => 'Typing indicator sent'
            ]);
        } catch (\Exception $e) {
            Log::error('Typing indicator error: ' . $e->getMessage());
            
            return response()->json([
                'success' => true,
                'message' => 'Received (Pusher may not be configured)'
            ]);
        }
    }

    /**
     * Send message reaction
     */
    public function sendMessageReaction(Request $request, $messageId): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'reaction' => 'required|string|max:10',
        ]);

        if ($validator->fails()) {
            Log::warning('chat.uploadMessageFile.validation_failed', [
                'errors' => $validator->errors()->toArray(),
                'type' => $request->input('type'),
                'mime' => $request->file('file')?->getMimeType(),
                'size' => $request->file('file')?->getSize(),
            ]);
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 422);
        }

        try {
            $user = auth()->user();
            $message = Message::findOrFail($messageId);

            // Verify user is part of the conversation
            if ($message->sender_id !== $user->id && $message->receiver_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu mesaja erişim yetkiniz yok'
                    ]
                ], 403);
            }

            // Create or update reaction
            $reaction = \App\Models\MessageReaction::updateOrCreate(
                [
                    'message_id' => $messageId,
                    'user_id' => $user->id,
                ],
                [
                    'reaction_type' => 'emoji',
                    'emoji' => $request->reaction,
                ]
            );

            // Send real-time event
            $this->realTimeChatService->sendMessageReaction(
                $messageId,
                $user->id,
                $request->reaction
            );

            return response()->json([
                'success' => true,
                'reaction' => [
                    'id' => $reaction->id,
                    'message_id' => $messageId,
                    'user_id' => $user->id,
                    'emoji' => $request->reaction,
                ]
            ], 201);

        } catch (\Exception $e) {
            Log::error('Message reaction error: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Reaction eklenirken hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get message reactions
     */
    public function getMessageReactions($messageId): JsonResponse
    {
        try {
            $message = Message::findOrFail($messageId);
            $user = auth()->user();

            // Verify access
            if ($message->sender_id !== $user->id && $message->receiver_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu mesaja erişim yetkiniz yok'
                    ]
                ], 403);
            }

            $reactions = \App\Models\MessageReaction::where('message_id', $messageId)
                ->with('user:id,name,profile_photo_url')
                ->get()
                ->map(function ($reaction) {
                    return [
                        'id' => $reaction->id,
                        'emoji' => $reaction->emoji,
                        'user' => [
                            'id' => $reaction->user->id,
                            'name' => $reaction->user->name,
                            'profile_photo_url' => $reaction->user->profile_photo_url,
                        ],
                        'created_at' => $reaction->created_at,
                    ];
                });

            return response()->json([
                'reactions' => $reactions
            ]);

        } catch (\Exception $e) {
            Log::error('Get reactions error: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Reactions yüklenirken hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Delete message (soft delete)
     */
    public function deleteMessage($messageId): JsonResponse
    {
        try {
            $message = Message::findOrFail($messageId);
            $user = auth()->user();

            // Only sender can delete
            if ($message->sender_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Sadece gönderen mesajı silebilir'
                    ]
                ], 403);
            }

            // Soft delete
            $message->softDelete();

            // Send real-time event
            $this->realTimeChatService->sendMessageDeleted(
                $messageId,
                $message->sender_id,
                $message->receiver_id
            );

            return response()->json([
                'success' => true,
                'message' => 'Mesaj silindi'
            ]);

        } catch (\Exception $e) {
            Log::error('Delete message error: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Mesaj silinirken hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Upload and send file/image message
     */
    public function uploadMessageFile(Request $request): JsonResponse
    {
        $maxSizeKb = 10240; // default 10MB
        if ($request->input('type') === 'video') {
            $maxSizeKb = 122880; // 120MB for videos
        } elseif ($request->input('type') === 'voice') {
            $maxSizeKb = 5120; // 5MB for voice
        }

        $validator = Validator::make($request->all(), [
            'chat_id' => 'required|exists:chats,id',
            'file' => 'required|file|max:' . $maxSizeKb,
            'type' => 'required|in:image,file,video,voice',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 422);
        }

        try {
            $user = auth()->user();
            $chatId = $request->input('chat_id');
            $type = $request->input('type');
            $file = $request->file('file');

            if (!$file) {
                Log::error('chat.uploadMessageFile.no_file', [
                    'type' => $type,
                    'payload_keys' => array_keys($request->all()),
                    'files_present' => array_keys($request->allFiles()),
                ]);
                return response()->json([
                    'error' => [
                        'code' => 'NO_FILE',
                        'message' => 'Dosya alanı bulunamadı (multipart field: file)'
                    ]
                ], 400);
            }

            // Log upload meta for diagnostics
            try {
                Log::error('chat.uploadMessageFile.meta', [
                    'type' => $type,
                    'mime' => $file->getMimeType(),
                    'name' => $file->getClientOriginalName(),
                    'size' => $file->getSize(),
                    'error' => method_exists($file, 'getError') ? $file->getError() : null,
                ]);
            } catch (\Throwable $t) {
                Log::error('chat.uploadMessageFile.meta_log_failed', ['err' => $t->getMessage()]);
            }

            // Verify user is part of chat
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

            // Additional validation based on type
            if ($type === 'image') {
                if (!in_array($file->getMimeType(), ['image/jpeg', 'image/png', 'image/gif', 'image/webp'])) {
                    return response()->json([
                        'error' => [
                            'code' => 'INVALID_FILE_TYPE',
                            'message' => 'Sadece resim dosyaları yüklenebilir (JPEG, PNG, GIF, WebP)'
                        ]
                    ], 422);
                }
            } elseif ($type === 'video') {
                $mime = $file->getMimeType();
                $name = $file->getClientOriginalName();
                $ext = strtolower(pathinfo($name, PATHINFO_EXTENSION));
                $isVideoMime = str_starts_with($mime ?? '', 'video/');
                $allowedExt = ['mp4','mov','m4v','3gp','3gpp','webm','mkv','avi','wmv','flv'];
                if (!$isVideoMime && !in_array($ext, $allowedExt) && $mime !== 'application/octet-stream') {
                    Log::warning('chat.uploadMessageFile.invalid_video_mime', [
                        'mime' => $mime,
                        'ext' => $ext,
                        'name' => $name,
                        'size' => $file->getSize(),
                    ]);
                    return response()->json([
                        'error' => [
                            'code' => 'INVALID_FILE_TYPE',
                            'message' => 'Video formatı desteklenmiyor'
                        ]
                    ], 422);
                }
            } elseif ($type === 'voice') {
                if (!in_array($file->getMimeType(), ['audio/mp3', 'audio/wav', 'audio/m4a', 'audio/aac', 'audio/webm', 'audio/ogg'])) {
                    return response()->json([
                        'error' => [
                            'code' => 'INVALID_FILE_TYPE',
                            'message' => 'Sadece ses dosyaları yüklenebilir (MP3, WAV, M4A, AAC, WebM, OGG)'
                        ]
                    ], 422);
                }
            }

            // Generate safe filename
            $originalName = $file->getClientOriginalName();
            $extension = $file->getClientOriginalExtension();
            $safeFileName = Str::slug(pathinfo($originalName, PATHINFO_FILENAME)) . '_' . time() . '.' . $extension;

            // Upload to local storage temporarily
            $folder = match($type) {
                'image' => 'chat-images',
                'video' => 'chat-videos',
                'voice' => 'chat-voice',
                default => 'chat-files'
            };
            
            $disk = config('filesystems.default');
            $options = $disk === 's3' ? ['visibility' => 'public'] : [];
            $path = Storage::disk($disk)->putFileAs(
                $folder,
                $file,
                $safeFileName,
                $options
            );

            $url = Storage::disk(config('filesystems.default'))->url($path);
            
            // Debug log for image upload
            Log::info('Image upload debug:', [
                'path' => $path,
                'url' => $url,
                's3_url' => config('filesystems.disks.s3.url'),
                'file_name' => $safeFileName,
                'type' => $type
            ]);

            DB::beginTransaction();
            try {
                // Get receiver
                $receiverId = $chat->user1_id === $user->id ? $chat->user2_id : $chat->user1_id;

                // Create message
                $content = match($type) {
                    'image' => '📷 Resim',
                    'video' => '🎥 Video',
                    'voice' => '🎤 Sesli mesaj',
                    default => "📄 {$originalName}"
                };
                
                $message = Message::create([
                    'chat_id' => $chatId,
                    'sender_id' => $user->id,
                    'receiver_id' => $receiverId,
                    'content' => $content,
                    'message_type' => $type,
                    'file_url' => $url,
                    'file_name' => $originalName,
                    'file_size' => $file->getSize(),
                    'file_type' => $file->getMimeType(),
                    'is_read' => false,
                ]);

                // Update chat timestamp and last message
                $chat->update([
                    'updated_at' => now(),
                    'last_message_id' => $message->id,
                    'last_message_at' => now(),
                ]);

                Log::info('chat.uploadMessageFile.save_attempt', [
                    'message_id' => $message->id,
                    'chat_id' => $chat->id,
                    'sender_id' => $user->id,
                    'receiver_id' => $receiverId,
                ]);

                // Commit BEFORE side-effects
                DB::commit();

                // Side-effects (non-transactional)
                try {
                    $this->realTimeChatService->sendMessage($message);
                } catch (\Exception $e) {
                    Log::warning('Realtime sendMessage failed: ' . $e->getMessage());
                }

                try {
                    $otherUser = $chat->user1_id === $user->id ? $chat->user2 : $chat->user1;
                    $this->notificationService->sendNewMessageNotification(
                        $otherUser,
                        $user,
                        $message->content
                    );
                } catch (\Exception $e) {
                    Log::warning('Failed to send file notification: ' . $e->getMessage());
                }

                Log::info('chat.uploadMessageFile.committed', [
                    'message_id' => $message->id,
                    'chat_id' => $chat->id,
                ]);

                return response()->json([
                    'message' => [
                        'id' => $message->id,
                        'content' => $message->content,
                        'message_type' => $message->message_type,
                        'file_url' => $message->file_url,
                        'file_name' => $message->file_name,
                        'file_size' => $message->file_size,
                        'file_type' => $message->file_type,
                        'sender_id' => $message->sender_id,
                        'is_read' => $message->is_read,
                        'created_at' => $message->created_at,
                    ]
                ], 201);

            } catch (\Exception $e) {
                DB::rollback();
                // Delete uploaded file if database fails
                Storage::disk(config('filesystems.default'))->delete($path);
                throw $e;
            }

        } catch (\Exception $e) {
            Log::error('File upload error: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Dosya yüklenirken hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Upload and send voice message
     */
    public function sendVoiceMessage(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'chat_id' => 'required|exists:chats,id',
            'audio_file' => 'required|file|mimes:mp3,wav,m4a,aac,webm|max:5120', // 5MB max
            'duration' => 'required|integer|min:1|max:300', // 5 minutes max
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 422);
        }

        try {
            $user = auth()->user();
            $chatId = $request->input('chat_id');
            $duration = $request->input('duration');
            $file = $request->file('audio_file');

            // Verify user is part of chat
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

            // Generate safe filename
            $extension = $file->getClientOriginalExtension();
            $safeFileName = 'voice_' . time() . '_' . Str::random(10) . '.' . $extension;

            // Upload to local storage (fallback from S3)
            try {
                $disk = config('filesystems.default');
                $options = $disk === 's3' ? ['visibility' => 'public'] : [];
                $path = Storage::disk($disk)->putFileAs(
                    'voice-messages',
                    $file,
                    $safeFileName,
                    $options
                );
                
                if (!$path) {
                    throw new \Exception('File upload failed - path is false');
                }
                
                $url = Storage::disk(config('filesystems.default'))->url($path);
                
                // Debug log for URL generation
                Log::info('Voice message S3 URL generated', [
                    'path' => $path,
                    'url' => $url,
                    'safe_filename' => $safeFileName
                ]);
            } catch (\Exception $e) {
                Log::error('S3 upload failed', [
                    'error' => $e->getMessage(),
                    'safe_filename' => $safeFileName,
                    'file_size' => $file->getSize(),
                    'file_mime' => $file->getMimeType()
                ]);
                
                return response()->json([
                    'error' => [
                        'code' => 'UPLOAD_FAILED',
                        'message' => 'Ses dosyası yüklenemedi: ' . $e->getMessage()
                    ]
                ], 500);
            }

            DB::beginTransaction();
            try {
                // Get receiver
                $receiverId = $chat->user1_id === $user->id ? $chat->user2_id : $chat->user1_id;

                // Create message
                $message = Message::create([
                    'chat_id' => $chatId,
                    'sender_id' => $user->id,
                    'receiver_id' => $receiverId,
                    'content' => "🎤 Sesli mesaj ({$duration} saniye)",
                    'message_type' => 'audio',
                    'file_url' => $url,
                    'file_name' => $safeFileName,
                    'file_size' => $duration, // Store duration in seconds
                    'file_type' => $file->getMimeType(),
                    'is_read' => false,
                ]);

                // Update chat timestamp and last message
                $chat->update([
                    'updated_at' => now(),
                    'last_message_id' => $message->id,
                    'last_message_at' => now(),
                ]);

                // Commit BEFORE side-effects
                DB::commit();

                // Side-effects (non-transactional)
                try {
                    $this->realTimeChatService->sendVoiceMessage($message);
                } catch (\Exception $e) {
                    Log::warning('Realtime sendVoiceMessage failed: ' . $e->getMessage());
                }

                try {
                    $otherUser = $chat->user1_id === $user->id ? $chat->user2 : $chat->user1;
                    $this->notificationService->sendNewMessageNotification(
                        $otherUser,
                        $user,
                        "🎤 Sesli mesaj gönderdi"
                    );
                } catch (\Exception $e) {
                    Log::warning('Failed to send voice notification: ' . $e->getMessage());
                }

                Log::info('chat.sendVoiceMessage.committed', [
                    'message_id' => $message->id,
                    'chat_id' => $chat->id,
                ]);

                Log::info('Voice message sent', [
                    'message_id' => $message->id,
                    'duration' => $duration,
                    'size' => $file->getSize(),
                ]);

                return response()->json([
                    'message' => [
                        'id' => $message->id,
                        'content' => $message->content,
                        'message_type' => $message->message_type,
                        'file_url' => $message->file_url,
                        'file_name' => $message->file_name,
                        'file_size' => $message->file_size,
                        'file_type' => $message->file_type,
                        'voice_duration' => $message->message_type === 'audio' ? $message->file_size : null,
                        'sender_id' => $message->sender_id,
                        'is_read' => $message->is_read,
                        'created_at' => $message->created_at,
                    ]
                ], 201);

            } catch (\Exception $e) {
                DB::rollback();
                // Delete uploaded file if database fails
                Storage::disk(config('filesystems.default'))->delete($path);
                throw $e;
            }

        } catch (\Exception $e) {
            Log::error('Voice message error: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Sesli mesaj gönderilirken hata oluştu'
                ]
            ], 500);
        }
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
            Log::error('Signaling error: ' . $e->getMessage(), [
                'trace' => $e->getTraceAsString(),
                'data' => $request->all()
            ]);
            
            // Return success anyway for development (Pusher might not be configured)
            return response()->json([
                'success' => true,
                'message' => 'Signaling mesajı alındı (development mode).',
                'warning' => 'Pusher not configured'
            ]);
        }
    }

    /**
     * Send video call invitation
     */
    public function sendVideoCallInvitation(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'chat_id' => 'required|exists:chats,id',
            'call_type' => 'required|in:video,audio',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 422);
        }

        try {
            $user = auth()->user();
            $chatId = $request->input('chat_id');
            $callType = $request->input('call_type');

            // Verify user is part of chat
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

            // Get receiver
            $receiverId = $chat->user1_id === $user->id ? $chat->user2_id : $chat->user1_id;

            // Send real-time video call invitation
            $this->realTimeChatService->sendVideoCallInvitation(
                $user->id,
                $receiverId,
                $callType
            );

            // Send push notification
            $receiver = $chat->user1_id === $user->id ? $chat->user2 : $chat->user1;
            try {
                $this->notificationService->sendVideoCallNotification(
                    $receiver->id,
                    $user->id,
                    $callType,
                    'call_' . time()
                );
            } catch (\Exception $e) {
                Log::warning('Failed to send video call notification: ' . $e->getMessage());
            }

            return response()->json([
                'success' => true,
                'message' => 'Video call daveti gönderildi'
            ]);

        } catch (\Exception $e) {
            Log::error('Video call invitation error: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Video call daveti gönderilirken hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Respond to video call invitation
     */
    public function respondToVideoCall(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'chat_id' => 'required|exists:chats,id',
            'response' => 'required|in:accepted,declined,missed',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 422);
        }

        try {
            $user = auth()->user();
            $chatId = $request->input('chat_id');
            $response = $request->input('response');

            // Verify user is part of chat
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

            // Send real-time response
            $this->realTimeChatService->sendVideoCallResponse(
                $chatId,
                $user->id,
                $response,
                'call_' . time()
            );

            return response()->json([
                'success' => true,
                'message' => 'Video call yanıtı gönderildi'
            ]);

        } catch (\Exception $e) {
            Log::error('Video call response error: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Video call yanıtı gönderilirken hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Search messages in chat
     */
    public function searchMessages(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'chat_id' => 'required|exists:chats,id',
            'query' => 'required|string|min:1|max:100',
            'type' => 'nullable|in:text,image,file,video,voice',
            'date_from' => 'nullable|date',
            'date_to' => 'nullable|date|after_or_equal:date_from',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 422);
        }

        try {
            $user = auth()->user();
            $chatId = $request->input('chat_id');
            $query = $request->input('query');
            $type = $request->input('type');
            $dateFrom = $request->input('date_from');
            $dateTo = $request->input('date_to');

            // Verify user is part of chat
            $chat = Chat::where('id', $chatId)
                ->where(function ($q) use ($user) {
                    $q->where('user1_id', $user->id)
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

            // Build search query
            $searchQuery = Message::where('chat_id', $chatId)
                ->where('is_deleted', false)
                ->where(function ($q) use ($query) {
                    $q->where('content', 'LIKE', "%{$query}%")
                      ->orWhere('file_name', 'LIKE', "%{$query}%");
                });

            // Filter by type
            if ($type) {
                $searchQuery->where('message_type', $type);
            }

            // Filter by date range
            if ($dateFrom) {
                $searchQuery->where('created_at', '>=', $dateFrom);
            }
            if ($dateTo) {
                $searchQuery->where('created_at', '<=', $dateTo);
            }

            $messages = $searchQuery
                ->orderBy('created_at', 'desc')
                ->limit(50)
                ->get()
                ->map(function ($message) {
                    return [
                        'id' => $message->id,
                        'content' => $message->content,
                        'message_type' => $message->message_type,
                        'file_name' => $message->file_name,
                        'sender_id' => $message->sender_id,
                        'created_at' => $message->created_at,
                    ];
                });

            return response()->json([
                'success' => true,
                'messages' => $messages,
                'total' => $messages->count()
            ]);

        } catch (\Exception $e) {
            Log::error('Search messages error: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Mesaj arama sırasında hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get chat statistics
     */
    public function getChatStatistics(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'chat_id' => 'required|exists:chats,id',
            'period' => 'nullable|in:7d,30d,90d,1y',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 422);
        }

        try {
            $user = auth()->user();
            $chatId = $request->input('chat_id');
            $period = $request->input('period', '30d');

            // Verify user is part of chat
            $chat = Chat::where('id', $chatId)
                ->where(function ($q) use ($user) {
                    $q->where('user1_id', $user->id)
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

            // Calculate date range
            $dateFrom = match($period) {
                '7d' => now()->subDays(7),
                '30d' => now()->subDays(30),
                '90d' => now()->subDays(90),
                '1y' => now()->subYear(),
                default => now()->subDays(30),
            };

            // Get statistics
            $totalMessages = Message::where('chat_id', $chatId)
                ->where('is_deleted', false)
                ->where('created_at', '>=', $dateFrom)
                ->count();

            $messagesByType = Message::where('chat_id', $chatId)
                ->where('is_deleted', false)
                ->where('created_at', '>=', $dateFrom)
                ->selectRaw('message_type, COUNT(*) as count')
                ->groupBy('message_type')
                ->pluck('count', 'message_type')
                ->toArray();

            $messagesByUser = Message::where('chat_id', $chatId)
                ->where('is_deleted', false)
                ->where('created_at', '>=', $dateFrom)
                ->selectRaw('sender_id, COUNT(*) as count')
                ->groupBy('sender_id')
                ->pluck('count', 'sender_id')
                ->toArray();

            $averageResponseTime = Message::where('chat_id', $chatId)
                ->where('is_deleted', false)
                ->where('created_at', '>=', $dateFrom)
                ->where('sender_id', '!=', $user->id)
                ->selectRaw('AVG(TIMESTAMPDIFF(MINUTE, LAG(created_at) OVER (ORDER BY created_at), created_at)) as avg_response_time')
                ->value('avg_response_time') ?? 0;

            $dailyActivity = Message::where('chat_id', $chatId)
                ->where('is_deleted', false)
                ->where('created_at', '>=', $dateFrom)
                ->selectRaw('DATE(created_at) as date, COUNT(*) as count')
                ->groupBy('date')
                ->orderBy('date')
                ->get()
                ->pluck('count', 'date')
                ->toArray();

            return response()->json([
                'success' => true,
                'statistics' => [
                    'total_messages' => $totalMessages,
                    'messages_by_type' => $messagesByType,
                    'messages_by_user' => $messagesByUser,
                    'average_response_time_minutes' => round($averageResponseTime, 1),
                    'daily_activity' => $dailyActivity,
                    'period' => $period,
                    'date_from' => $dateFrom->format('Y-m-d'),
                    'date_to' => now()->format('Y-m-d'),
                ]
            ]);

        } catch (\Exception $e) {
            Log::error('Chat statistics error: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Chat istatistikleri alınırken hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Pin message
     */
    public function pinMessage(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'message_id' => 'required|exists:messages,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 422);
        }

        try {
            $user = auth()->user();
            $message = Message::findOrFail($request->message_id);

            // Verify user is part of chat
            $chat = Chat::where('id', $message->chat_id)
                ->where(function ($q) use ($user) {
                    $q->where('user1_id', $user->id)
                      ->orWhere('user2_id', $user->id);
                })
                ->first();

            if (!$chat) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu mesaja erişim yetkiniz yok'
                    ]
                ], 403);
            }

            $message->pin($user->id);

            return response()->json([
                'success' => true,
                'message' => 'Mesaj sabitlendi'
            ]);

        } catch (\Exception $e) {
            Log::error('Pin message error: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Mesaj sabitlenirken hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Unpin message
     */
    public function unpinMessage(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'message_id' => 'required|exists:messages,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 422);
        }

        try {
            $user = auth()->user();
            $message = Message::findOrFail($request->message_id);

            // Verify user is part of chat
            $chat = Chat::where('id', $message->chat_id)
                ->where(function ($q) use ($user) {
                    $q->where('user1_id', $user->id)
                      ->orWhere('user2_id', $user->id);
                })
                ->first();

            if (!$chat) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu mesaja erişim yetkiniz yok'
                    ]
                ], 403);
            }

            $message->unpin();

            return response()->json([
                'success' => true,
                'message' => 'Mesaj sabitlemesi kaldırıldı'
            ]);

        } catch (\Exception $e) {
            Log::error('Unpin message error: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Mesaj sabitlemesi kaldırılırken hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Edit message
     */
    public function editMessage(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'message_id' => 'required|exists:messages,id',
            'content' => 'required|string|max:4000',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 422);
        }

        try {
            $user = auth()->user();
            $message = Message::findOrFail($request->message_id);

            // Verify user is the sender
            if ($message->sender_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Sadece kendi mesajlarınızı düzenleyebilirsiniz'
                    ]
                ], 403);
            }

            $message->edit($validator->validated()['content']);

            return response()->json([
                'success' => true,
                'message' => 'Mesaj düzenlendi',
                'message_data' => $message->fresh()
            ]);

        } catch (\Exception $e) {
            Log::error('Edit message error: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Mesaj düzenlenirken hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Forward message
     */
    public function forwardMessage(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'message_id' => 'required|exists:messages,id',
            'chat_id' => 'required|exists:chats,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 422);
        }

        try {
            $user = auth()->user();
            $originalMessage = Message::findOrFail($request->message_id);
            $targetChat = Chat::findOrFail($request->chat_id);

            // Verify user is part of both chats
            $sourceChat = Chat::where('id', $originalMessage->chat_id)
                ->where(function ($q) use ($user) {
                    $q->where('user1_id', $user->id)
                      ->orWhere('user2_id', $user->id);
                })
                ->first();

            $targetChatAccess = Chat::where('id', $targetChat->id)
                ->where(function ($q) use ($user) {
                    $q->where('user1_id', $user->id)
                      ->orWhere('user2_id', $user->id);
                })
                ->first();

            if (!$sourceChat || !$targetChatAccess) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu chat\'lere erişim yetkiniz yok'
                    ]
                ], 403);
            }

            $otherUserId = $targetChat->user1_id === $user->id 
                ? $targetChat->user2_id 
                : $targetChat->user1_id;

            $forwardedMessage = $originalMessage->forward(
                $targetChat->id,
                $user->id,
                $otherUserId
            );

            return response()->json([
                'success' => true,
                'message' => 'Mesaj iletildi',
                'forwarded_message' => $forwardedMessage
            ]);

        } catch (\Exception $e) {
            Log::error('Forward message error: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Mesaj iletirken hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Reply to message
     */
    public function replyToMessage(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'message_id' => 'required|exists:messages,id',
            'content' => 'required|string|max:4000',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 422);
        }

        try {
            $user = auth()->user();
            $originalMessage = Message::findOrFail($request->message_id);

            // Verify user is part of chat
            $chat = Chat::where('id', $originalMessage->chat_id)
                ->where(function ($q) use ($user) {
                    $q->where('user1_id', $user->id)
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

            $otherUserId = $chat->user1_id === $user->id 
                ? $chat->user2_id 
                : $chat->user1_id;

            $replyMessage = Message::create([
                'chat_id' => $originalMessage->chat_id,
                'sender_id' => $user->id,
                'receiver_id' => $otherUserId,
                'content' => $validator->validated()['content'],
                'is_read' => false,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Yanıt gönderildi',
                'reply_message' => $replyMessage
            ]);

        } catch (\Exception $e) {
            Log::error('Reply to message error: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Yanıt gönderilirken hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Create message thread
     */
    public function createThread(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'message_id' => 'required|exists:messages,id',
            'title' => 'nullable|string|max:255',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 422);
        }

        try {
            $user = auth()->user();
            $message = Message::findOrFail($request->message_id);

            // Verify user is part of chat
            $chat = Chat::where('id', $message->chat_id)
                ->where(function ($q) use ($user) {
                    $q->where('user1_id', $user->id)
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

            $thread = MessageThread::create([
                'chat_id' => $message->chat_id,
                'root_message_id' => $message->id,
                'thread_title' => $request->title,
            ]);
            
            $message->update(['thread_id' => $thread->id]);

            return response()->json([
                'success' => true,
                'message' => 'Konu oluşturuldu',
                'thread' => $thread
            ]);

        } catch (\Exception $e) {
            Log::error('Create thread error: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Konu oluşturulurken hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get message thread
     */
    public function getThread(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'thread_id' => 'required|exists:message_threads,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 422);
        }

        try {
            $user = auth()->user();
            $thread = MessageThread::with(['rootMessage', 'messages.sender'])
                ->findOrFail($request->thread_id);

            // Verify user is part of chat
            $chat = Chat::where('id', $thread->chat_id)
                ->where(function ($q) use ($user) {
                    $q->where('user1_id', $user->id)
                      ->orWhere('user2_id', $user->id);
                })
                ->first();

            if (!$chat) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu konuya erişim yetkiniz yok'
                    ]
                ], 403);
            }

            return response()->json([
                'success' => true,
                'thread' => $thread
            ]);

        } catch (\Exception $e) {
            Log::error('Get thread error: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Konu alınırken hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Translate message
     */
    public function translateMessage(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'message_id' => 'required|exists:messages,id',
            'target_language' => 'required|string|size:2',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 422);
        }

        try {
            $user = auth()->user();
            $message = Message::findOrFail($request->message_id);

            // Verify user is part of chat
            $chat = Chat::where('id', $message->chat_id)
                ->where(function ($q) use ($user) {
                    $q->where('user1_id', $user->id)
                      ->orWhere('user2_id', $user->id);
                })
                ->first();

            if (!$chat) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu mesaja erişim yetkiniz yok'
                    ]
                ], 403);
            }

            // Check if translation already exists
            $existingTranslation = MessageTranslation::where('message_id', $message->id)
                ->where('language_code', $request->target_language)
                ->first();

            if ($existingTranslation) {
                return response()->json([
                    'success' => true,
                    'translation' => $existingTranslation
                ]);
            }

            // Create new translation
            $translation = MessageTranslation::translateMessage(
                $message->id,
                $request->target_language,
                $message->content
            );

            return response()->json([
                'success' => true,
                'translation' => $translation
            ]);

        } catch (\Exception $e) {
            Log::error('Translate message error: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Mesaj çevrilirken hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get pinned messages
     */
    public function getPinnedMessages(Request $request): JsonResponse
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
            ], 422);
        }

        try {
            $user = auth()->user();
            $chatId = $request->chat_id;

            // Verify user is part of chat
            $chat = Chat::where('id', $chatId)
                ->where(function ($q) use ($user) {
                    $q->where('user1_id', $user->id)
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

            $pinnedMessages = Message::where('chat_id', $chatId)
                ->pinned()
                ->with(['sender', 'reactions'])
                ->orderBy('pinned_at', 'desc')
                ->get();

            return response()->json([
                'success' => true,
                'pinned_messages' => $pinnedMessages
            ]);

        } catch (\Exception $e) {
            Log::error('Get pinned messages error: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Sabitlenmiş mesajlar alınırken hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get unread message count for user
     */
    public function getUnreadCount(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            
            // Count unread messages in chats where user is participant
            $unreadCount = Message::whereHas('chat', function ($query) use ($user) {
                $query->where('student_id', $user->id)
                      ->orWhere('teacher_id', $user->id);
            })
            ->where('sender_id', '!=', $user->id)
            ->where('is_read', false)
            ->count();
            
            return response()->json([
                'success' => true,
                'count' => $unreadCount
            ]);
            
        } catch (\Exception $e) {
            Log::error('Get unread count error: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Okunmamış mesaj sayısı alınırken hata oluştu'
                ]
            ], 500);
        }
    }
}