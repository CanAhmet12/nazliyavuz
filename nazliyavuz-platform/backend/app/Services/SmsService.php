<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class SmsService
{
    public function isConfigured(): bool
    {
        $provider = config('services.sms.provider', 'mock');

        if ($provider === 'twilio') {
            return !empty(config('services.sms.twilio.account_sid'))
                && !empty(config('services.sms.twilio.auth_token'))
                && !empty(config('services.sms.twilio.from'));
        }

        return false;
    }

    public function getStatus(): array
    {
        $provider = config('services.sms.provider', 'mock');

        $status = [
            'configured' => $this->isConfigured(),
            'provider' => $provider,
            'details' => [
                'twilio_account_sid' => config('services.sms.twilio.account_sid'),
                'twilio_auth_token_set' => !empty(config('services.sms.twilio.auth_token')),
                'twilio_from' => config('services.sms.twilio.from'),
            ],
            'missing' => [],
        ];

        if ($provider !== 'twilio') {
            $status['missing'][] = 'provider';
        } else {
            if (empty(config('services.sms.twilio.account_sid'))) {
                $status['missing'][] = 'twilio_account_sid';
            }
            if (empty(config('services.sms.twilio.auth_token'))) {
                $status['missing'][] = 'twilio_auth_token';
            }
            if (empty(config('services.sms.twilio.from'))) {
                $status['missing'][] = 'twilio_from';
            }
        }

        return $status;
    }

    /**
     * Send SMS using the configured provider.
     *
     * @return array{success: bool, response?: mixed, status?: int, error?: string}
     */
    public function send(string $to, string $message): array
    {
        $provider = config('services.sms.provider', 'mock');

        if ($provider === 'twilio') {
            return $this->sendViaTwilio($to, $message);
        }

        Log::warning('SMS provider not configured', [
            'provider' => $provider,
            'to' => $to,
        ]);

        return [
            'success' => false,
            'error' => 'SMS servis sağlayıcısı yapılandırılmamış.',
        ];
    }

    protected function sendViaTwilio(string $to, string $message): array
    {
        $accountSid = config('services.sms.twilio.account_sid');
        $authToken = config('services.sms.twilio.auth_token');
        $from = config('services.sms.twilio.from');

        if (!$accountSid || !$authToken || !$from) {
            return [
                'success' => false,
                'error' => 'Twilio ayarları eksik.',
            ];
        }

        try {
            $response = Http::withBasicAuth($accountSid, $authToken)
                ->asForm()
                ->post(sprintf('https://api.twilio.com/2010-04-01/Accounts/%s/Messages.json', $accountSid), [
                    'From' => $from,
                    'To' => $to,
                    'Body' => $message,
                ]);

            if ($response->successful()) {
                return [
                    'success' => true,
                    'response' => $response->json(),
                ];
            }

            $body = $response->json();
            $errorMessage = is_array($body) ? ($body['message'] ?? $response->body()) : $response->body();

            Log::error('Twilio SMS failed', [
                'status' => $response->status(),
                'response' => $response->body(),
            ]);

            return [
                'success' => false,
                'status' => $response->status(),
                'error' => $errorMessage,
            ];
        } catch (\Throwable $exception) {
            Log::error('Twilio SMS exception', [
                'error' => $exception->getMessage(),
            ]);

            return [
                'success' => false,
                'error' => $exception->getMessage(),
            ];
        }
    }
}

