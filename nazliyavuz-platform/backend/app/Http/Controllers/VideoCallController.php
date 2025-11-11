<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\Reservation;
use App\Models\VideoCall;
use App\Models\VideoCallParticipant;
use App\Services\NotificationService;
use App\Services\CacheService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Carbon\Carbon;

class VideoCallController extends Controller
{
    protected NotificationService $notificationService;
    protected CacheService $cacheService;

    public function __construct(NotificationService $notificationService, CacheService $cacheService)
    {
        $this->notificationService = $notificationService;
        $this->cacheService = $cacheService;
    }

    /**
     * Start a video call
     */
    public function startCall(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'receiver_id' => 'required|integer|exists:users,id',
            'call_type' => 'required|in:video,audio',
            'call_id' => 'nullable|string',
            'subject' => 'nullable|string|max:255',
            'reservation_id' => 'nullable|integer|exists:reservations,id',
        ]);

        try {
            Log::info('🚀 VideoCallController::startCall STARTED', [
                'request_data' => $request->all(),
                'timestamp' => now(),
            ]);
            
            $user = Auth::user();
            Log::info('👤 User authenticated for video call', [
                'user_id' => $user->id,
                'role' => $user->role,
            ]);
            
            $receiverId = $validated['receiver_id'];
            $callType = $validated['call_type'];
            $callId = $validated['call_id'] ?? 'call_' . Str::uuid();
            $subject = $validated['subject'] ?? null;
            $reservationId = $validated['reservation_id'] ?? null;

            // Check if receiver exists and is available
            Log::info('🔍 Checking receiver', ['receiver_id' => $receiverId]);
            $receiver = User::find($receiverId);
            if (!$receiver) {
                Log::error('❌ Receiver not found', ['receiver_id' => $receiverId]);
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'USER_NOT_FOUND',
                        'message' => 'Receiver not found'
                    ]
                ], 404);
            }
            Log::info('✅ Receiver found', ['receiver_id' => $receiverId, 'receiver_name' => $receiver->name]);

            // Check if receiver is available for calls
            Log::info('🔍 Checking receiver availability', ['receiver_id' => $receiverId]);
            $isAvailable = $this->isUserAvailableForCalls($receiverId);
            Log::info('📊 Availability check result', ['receiver_id' => $receiverId, 'is_available' => $isAvailable]);
            
            if (!$isAvailable) {
                Log::error('❌ Receiver not available for calls', ['receiver_id' => $receiverId]);
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'USER_NOT_AVAILABLE',
                        'message' => 'User is not available for calls'
                    ]
                ], 400);
            }

            // Create video call record
            Log::info('💾 Creating video call record', [
                'call_id' => $callId,
                'caller_id' => $user->id,
                'receiver_id' => $receiverId,
                'call_type' => $callType,
                'subject' => $subject,
                'reservation_id' => $reservationId,
            ]);
            
            $videoCall = VideoCall::create([
                'call_id' => $callId,
                'caller_id' => $user->id,
                'receiver_id' => $receiverId,
                'call_type' => $callType,
                'subject' => $subject,
                'reservation_id' => $reservationId,
                'status' => 'initiated',
                'started_at' => now(),
            ]);
            
            Log::info('✅ Video call record created', ['video_call_id' => $videoCall->id]);

            // Add participants
            VideoCallParticipant::create([
                'video_call_id' => $videoCall->id,
                'user_id' => $user->id,
                'role' => 'caller',
                'joined_at' => now(),
            ]);

            VideoCallParticipant::create([
                'video_call_id' => $videoCall->id,
                'user_id' => $receiverId,
                'role' => 'receiver',
            ]);

            // Send push notification
            $this->notificationService->sendVideoCallNotification(
                $receiverId,
                $user->name,
                $callType,
                $callId
            );

            // Add video call message to chat
            $this->addVideoCallMessageToChat($user->id, $receiverId, $callId, $callType, $subject);

            // Invalidate cache
            $this->cacheService->invalidateUserCache($user->id);
            $this->cacheService->invalidateUserCache($receiverId);

            Log::info('Video call started', [
                'call_id' => $callId,
                'caller_id' => $user->id,
                'receiver_id' => $receiverId,
                'call_type' => $callType,
            ]);

            return response()->json([
                'success' => true,
                'call_id' => $callId,
                'call_type' => $callType,
                'video_call' => $videoCall,
                'message' => 'Video call initiated successfully'
            ]);

        } catch (\Exception $e) {
            Log::error('❌ Video call start error', [
                'error_message' => $e->getMessage(),
                'error_file' => $e->getFile(),
                'error_line' => $e->getLine(),
                'error_trace' => $e->getTraceAsString(),
                'request_data' => $request->all()
            ]);
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => 'VIDEO_CALL_START_ERROR',
                    'message' => 'Failed to start video call',
                    'debug' => $e->getMessage()
                ]
            ], 500);
        }
    }

    /**
     * Answer a video call
     */
    public function answerCall(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $validator = validator($request->all(), [
                'call_id' => 'required|string',
                'call_type' => 'required|in:video,audio',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Validation failed',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $callId = $request->call_id;
            $callType = $request->call_type;

            // Find the video call
            $videoCall = VideoCall::where('call_id', $callId)->first();
            if (!$videoCall) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'CALL_NOT_FOUND',
                        'message' => 'Video call not found'
                    ]
                ], 404);
            }

            // Check if user is the receiver
            if ($videoCall->receiver_id !== $user->id) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'UNAUTHORIZED',
                        'message' => 'You are not authorized to answer this call'
                    ]
                ], 403);
            }

            // Update call status
            $videoCall->update([
                'status' => 'active',
                'answered_at' => now(),
            ]);

            // Update participant status
            VideoCallParticipant::where('video_call_id', $videoCall->id)
                ->where('user_id', $user->id)
                ->update([
                    'joined_at' => now(),
                    'status' => 'active',
                ]);

            // Send push notification to caller
            try {
                $caller = User::find($videoCall->caller_id);
                if ($caller) {
                    $this->notificationService->sendVideoCallNotification(
                        $caller->id,
                        $user->name,
                        $callType,
                        $callId
                    );
                }
            } catch (\Exception $e) {
                Log::error('Failed to send video call answer notification', [
                    'error' => $e->getMessage(),
                    'caller_id' => $videoCall->caller_id,
                    'call_id' => $callId
                ]);
            }
            
            // Add answer message to chat
            $this->addVideoCallMessageToChat($user->id, $videoCall->caller_id, $callId, $callType, "Arama cevaplandı");

            // Invalidate cache
            $this->cacheService->invalidateUserCache($user->id);
            $this->cacheService->invalidateUserCache($videoCall->caller_id);

            Log::info('Video call answered', [
                'call_id' => $callId,
                'user_id' => $user->id,
            ]);

            return response()->json([
                'success' => true,
                'call_id' => $callId,
                'call_type' => $callType,
                'message' => 'Call answered successfully'
            ]);

        } catch (\Exception $e) {
            Log::error('Answer video call error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => 'VIDEO_CALL_ANSWER_ERROR',
                    'message' => 'Failed to answer video call'
                ]
            ], 500);
        }
    }

    /**
     * Reject a video call
     */
    public function rejectCall(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $validator = validator($request->all(), [
                'call_id' => 'required|string',
                'reason' => 'nullable|string|max:255',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Validation failed',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $callId = $request->call_id;
            $reason = $request->reason;

            // Find the video call
            $videoCall = VideoCall::where('call_id', $callId)->first();
            if (!$videoCall) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'CALL_NOT_FOUND',
                        'message' => 'Video call not found'
                    ]
                ], 404);
            }

            // Check if user is the receiver
            if ($videoCall->receiver_id !== $user->id) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'UNAUTHORIZED',
                        'message' => 'You are not authorized to reject this call'
                    ]
                ], 403);
            }

            // Update call status
            $videoCall->update([
                'status' => 'rejected',
                'ended_at' => now(),
                'end_reason' => $reason ?? 'Call rejected by user',
            ]);

            // Add reject message to chat
            $this->addVideoCallMessageToChat($user->id, $videoCall->caller_id, $callId, $videoCall->call_type, "Arama reddedildi" . ($reason ? ": {$reason}" : ""));

            // Invalidate cache
            $this->cacheService->invalidateUserCache($user->id);
            $this->cacheService->invalidateUserCache($videoCall->caller_id);

            Log::info('Video call rejected', [
                'call_id' => $callId,
                'user_id' => $user->id,
                'reason' => $reason,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Call rejected successfully'
            ]);

        } catch (\Exception $e) {
            Log::error('Reject video call error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => 'VIDEO_CALL_REJECT_ERROR',
                    'message' => 'Failed to reject video call'
                ]
            ], 500);
        }
    }

    /**
     * End a video call
     */
    public function endCall(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $validator = validator($request->all(), [
                'call_id' => 'required|string',
                'reason' => 'nullable|string|max:255',
                'duration' => 'nullable|integer|min:0',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Validation failed',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $callId = $request->call_id;
            $reason = $request->reason;
            $duration = $request->duration;

            // Find the video call
            $videoCall = VideoCall::where('call_id', $callId)->first();
            if (!$videoCall) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'CALL_NOT_FOUND',
                        'message' => 'Video call not found'
                    ]
                ], 404);
            }

            // Check if user is a participant
            $participant = VideoCallParticipant::where('video_call_id', $videoCall->id)
                ->where('user_id', $user->id)
                ->first();

            if (!$participant) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'UNAUTHORIZED',
                        'message' => 'You are not authorized to end this call'
                    ]
                ], 403);
            }

            // Calculate actual duration if not provided
            if (!$duration && $videoCall->started_at) {
                $duration = $videoCall->started_at->diffInSeconds(now());
            }

            // Update call status
            $videoCall->update([
                'status' => 'ended',
                'ended_at' => now(),
                'duration_seconds' => $duration,
                'end_reason' => $reason ?? 'Call ended by user',
            ]);

            // Update participant status
            VideoCallParticipant::where('video_call_id', $videoCall->id)
                ->where('user_id', $user->id)
                ->update([
                    'left_at' => now(),
                    'status' => 'left',
                ]);

            // Add end message to chat
            $otherUserId = $user->id === $videoCall->caller_id ? $videoCall->receiver_id : $videoCall->caller_id;
            $this->addVideoCallMessageToChat($user->id, $otherUserId, $callId, $videoCall->call_type, "Arama sonlandırıldı" . ($reason ? ": {$reason}" : ""));

            // Invalidate cache
            $this->cacheService->invalidateUserCache($user->id);
            $this->cacheService->invalidateUserCache($videoCall->caller_id);
            $this->cacheService->invalidateUserCache($videoCall->receiver_id);

            Log::info('Video call ended', [
                'call_id' => $callId,
                'user_id' => $user->id,
                'duration' => $duration,
                'reason' => $reason,
            ]);

            return response()->json([
                'success' => true,
                'duration' => $duration,
                'message' => 'Call ended successfully'
            ]);

        } catch (\Exception $e) {
            Log::error('End video call error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => 'VIDEO_CALL_END_ERROR',
                    'message' => 'Failed to end video call'
                ]
            ], 500);
        }
    }

    /**
     * Toggle microphone mute
     */
    public function toggleMute(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $validator = validator($request->all(), [
                'call_id' => 'required|string',
                'muted' => 'required|boolean',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Validation failed',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $callId = $request->call_id;
            $muted = $request->muted;

            // Find the video call
            $videoCall = VideoCall::where('call_id', $callId)->first();
            if (!$videoCall) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'CALL_NOT_FOUND',
                        'message' => 'Video call not found'
                    ]
                ], 404);
            }

            // Update participant mute status
            VideoCallParticipant::where('video_call_id', $videoCall->id)
                ->where('user_id', $user->id)
                ->update(['is_muted' => $muted]);

            return response()->json([
                'success' => true,
                'muted' => $muted,
                'message' => 'Microphone status updated'
            ]);

        } catch (\Exception $e) {
            Log::error('Toggle mute error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => 'TOGGLE_MUTE_ERROR',
                    'message' => 'Failed to toggle mute'
                ]
            ], 500);
        }
    }

    /**
     * Toggle video on/off
     */
    public function toggleVideo(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $validator = validator($request->all(), [
                'call_id' => 'required|string',
                'video_enabled' => 'required|boolean',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Validation failed',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $callId = $request->call_id;
            $videoEnabled = $request->video_enabled;

            // Find the video call
            $videoCall = VideoCall::where('call_id', $callId)->first();
            if (!$videoCall) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'CALL_NOT_FOUND',
                        'message' => 'Video call not found'
                    ]
                ], 404);
            }

            // Update participant video status
            VideoCallParticipant::where('video_call_id', $videoCall->id)
                ->where('user_id', $user->id)
                ->update(['video_enabled' => $videoEnabled]);

            return response()->json([
                'success' => true,
                'video_enabled' => $videoEnabled,
                'message' => 'Video status updated'
            ]);

        } catch (\Exception $e) {
            Log::error('Toggle video error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => 'TOGGLE_VIDEO_ERROR',
                    'message' => 'Failed to toggle video'
                ]
            ], 500);
        }
    }

    /**
     * Get call history
     */
    public function getCallHistory(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $page = $request->get('page', 1);
            $limit = $request->get('limit', 20);
            $callType = $request->get('call_type');
            $status = $request->get('status');

            $query = VideoCall::with(['caller', 'receiver', 'participants'])
                ->where(function ($q) use ($user) {
                    $q->where('caller_id', $user->id)
                      ->orWhere('receiver_id', $user->id);
                });

            if ($callType) {
                $query->where('call_type', $callType);
            }

            if ($status) {
                $query->where('status', $status);
            }

            $calls = $query->orderBy('created_at', 'desc')
                ->paginate($limit, ['*'], 'page', $page);

            return response()->json([
                'success' => true,
                'calls' => $calls->items(),
                'pagination' => [
                    'current_page' => $calls->currentPage(),
                    'last_page' => $calls->lastPage(),
                    'per_page' => $calls->perPage(),
                    'total' => $calls->total(),
                ]
            ]);

        } catch (\Exception $e) {
            Log::error('Get call history error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => 'GET_CALL_HISTORY_ERROR',
                    'message' => 'Failed to get call history'
                ]
            ], 500);
        }
    }

    /**
     * Get call statistics
     */
    public function getCallStatistics(): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $stats = [
                'total_calls' => VideoCall::where('caller_id', $user->id)
                    ->orWhere('receiver_id', $user->id)
                    ->count(),
                'total_duration' => VideoCall::where('caller_id', $user->id)
                    ->orWhere('receiver_id', $user->id)
                    ->sum('duration_seconds'),
                'video_calls' => VideoCall::where(function ($q) use ($user) {
                    $q->where('caller_id', $user->id)
                      ->orWhere('receiver_id', $user->id);
                })->where('call_type', 'video')->count(),
                'audio_calls' => VideoCall::where(function ($q) use ($user) {
                    $q->where('caller_id', $user->id)
                      ->orWhere('receiver_id', $user->id);
                })->where('call_type', 'audio')->count(),
                'completed_calls' => VideoCall::where(function ($q) use ($user) {
                    $q->where('caller_id', $user->id)
                      ->orWhere('receiver_id', $user->id);
                })->where('status', 'ended')->count(),
                'missed_calls' => VideoCall::where('receiver_id', $user->id)
                    ->where('status', 'rejected')->count(),
            ];

            return response()->json([
                'success' => true,
                'statistics' => $stats
            ]);

        } catch (\Exception $e) {
            Log::error('Get call statistics error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => 'GET_CALL_STATISTICS_ERROR',
                    'message' => 'Failed to get call statistics'
                ]
            ], 500);
        }
    }

    /**
     * Check if user is available for calls
     */
    private function isUserAvailableForCalls(int $userId): bool
    {
        $activeCall = VideoCall::where(function ($q) use ($userId) {
            $q->where('caller_id', $userId)
              ->orWhere('receiver_id', $userId);
        })->where('status', 'active')->exists();

        return !$activeCall;
    }

    /**
     * Add video call message to chat
     */
    private function addVideoCallMessageToChat(int $callerId, int $receiverId, string $callId, string $callType, ?string $subject): void
    {
        try {
            // Find or create chat between users
            $chat = DB::table('chats')
                ->where(function ($q) use ($callerId, $receiverId) {
                    $q->where('user1_id', $callerId)->where('user2_id', $receiverId);
                })
                ->orWhere(function ($q) use ($callerId, $receiverId) {
                    $q->where('user1_id', $receiverId)->where('user2_id', $callerId);
                })
                ->first();

            if (!$chat) {
                // Create new chat
                $chatId = DB::table('chats')->insertGetId([
                    'user1_id' => $callerId,
                    'user2_id' => $receiverId,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            } else {
                $chatId = $chat->id;
            }

            // Create video call message
            $callTypeText = $callType === 'video' ? 'Görüntülü' : 'Sesli';
            $messageContent = $subject ? 
                "📞 {$callTypeText} arama: {$subject}" :
                "📞 {$callTypeText} arama başlattı";

            DB::table('messages')->insert([
                'chat_id' => $chatId,
                'sender_id' => $callerId,
                'content' => $messageContent,
                'type' => 'video_call',
                'metadata' => json_encode([
                    'call_id' => $callId,
                    'call_type' => $callType,
                    'action' => 'call_started'
                ]),
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            // Update chat last message
            DB::table('chats')
                ->where('id', $chatId)
                ->update([
                    'last_message' => $messageContent,
                    'last_message_at' => now(),
                    'updated_at' => now(),
                ]);

            Log::info('Video call message added to chat', [
                'chat_id' => $chatId,
                'caller_id' => $callerId,
                'receiver_id' => $receiverId,
                'call_id' => $callId
            ]);

        } catch (\Exception $e) {
            Log::error('Failed to add video call message to chat', [
                'error' => $e->getMessage(),
                'caller_id' => $callerId,
                'receiver_id' => $receiverId,
                'call_id' => $callId
            ]);
        }
    }

    /**
     * Set user availability status
     */
    public function setAvailabilityStatus(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $validator = validator($request->all(), [
                'available' => 'required|boolean',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Validation failed',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $available = $request->available;

            // Update user availability status
            $user->update(['available_for_calls' => $available]);

            // Invalidate cache
            $this->cacheService->invalidateUserCache($user->id);

            return response()->json([
                'success' => true,
                'available' => $available,
                'message' => 'Availability status updated'
            ]);

        } catch (\Exception $e) {
            Log::error('Set availability status error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => 'SET_AVAILABILITY_ERROR',
                    'message' => 'Failed to set availability status'
                ]
            ], 500);
        }
    }

    /**
     * Check user availability
     */
    public function checkUserAvailability(int $userId): JsonResponse
    {
        try {
            $user = User::find($userId);
            if (!$user) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'USER_NOT_FOUND',
                        'message' => 'User not found'
                    ]
                ], 404);
            }

            $available = $this->isUserAvailableForCalls($userId) && 
                        ($user->available_for_calls ?? true);

            return response()->json([
                'success' => true,
                'available' => $available,
                'user_id' => $userId
            ]);

        } catch (\Exception $e) {
            Log::error('Check user availability error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => 'CHECK_AVAILABILITY_ERROR',
                    'message' => 'Failed to check user availability'
                ]
            ], 500);
        }
    }

    /**
     * Send WebRTC Offer
     * For real-time signaling between peers
     */
    public function sendOffer(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $validator = validator($request->all(), [
                'call_id' => 'required|string',
                'sdp' => 'required|string',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Validation failed',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $callId = $request->call_id;
            $sdp = $request->sdp;

            // Find the call
            $call = VideoCall::where('call_id', $callId)->first();
            
            if (!$call) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'CALL_NOT_FOUND',
                        'message' => 'Call not found'
                    ]
                ], 404);
            }

            // Broadcast offer via Pusher to the other participant
            $receiverId = ($call->caller_id == $user->id) ? $call->receiver_id : $call->caller_id;
            
            event(new \App\Events\WebRTCSignaling([
                'type' => 'offer',
                'call_id' => $callId,
                'sdp' => $sdp,
                'sender_id' => $user->id,
                'receiver_id' => $receiverId,
            ]));

            Log::info('WebRTC Offer sent', [
                'call_id' => $callId,
                'sender_id' => $user->id,
                'receiver_id' => $receiverId,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Offer sent successfully'
            ]);

        } catch (\Exception $e) {
            Log::error('Send offer error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => 'SEND_OFFER_ERROR',
                    'message' => 'Failed to send offer'
                ]
            ], 500);
        }
    }

    /**
     * Send WebRTC Answer
     */
    public function sendAnswer(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $validator = validator($request->all(), [
                'call_id' => 'required|string',
                'sdp' => 'required|string',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Validation failed',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $callId = $request->call_id;
            $sdp = $request->sdp;

            // Find the call
            $call = VideoCall::where('call_id', $callId)->first();
            
            if (!$call) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'CALL_NOT_FOUND',
                        'message' => 'Call not found'
                    ]
                ], 404);
            }

            // Broadcast answer via Pusher
            $receiverId = ($call->caller_id == $user->id) ? $call->receiver_id : $call->caller_id;
            
            event(new \App\Events\WebRTCSignaling([
                'type' => 'answer',
                'call_id' => $callId,
                'sdp' => $sdp,
                'sender_id' => $user->id,
                'receiver_id' => $receiverId,
            ]));

            Log::info('WebRTC Answer sent', [
                'call_id' => $callId,
                'sender_id' => $user->id,
                'receiver_id' => $receiverId,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Answer sent successfully'
            ]);

        } catch (\Exception $e) {
            Log::error('Send answer error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => 'SEND_ANSWER_ERROR',
                    'message' => 'Failed to send answer'
                ]
            ], 500);
        }
    }

    /**
     * Send ICE Candidate
     */
    public function sendIceCandidate(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $validator = validator($request->all(), [
                'call_id' => 'required|string',
                'candidate' => 'required|string',
                'sdp_mid' => 'nullable|string',
                'sdp_m_line_index' => 'nullable|integer',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Validation failed',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $callId = $request->call_id;
            $candidate = $request->candidate;
            $sdpMid = $request->sdp_mid;
            $sdpMLineIndex = $request->sdp_m_line_index;

            // Find the call
            $call = VideoCall::where('call_id', $callId)->first();
            
            if (!$call) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'CALL_NOT_FOUND',
                        'message' => 'Call not found'
                    ]
                ], 404);
            }

            // Broadcast ICE candidate via Pusher
            $receiverId = ($call->caller_id == $user->id) ? $call->receiver_id : $call->caller_id;
            
            event(new \App\Events\WebRTCSignaling([
                'type' => 'ice-candidate',
                'call_id' => $callId,
                'candidate' => $candidate,
                'sdp_mid' => $sdpMid,
                'sdp_m_line_index' => $sdpMLineIndex,
                'sender_id' => $user->id,
                'receiver_id' => $receiverId,
            ]));

            Log::info('ICE Candidate sent', [
                'call_id' => $callId,
                'sender_id' => $user->id,
                'receiver_id' => $receiverId,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'ICE candidate sent successfully'
            ]);

        } catch (\Exception $e) {
            Log::error('Send ICE candidate error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => 'SEND_ICE_CANDIDATE_ERROR',
                    'message' => 'Failed to send ICE candidate'
                ]
            ], 500);
        }
    }
}
