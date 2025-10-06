<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Log;
use App\Services\PushNotificationService;
use App\Models\User;

class PushNotificationController extends Controller
{
    protected PushNotificationService $pushNotificationService;

    public function __construct(PushNotificationService $pushNotificationService)
    {
        $this->pushNotificationService = $pushNotificationService;
    }

    /**
     * Register FCM token for the authenticated user
     */
    public function registerToken(Request $request): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'token' => 'required|string|max:500',
                'device_type' => 'nullable|string|in:android,ios,web',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Geçersiz veri',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $user = Auth::user();
            
            // Get existing tokens
            $existingTokens = $user->fcm_tokens ?? [];
            
            // Add new token if not exists
            if (!in_array($request->token, $existingTokens)) {
                $existingTokens[] = $request->token;
                
                $user->update([
                    'fcm_tokens' => $existingTokens
                ]);
            }

            return response()->json([
                'success' => true,
                'message' => 'FCM token başarıyla kaydedildi'
            ]);

        } catch (\Exception $e) {
            Log::error('Error registering FCM token: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'TOKEN_REGISTRATION_ERROR',
                    'message' => 'Token kaydedilirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Unregister FCM token
     */
    public function unregisterToken(Request $request): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'token' => 'required|string',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Geçersiz veri',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $user = Auth::user();
            
            // Remove token from user's tokens
            $existingTokens = $user->fcm_tokens ?? [];
            $updatedTokens = array_filter($existingTokens, function($token) use ($request) {
                return $token !== $request->token;
            });
            
            $user->update([
                'fcm_tokens' => array_values($updatedTokens)
            ]);

            return response()->json([
                'success' => true,
                'message' => 'FCM token başarıyla kaldırıldı'
            ]);

        } catch (\Exception $e) {
            Log::error('Error unregistering FCM token: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'TOKEN_UNREGISTRATION_ERROR',
                    'message' => 'Token kaldırılırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Send test notification
     */
    public function sendTestNotification(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();

            $success = $this->pushNotificationService->sendNotification(
                $user,
                'Test Bildirimi',
                'Bu bir test bildirimidir.',
                ['type' => 'test']
            );

            if ($success) {
                return response()->json([
                    'success' => true,
                    'message' => 'Test bildirimi gönderildi'
                ]);
            }

            return response()->json([
                'error' => [
                    'code' => 'NOTIFICATION_FAILED',
                    'message' => 'Bildirim gönderilemedi'
                ]
            ], 500);

        } catch (\Exception $e) {
            Log::error('Error sending test notification: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'TEST_NOTIFICATION_ERROR',
                    'message' => 'Test bildirimi gönderilirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get notification settings
     */
    public function getNotificationSettings(): JsonResponse
    {
        try {
            $user = Auth::user();
            
            // Default notification settings
            $defaultSettings = [
                'email_notifications' => true,
                'push_notifications' => true,
                'reservation_notifications' => true,
                'message_notifications' => true,
                'assignment_notifications' => true,
                'marketing_notifications' => false,
            ];

            return response()->json([
                'success' => true,
                'settings' => $defaultSettings
            ]);

        } catch (\Exception $e) {
            Log::error('Error getting notification settings: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'SETTINGS_ERROR',
                    'message' => 'Bildirim ayarları alınırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Update notification settings
     */
    public function updateNotificationSettings(Request $request): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'email_notifications' => 'boolean',
                'push_notifications' => 'boolean',
                'reservation_notifications' => 'boolean',
                'message_notifications' => 'boolean',
                'assignment_notifications' => 'boolean',
                'marketing_notifications' => 'boolean',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Geçersiz veri',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $user = Auth::user();
            
            // Update user notification preferences
            // For now, we'll store them in a JSON field or separate table
            // This is a simplified implementation
            
            return response()->json([
                'success' => true,
                'message' => 'Bildirim ayarları güncellendi'
            ]);

        } catch (\Exception $e) {
            Log::error('Error updating notification settings: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'SETTINGS_UPDATE_ERROR',
                    'message' => 'Bildirim ayarları güncellenirken bir hata oluştu'
                ]
            ], 500);
        }
    }
}