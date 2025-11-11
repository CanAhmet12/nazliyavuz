<?php

namespace App\Services;

use App\Models\User;
use App\Jobs\SendPushNotification;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class PushNotificationService
{
    public function isConfigured(): bool
    {
        return !empty(config('services.fcm.server_key'));
    }

    public function getStatus(): array
    {
        $serverKey = config('services.fcm.server_key');
        $senderId = config('services.fcm.sender_id');

        $missing = [];
        if (empty($serverKey)) {
            $missing[] = 'server_key';
        }
        if (empty($senderId)) {
            $missing[] = 'sender_id';
        }

        return [
            'configured' => $this->isConfigured(),
            'details' => [
                'server_key_set' => !empty($serverKey),
                'sender_id' => $senderId,
            ],
            'missing' => $missing,
        ];
    }

    /**
     * Send push notification to a user (queued).
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
     * Send push notification directly to a specific device token.
     *
     * @return array{success: bool, response?: mixed, status?: int, error?: string}
     */
    public function sendToToken(string $token, string $title, string $body, array $data = []): array
    {
        $serverKey = config('services.fcm.server_key');

        if (empty($serverKey)) {
            return [
                'success' => false,
                'error' => 'FCM server key is missing.',
            ];
        }

        $payload = [
            'to' => $token,
            'notification' => [
                'title' => $title,
                'body' => $body,
                'icon' => config('app.url') . '/images/notification-icon.png',
                'click_action' => config('app.frontend_url'),
            ],
            'data' => array_merge($data, [
                'timestamp' => now()->toISOString(),
            ]),
        ];

        try {
            $response = Http::withHeaders([
                'Authorization' => 'key=' . $serverKey,
                'Content-Type' => 'application/json',
            ])->post('https://fcm.googleapis.com/fcm/send', $payload);

            if ($response->successful()) {
                return [
                    'success' => true,
                    'response' => $response->json(),
                ];
            }

            $bodyResponse = $response->json();
            $errorMessage = is_array($bodyResponse)
                ? ($bodyResponse['error'] ?? $bodyResponse['results'][0]['error'] ?? $response->body())
                : $response->body();

            Log::error('Push notification direct send failed', [
                'status' => $response->status(),
                'response' => $response->body(),
            ]);

            return [
                'success' => false,
                'status' => $response->status(),
                'error' => $errorMessage,
            ];
        } catch (\Throwable $exception) {
            Log::error('Push notification direct send threw exception', [
                'error' => $exception->getMessage(),
            ]);

            return [
                'success' => false,
                'error' => $exception->getMessage(),
            ];
        }
    }

    /**
     * Send push notification to multiple users.
     */
    public function sendToUsers(array $users, string $title, string $body, array $data = []): array
    {
        $results = [
            'success' => 0,
            'failed' => 0,
            'errors' => [],
        ];

        foreach ($users as $user) {
            if ($this->sendToUser($user, $title, $body, $data)) {
                $results['success']++;
            } else {
                $results['failed']++;
                $results['errors'][] = [
                    'user_id' => $user->id,
                    'error' => 'Failed to queue notification',
                ];
            }
        }

        return $results;
    }

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

    public function sendRatingNotification(User $teacher, User $student, float $rating, string $review = null): bool
    {
        $title = 'Yeni Değerlendirme';
        $body = "{$student->name} size {$rating}/5 puan verdi.";

        if ($review) {
            $body .= ' Yorumu: ' . substr($review, 0, 50) . (strlen($review) > 50 ? '...' : '');
        }

        $data = [
            'type' => 'rating',
            'student_name' => $student->name,
            'rating' => $rating,
            'review' => $review,
        ];

        return $this->sendToUser($teacher, $title, $body, $data);
    }

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

    public function sendPromotionalNotification(array $users, string $title, string $message, array $additionalData = []): array
    {
        $data = array_merge($additionalData, [
            'type' => 'promotional',
        ]);

        return $this->sendToUsers($users, $title, $message, $data);
    }

    public function sendSystemAnnouncement(array $users, string $title, string $message): array
    {
        $data = [
            'type' => 'announcement',
            'priority' => 'high',
        ];

        return $this->sendToUsers($users, $title, $message, $data);
    }

    public function registerFCMToken(User $user, string $token): bool
    {
        try {
            $currentTokens = $user->fcm_tokens ?? [];

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

    public function unregisterFCMToken(User $user, string $token): bool
    {
        try {
            $currentTokens = $user->fcm_tokens ?? [];
            $filteredTokens = array_filter($currentTokens, fn ($t) => $t !== $token);

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
