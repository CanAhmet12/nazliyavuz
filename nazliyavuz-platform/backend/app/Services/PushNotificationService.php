<?php

namespace App\Services;

use App\Models\User;
use App\Jobs\SendPushNotification;
use Illuminate\Support\Facades\Log;

class PushNotificationService
{
    /**
     * Send push notification to a user
     */
    public function sendToUser(User $user, string $title, string $body, array $data = []): bool
    {
        try {
            SendPushNotification::dispatch($user, $title, $body, $data);
            
            Log::info('Push notification queued', [
                'user_id' => $user->id,
                'title' => $title,
            ]);
            
            return true;
        } catch (\Exception $e) {
            Log::error('Failed to queue push notification', [
                'user_id' => $user->id,
                'error' => $e->getMessage(),
            ]);
            
            return false;
        }
    }

    /**
     * Send push notification to multiple users
     */
    public function sendToUsers(array $users, string $title, string $body, array $data = []): array
    {
        $results = [
            'success' => 0,
            'failed' => 0,
            'errors' => []
        ];

        foreach ($users as $user) {
            if ($this->sendToUser($user, $title, $body, $data)) {
                $results['success']++;
            } else {
                $results['failed']++;
                $results['errors'][] = [
                    'user_id' => $user->id,
                    'error' => 'Failed to queue notification'
                ];
            }
        }

        return $results;
    }

    /**
     * Send reservation notification
     */
    public function sendReservationNotification(User $user, string $type, array $reservationData): bool
    {
        $titles = [
            'new_request' => 'Yeni Rezervasyon Talebi',
            'accepted' => 'Rezervasyon Onaylandı',
            'rejected' => 'Rezervasyon Reddedildi',
            'cancelled' => 'Rezervasyon İptal Edildi',
            'reminder' => 'Rezervasyon Hatırlatması',
            'completed' => 'Rezervasyon Tamamlandı',
        ];

        $bodies = [
            'new_request' => 'Size yeni bir rezervasyon talebi geldi.',
            'accepted' => 'Rezervasyonunuz onaylandı.',
            'rejected' => 'Rezervasyonunuz reddedildi.',
            'cancelled' => 'Rezervasyonunuz iptal edildi.',
            'reminder' => 'Rezervasyonunuz yaklaşıyor.',
            'completed' => 'Rezervasyonunuz tamamlandı. Lütfen değerlendirin.',
        ];

        $title = $titles[$type] ?? 'Rezervasyon Bildirimi';
        $body = $bodies[$type] ?? 'Rezervasyonunuzla ilgili bir güncelleme var.';

        $data = array_merge($reservationData, [
            'type' => 'reservation',
            'action' => $type,
        ]);

        return $this->sendToUser($user, $title, $body, $data);
    }

    /**
     * Send rating notification
     */
    public function sendRatingNotification(User $teacher, User $student, float $rating, string $review = null): bool
    {
        $title = 'Yeni Değerlendirme';
        $body = "{$student->name} size {$rating}/5 puan verdi.";
        
        if ($review) {
            $body .= " Yorumu: " . substr($review, 0, 50) . (strlen($review) > 50 ? '...' : '');
        }

        $data = [
            'type' => 'rating',
            'student_name' => $student->name,
            'rating' => $rating,
            'review' => $review,
        ];

        return $this->sendToUser($teacher, $title, $body, $data);
    }

    /**
     * Send message notification
     */
    public function sendMessageNotification(User $recipient, User $sender, string $message): bool
    {
        $title = 'Yeni Mesaj';
        $body = "{$sender->name}: " . substr($message, 0, 50) . (strlen($message) > 50 ? '...' : '');

        $data = [
            'type' => 'message',
            'sender_id' => $sender->id,
            'sender_name' => $sender->name,
            'message_preview' => substr($message, 0, 100),
        ];

        return $this->sendToUser($recipient, $title, $body, $data);
    }

    /**
     * Send promotional notification
     */
    public function sendPromotionalNotification(array $users, string $title, string $message, array $additionalData = []): array
    {
        $data = array_merge($additionalData, [
            'type' => 'promotional',
        ]);

        return $this->sendToUsers($users, $title, $message, $data);
    }

    /**
     * Send system announcement
     */
    public function sendSystemAnnouncement(array $users, string $title, string $message): array
    {
        $data = [
            'type' => 'announcement',
            'priority' => 'high',
        ];

        return $this->sendToUsers($users, $title, $message, $data);
    }

    /**
     * Register FCM token for user
     */
    public function registerFCMToken(User $user, string $token): bool
    {
        try {
            $currentTokens = $user->fcm_tokens ?? [];
            
            // Add token if not already present
            if (!in_array($token, $currentTokens)) {
                $currentTokens[] = $token;
                $user->update(['fcm_tokens' => $currentTokens]);
                
                Log::info('FCM token registered', [
                    'user_id' => $user->id,
                    'token_count' => count($currentTokens),
                ]);
            }
            
            return true;
        } catch (\Exception $e) {
            Log::error('Failed to register FCM token', [
                'user_id' => $user->id,
                'error' => $e->getMessage(),
            ]);
            
            return false;
        }
    }

    /**
     * Unregister FCM token for user
     */
    public function unregisterFCMToken(User $user, string $token): bool
    {
        try {
            $currentTokens = $user->fcm_tokens ?? [];
            $filteredTokens = array_filter($currentTokens, fn($t) => $t !== $token);
            
            if (count($filteredTokens) !== count($currentTokens)) {
                $user->update(['fcm_tokens' => array_values($filteredTokens)]);
                
                Log::info('FCM token unregistered', [
                    'user_id' => $user->id,
                    'token_count' => count($filteredTokens),
                ]);
            }
            
            return true;
        } catch (\Exception $e) {
            Log::error('Failed to unregister FCM token', [
                'user_id' => $user->id,
                'error' => $e->getMessage(),
            ]);
            
            return false;
        }
    }
}
