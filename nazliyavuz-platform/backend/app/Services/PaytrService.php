<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class PaytrService
{
    protected $merchantId;
    protected $merchantKey;
    protected $merchantSalt;
    protected $testMode;

    public function __construct()
    {
        $this->merchantId = config('paytr.merchant_id');
        $this->merchantKey = config('paytr.merchant_key');
        $this->merchantSalt = config('paytr.merchant_salt');
        $this->testMode = config('paytr.test_mode', true);
    }

    /**
     * Create payment with PayTR
     */
    public function createPayment(array $paymentData): array
    {
        try {
            // Prepare payment parameters
            $params = [
                'merchant_id' => $this->merchantId,
                'user_ip' => request()->ip(),
                'merchant_oid' => $paymentData['order_id'],
                'email' => $paymentData['user_email'],
                'payment_amount' => $paymentData['amount'],
                'paytr_token' => $this->generatePaytrToken($paymentData),
                'user_basket' => base64_encode(json_encode([
                    [
                        $paymentData['description'],
                        1,
                        $paymentData['amount'] / 100, // Convert back to TL
                    ]
                ])),
                'debug_on' => $this->testMode ? 1 : 0,
                'no_installment' => 0,
                'max_installment' => 0,
                'user_name' => $paymentData['user_name'],
                'user_address' => 'Türkiye',
                'user_phone' => $paymentData['user_phone'] ?? '',
                'merchant_ok_url' => $paymentData['success_url'],
                'merchant_fail_url' => $paymentData['fail_url'],
                'timeout_limit' => 30,
                'currency' => $paymentData['currency'] ?? 'TL',
                'test_mode' => $this->testMode ? '1' : '0',
            ];

            Log::info('PayTR payment request', [
                'order_id' => $paymentData['order_id'],
                'amount' => $paymentData['amount'],
                'test_mode' => $this->testMode,
            ]);

            // Send request to PayTR
            $response = Http::asForm()->post('https://www.paytr.com/odeme/api/get-token', $params);

            if (!$response->successful()) {
                throw new \Exception('PayTR API request failed: ' . $response->body());
            }

            $result = $response->json();

            if ($result['status'] === 'success') {
                return [
                    'success' => true,
                    'token' => $result['token'],
                    'payment_url' => 'https://www.paytr.com/odeme/guvenli/' . $result['token'],
                ];
            } else {
                return [
                    'success' => false,
                    'error' => $result['reason'] ?? 'PayTR ödeme oluşturulamadı',
                ];
            }

        } catch (\Exception $e) {
            Log::error('PayTR payment creation failed', [
                'error' => $e->getMessage(),
                'order_id' => $paymentData['order_id'] ?? null,
            ]);

            return [
                'success' => false,
                'error' => 'Ödeme oluşturulurken bir hata oluştu: ' . $e->getMessage(),
            ];
        }
    }

    /**
     * Generate PayTR token
     */
    private function generatePaytrToken(array $paymentData): string
    {
        $hashStr = $this->merchantId . 
                   $paymentData['user_ip'] . 
                   $paymentData['order_id'] . 
                   $paymentData['user_email'] . 
                   $paymentData['amount'] . 
                   $this->merchantSalt;

        return base64_encode(hash_hmac('sha256', $hashStr, $this->merchantKey, true));
    }

    /**
     * Verify PayTR callback
     */
    public function verifyCallback(array $callbackData): array
    {
        try {
            $expectedHash = base64_encode(hash_hmac('sha256', 
                $callbackData['merchant_oid'] . 
                $this->merchantSalt . 
                $callbackData['status'] . 
                $callbackData['total_amount'], 
                $this->merchantKey, 
                true
            ));

            if ($expectedHash !== $callbackData['hash']) {
                return [
                    'success' => false,
                    'error' => 'Hash verification failed',
                ];
            }

            return [
                'success' => true,
                'verified' => true,
                'data' => $callbackData,
            ];

        } catch (\Exception $e) {
            Log::error('PayTR callback verification failed', [
                'error' => $e->getMessage(),
                'callback_data' => $callbackData,
            ]);

            return [
                'success' => false,
                'error' => 'Callback verification failed: ' . $e->getMessage(),
            ];
        }
    }

    /**
     * Get payment status
     */
    public function getPaymentStatus(string $merchantOid): array
    {
        try {
            $hashStr = $this->merchantId . $merchantOid . $this->merchantSalt;
            $paytrToken = base64_encode(hash_hmac('sha256', $hashStr, $this->merchantKey, true));

            $response = Http::asForm()->post('https://www.paytr.com/odeme/api/check-status', [
                'merchant_id' => $this->merchantId,
                'merchant_oid' => $merchantOid,
                'paytr_token' => $paytrToken,
            ]);

            if (!$response->successful()) {
                throw new \Exception('PayTR status check failed: ' . $response->body());
            }

            $result = $response->json();

            return [
                'success' => true,
                'status' => $result['status'] ?? 'unknown',
                'data' => $result,
            ];

        } catch (\Exception $e) {
            Log::error('PayTR status check failed', [
                'error' => $e->getMessage(),
                'merchant_oid' => $merchantOid,
            ]);

            return [
                'success' => false,
                'error' => 'Status check failed: ' . $e->getMessage(),
            ];
        }
    }

    /**
     * Test payment (for development)
     */
    public function createTestPayment(array $paymentData): array
    {
        if (!$this->testMode) {
            return [
                'success' => false,
                'error' => 'Test mode is disabled',
            ];
        }

        // Return mock successful payment for testing
        return [
            'success' => true,
            'token' => 'test_token_' . time(),
            'payment_url' => 'https://www.paytr.com/odeme/guvenli/test_token_' . time(),
            'test_mode' => true,
        ];
    }

    /**
     * Refund payment
     */
    public function refundPayment(string $merchantOid, float $amount): array
    {
        try {
            $hashStr = $this->merchantId . $merchantOid . $this->merchantSalt;
            $paytrToken = base64_encode(hash_hmac('sha256', $hashStr, $this->merchantKey, true));

            $response = Http::asForm()->post('https://www.paytr.com/odeme/api/refund', [
                'merchant_id' => $this->merchantId,
                'merchant_oid' => $merchantOid,
                'amount' => $amount * 100, // Convert to kuruş
                'paytr_token' => $paytrToken,
            ]);

            if (!$response->successful()) {
                throw new \Exception('PayTR refund failed: ' . $response->body());
            }

            $result = $response->json();

            return [
                'success' => $result['status'] === 'success',
                'message' => $result['message'] ?? 'İade işlemi tamamlandı',
                'data' => $result,
            ];

        } catch (\Exception $e) {
            Log::error('PayTR refund failed', [
                'error' => $e->getMessage(),
                'merchant_oid' => $merchantOid,
                'amount' => $amount,
            ]);

            return [
                'success' => false,
                'error' => 'İade işlemi başarısız: ' . $e->getMessage(),
            ];
        }
    }
}
