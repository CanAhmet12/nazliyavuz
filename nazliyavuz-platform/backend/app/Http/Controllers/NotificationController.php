<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Log;
use App\Models\Notification;

class NotificationController extends Controller
{
    /**
     * Get user's notifications
     */
    public function index(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $query = Notification::where('user_id', $user->id);
            
            // Apply type filter
            if ($request->has('type') && $request->type) {
                $query->where('type', $request->type);
            }
            
            // Apply read status filter
            if ($request->has('is_read') && $request->is_read !== null) {
                $query->where('is_read', $request->boolean('is_read'));
            }
            
            // Order by most recent first
            $query->orderBy('created_at', 'desc');
            
            $notifications = $query->paginate($request->get('per_page', 20));
            
            return response()->json([
                'success' => true,
                'notifications' => $notifications->items(),
                'pagination' => [
                    'current_page' => $notifications->currentPage(),
                    'last_page' => $notifications->lastPage(),
                    'per_page' => $notifications->perPage(),
                    'total' => $notifications->total(),
                ],
                'unread_count' => Notification::where('user_id', $user->id)->where('is_read', false)->count(),
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error getting notifications: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'NOTIFICATIONS_FETCH_ERROR',
                    'message' => 'Bildirimler yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Mark notification as read
     */
    public function markAsRead(Notification $notification): JsonResponse
    {
        try {
            $user = Auth::user();
            
            // Check if user owns this notification
            if ($notification->user_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu bildirimi okuma yetkiniz yok'
                    ]
                ], 403);
            }
            
            $notification->markAsRead();
            
            return response()->json([
                'success' => true,
                'message' => 'Bildirim okundu olarak işaretlendi',
                'notification' => $notification
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error marking notification as read: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'NOTIFICATION_READ_ERROR',
                    'message' => 'Bildirim okundu olarak işaretlenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Mark all notifications as read
     */
    public function markAllAsRead(): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $updated = Notification::where('user_id', $user->id)
                ->where('is_read', false)
                ->update([
                    'is_read' => true,
                    'read_at' => now(),
                ]);
            
            return response()->json([
                'success' => true,
                'message' => "$updated bildirim okundu olarak işaretlendi",
                'updated_count' => $updated
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error marking all notifications as read: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'NOTIFICATIONS_READ_ERROR',
                    'message' => 'Bildirimler okundu olarak işaretlenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Delete notification
     */
    public function destroy(Notification $notification): JsonResponse
    {
        try {
            $user = Auth::user();
            
            // Check if user owns this notification
            if ($notification->user_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu bildirimi silme yetkiniz yok'
                    ]
                ], 403);
            }
            
            $notification->delete();
            
            return response()->json([
                'success' => true,
                'message' => 'Bildirim silindi'
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error deleting notification: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'NOTIFICATION_DELETE_ERROR',
                    'message' => 'Bildirim silinirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get notification statistics
     */
    public function getStatistics(): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $total = Notification::where('user_id', $user->id)->count();
            $unread = Notification::where('user_id', $user->id)->where('is_read', false)->count();
            $read = $total - $unread;
            
            // Get notifications by type
            $byType = Notification::where('user_id', $user->id)
                ->selectRaw('type, COUNT(*) as count')
                ->groupBy('type')
                ->get()
                ->pluck('count', 'type');
            
            return response()->json([
                'success' => true,
                'statistics' => [
                    'total' => $total,
                    'unread' => $unread,
                    'read' => $read,
                    'by_type' => $byType,
                ]
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error getting notification statistics: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'NOTIFICATION_STATS_ERROR',
                    'message' => 'Bildirim istatistikleri yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }
}