<?php

namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use App\Models\User;

class SendPushNotification implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected User $user;
    protected string $title;
    protected string $body;
    protected array $data;

    /**
     * Create a new job instance.
     */
    public function __construct(User $user, string $title, string $body, array $data = [])
    {
        $this->user = $user;
        $this->title = $title;
        $this->body = $body;
        $this->data = $data;
    }

    /**
     * Execute the job.
     */
    public function handle(): void
    {
        try {
            // FCM Server Key - should be in environment variables
            $serverKey = config('services.fcm.server_key');
            
            if (!$serverKey) {
                Log::warning('FCM server key not configured');
                return;
            }

            // Get user's FCM tokens
            $fcmTokens = $this->user->fcm_tokens ?? [];
            
            if (empty($fcmTokens)) {
                Log::info('No FCM tokens found for user', ['user_id' => $this->user->id]);
                return;
            }

            // Prepare notification payload
            $payload = [
                'registration_ids' => $fcmTokens,
                'notification' => [
                    'title' => $this->title,
                    'body' => $this->body,
                    'icon' => config('app.url') . '/images/notification-icon.png',
                    'click_action' => config('app.frontend_url'),
                ],
                'data' => array_merge($this->data, [
                    'user_id' => $this->user->id,
                    'timestamp' => now()->toISOString(),
                ]),
                'android' => [
                    'notification' => [
                        'sound' => 'default',
                        'priority' => 'high',
                    ],
                ],
                'apns' => [
                    'payload' => [
                        'aps' => [
                            'sound' => 'default',
                            'badge' => 1,
                        ],
                    ],
                ],
            ];

            // Send to FCM
            $response = Http::withHeaders([
                'Authorization' => 'key=' . $serverKey,
                'Content-Type' => 'application/json',
            ])->post('https://fcm.googleapis.com/fcm/send', $payload);

            if ($response->successful()) {
                $result = $response->json();
                
                Log::info('Push notification sent successfully', [
                    'user_id' => $this->user->id,
                    'success_count' => $result['success'] ?? 0,
                    'failure_count' => $result['failure'] ?? 0,
                ]);

                // Remove invalid tokens
                if (isset($result['results'])) {
                    $this->removeInvalidTokens($result['results'], $fcmTokens);
                }
            } else {
                Log::error('Failed to send push notification', [
                    'user_id' => $this->user->id,
                    'status' => $response->status(),
                    'response' => $response->body(),
                ]);
            }
        } catch (\Exception $e) {
            Log::error('Push notification job failed', [
                'user_id' => $this->user->id,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);
        }
    }

    /**
     * Remove invalid FCM tokens
     */
    private function removeInvalidTokens(array $results, array $fcmTokens): void
    {
        $validTokens = [];
        
        foreach ($results as $index => $result) {
            if (!isset($result['error']) || $result['error'] !== 'NotRegistered') {
                $validTokens[] = $fcmTokens[$index];
            } else {
                Log::info('Removing invalid FCM token', [
                    'user_id' => $this->user->id,
                    'token' => $fcmTokens[$index],
                ]);
            }
        }

        // Update user's FCM tokens
        if (count($validTokens) !== count($fcmTokens)) {
            $this->user->update(['fcm_tokens' => $validTokens]);
        }
    }

    /**
     * Handle a job failure.
     */
    public function failed(\Throwable $exception): void
    {
        Log::error('Push notification job failed permanently', [
            'user_id' => $this->user->id,
            'title' => $this->title,
            'error' => $exception->getMessage(),
        ]);
    }
}