<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\Reservation;
use App\Models\VideoCall;
use App\Models\VideoCallParticipant;
use App\Services\NotificationService;
use App\Services\AdvancedCacheService;
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
    protected AdvancedCacheService $cacheService;

    public function __construct(NotificationService $notificationService, AdvancedCacheService $cacheService)
    {
        $this->notificationService = $notificationService;
        $this->cacheService = $cacheService;
    }

    /**
     * Start a video call
     */
    public function startCall(Request $request): JsonResponse
    {
        try {
            Log::info('Video call start attempt', ['request_data' => $request->all()]);
            $user = Auth::user();
            Log::info('User authenticated', ['user_id' => $user->id]);
            
            $validator = validator($request->all(), [
                'receiver_id' => 'required|integer|exists:users,id',
                'call_type' => 'required|in:video,audio',
                'call_id' => 'nullable|string',
                'subject' => 'nullable|string|max:255',
                'reservation_id' => 'nullable|integer|exists:reservations,id',
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

            $receiverId = $request->receiver_id;
            $callType = $request->call_type;
            $callId = $request->call_id ?? 'call_' . Str::uuid();
            $subject = $request->subject;
            $reservationId = $request->reservation_id;

            // Check if receiver exists and is available
            $receiver = User::find($receiverId);
            if (!$receiver) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'USER_NOT_FOUND',
                        'message' => 'Receiver not found'
                    ]
                ], 404);
            }

            // Check if receiver is available for calls
            if (!$this->isUserAvailableForCalls($receiverId)) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'code' => 'USER_NOT_AVAILABLE',
                        'message' => 'User is not available for calls'
                    ]
                ], 400);
            }

            // Create video call record
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
            Log::error('Start video call error', [
                'message' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
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
        // Check if user is online and not in another call
        $activeCall = VideoCall::where(function ($q) use ($userId) {
            $q->where('caller_id', $userId)
              ->orWhere('receiver_id', $userId);
        })->whereIn('status', ['initiated', 'active'])->exists();

        return !$activeCall;
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
}
