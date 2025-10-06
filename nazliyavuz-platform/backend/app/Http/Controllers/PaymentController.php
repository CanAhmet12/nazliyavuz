<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use App\Models\Reservation;
use App\Models\Payment;
use App\Services\PaytrService;

class PaymentController extends Controller
{
    protected $paytrService;

    public function __construct(PaytrService $paytrService)
    {
        $this->paytrService = $paytrService;
    }

    /**
     * Create payment for reservation
     */
    public function createPayment(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'reservation_id' => 'required|exists:reservations,id',
            'amount' => 'required|numeric|min:0.01',
            'currency' => 'sometimes|string|in:TRY',
            'description' => 'sometimes|string|max:255',
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
            $user = Auth::user();
            $reservation = Reservation::with(['teacher', 'student'])->findOrFail($request->reservation_id);

            // Check if user owns the reservation
            if ($reservation->student_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu rezervasyonu ödeyemezsiniz'
                    ]
                ], 403);
            }

            // Check if reservation is pending
            if ($reservation->status !== 'pending') {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_STATUS',
                        'message' => 'Bu rezervasyon ödenebilir durumda değil'
                    ]
                ], 400);
            }

            // Create payment record
            $payment = Payment::create([
                'reservation_id' => $reservation->id,
                'user_id' => $user->id,
                'amount' => $request->amount,
                'currency' => $request->currency ?? 'TRY',
                'status' => 'pending',
                'description' => $request->description,
                'paytr_order_id' => 'RES_' . $reservation->id . '_' . time(),
            ]);

            // Generate PayTR payment URL
            $paymentUrl = $this->paytrService->createPayment([
                'order_id' => $payment->paytr_order_id,
                'amount' => $payment->amount * 100, // Convert to kuruş
                'currency' => $payment->currency,
                'description' => $payment->description ?? "Ders Rezervasyonu - {$reservation->subject}",
                'user_name' => $user->name,
                'user_email' => $user->email,
                'user_phone' => $user->phone,
                'success_url' => config('app.frontend_url') . '/payment/success',
                'fail_url' => config('app.frontend_url') . '/payment/fail',
                'callback_url' => config('app.url') . '/api/payments/callback',
            ]);

            if (!$paymentUrl['success']) {
                $payment->update(['status' => 'failed']);
                return response()->json([
                    'error' => [
                        'code' => 'PAYMENT_CREATION_FAILED',
                        'message' => $paymentUrl['error'] ?? 'Ödeme oluşturulamadı'
                    ]
                ], 500);
            }

            // Update payment with PayTR token
            $payment->update([
                'paytr_token' => $paymentUrl['token'],
                'status' => 'processing',
            ]);

            Log::info('Payment created successfully', [
                'payment_id' => $payment->id,
                'reservation_id' => $reservation->id,
                'amount' => $payment->amount,
                'user_id' => $user->id,
            ]);

            return response()->json([
                'success' => true,
                'payment_id' => $payment->id,
                'payment_url' => $paymentUrl['payment_url'],
                'order_id' => $payment->paytr_order_id,
                'amount' => $payment->amount,
                'currency' => $payment->currency,
            ]);

        } catch (\Exception $e) {
            Log::error('Payment creation failed', [
                'error' => $e->getMessage(),
                'reservation_id' => $request->reservation_id,
                'user_id' => $user->id ?? null,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'PAYMENT_CREATION_ERROR',
                    'message' => 'Ödeme oluşturulurken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Handle PayTR callback
     */
    public function handleCallback(Request $request): JsonResponse
    {
        try {
            Log::info('PayTR callback received', $request->all());

            $validator = Validator::make($request->all(), [
                'merchant_oid' => 'required|string',
                'status' => 'required|string',
                'total_amount' => 'required|numeric',
                'hash' => 'required|string',
            ]);

            if ($validator->fails()) {
                Log::error('PayTR callback validation failed', $validator->errors()->toArray());
                return response()->json(['status' => 'fail'], 400);
            }

            // Verify hash
            $hash = base64_encode(hash_hmac('sha256', 
                $request->merchant_oid . 
                config('paytr.merchant_salt') . 
                $request->status . 
                $request->total_amount, 
                config('paytr.merchant_key'), 
                true
            ));

            if ($hash !== $request->hash) {
                Log::error('PayTR callback hash verification failed', [
                    'expected' => $hash,
                    'received' => $request->hash,
                ]);
                return response()->json(['status' => 'fail'], 400);
            }

            // Find payment
            $payment = Payment::where('paytr_order_id', $request->merchant_oid)->first();
            if (!$payment) {
                Log::error('Payment not found for PayTR callback', [
                    'merchant_oid' => $request->merchant_oid,
                ]);
                return response()->json(['status' => 'fail'], 404);
            }

            // Update payment status
            if ($request->status === 'success') {
                $payment->update([
                    'status' => 'success',
                    'transaction_id' => $request->get('payment_id'),
                    'paid_at' => now(),
                ]);

                // Update reservation status
                $payment->reservation->update(['status' => 'accepted']);

                // Send notifications
                $this->sendPaymentSuccessNotifications($payment);

                Log::info('Payment completed successfully', [
                    'payment_id' => $payment->id,
                    'reservation_id' => $payment->reservation_id,
                ]);

            } else {
                $payment->update([
                    'status' => 'failed',
                    'failed_at' => now(),
                ]);

                Log::info('Payment failed', [
                    'payment_id' => $payment->id,
                    'status' => $request->status,
                ]);
            }

            return response()->json(['status' => 'success']);

        } catch (\Exception $e) {
            Log::error('PayTR callback error', [
                'error' => $e->getMessage(),
                'request' => $request->all(),
            ]);

            return response()->json(['status' => 'fail'], 500);
        }
    }

    /**
     * Confirm payment manually
     */
    public function confirmPayment(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'reservation_id' => 'required|exists:reservations,id',
            'amount' => 'required|numeric',
            'status' => 'required|in:success,failed',
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
            $user = Auth::user();
            $reservation = Reservation::findOrFail($request->reservation_id);

            if ($reservation->student_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu rezervasyonu onaylayamazsınız'
                    ]
                ], 403);
            }

            $payment = Payment::where('reservation_id', $reservation->id)
                             ->where('user_id', $user->id)
                             ->latest()
                             ->first();

            if (!$payment) {
                return response()->json([
                    'error' => [
                        'code' => 'PAYMENT_NOT_FOUND',
                        'message' => 'Ödeme kaydı bulunamadı'
                    ]
                ], 404);
            }

            if ($request->status === 'success') {
                $payment->update([
                    'status' => 'success',
                    'paid_at' => now(),
                ]);

                $reservation->update(['status' => 'accepted']);
                $this->sendPaymentSuccessNotifications($payment);
            } else {
                $payment->update(['status' => 'failed']);
            }

            return response()->json([
                'success' => true,
                'message' => 'Ödeme durumu güncellendi',
                'payment_status' => $payment->status,
                'reservation_status' => $reservation->status,
            ]);

        } catch (\Exception $e) {
            Log::error('Payment confirmation failed', [
                'error' => $e->getMessage(),
                'reservation_id' => $request->reservation_id,
                'user_id' => $user->id ?? null,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'PAYMENT_CONFIRMATION_ERROR',
                    'message' => 'Ödeme onaylanırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get payment history
     */
    public function getPaymentHistory(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $payments = Payment::with(['reservation.teacher'])
                              ->where('user_id', $user->id)
                              ->orderBy('created_at', 'desc')
                              ->paginate(20);

            return response()->json([
                'success' => true,
                'payments' => $payments->items(),
                'pagination' => [
                    'current_page' => $payments->currentPage(),
                    'last_page' => $payments->lastPage(),
                    'per_page' => $payments->perPage(),
                    'total' => $payments->total(),
                ],
            ]);

        } catch (\Exception $e) {
            Log::error('Get payment history failed', [
                'error' => $e->getMessage(),
                'user_id' => $user->id ?? null,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'PAYMENT_HISTORY_ERROR',
                    'message' => 'Ödeme geçmişi alınırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Send payment success notifications
     */
    private function sendPaymentSuccessNotifications(Payment $payment): void
    {
        try {
            $reservation = $payment->reservation;
            
            // Notify student
            $reservation->student->notifications()->create([
                'type' => 'payment_success',
                'title' => 'Ödeme Başarılı',
                'message' => "Rezervasyonunuz için ödeme başarıyla tamamlandı. Ders: {$reservation->subject}",
                'data' => [
                    'reservation_id' => $reservation->id,
                    'payment_id' => $payment->id,
                    'amount' => $payment->amount,
                ],
            ]);

            // Notify teacher
            $reservation->teacher->user->notifications()->create([
                'type' => 'reservation_confirmed',
                'title' => 'Yeni Rezervasyon',
                'message' => "Yeni bir rezervasyonunuz onaylandı. Ders: {$reservation->subject}",
                'data' => [
                    'reservation_id' => $reservation->id,
                    'student_name' => $reservation->student->name,
                ],
            ]);

            Log::info('Payment success notifications sent', [
                'payment_id' => $payment->id,
                'reservation_id' => $reservation->id,
            ]);

        } catch (\Exception $e) {
            Log::error('Failed to send payment success notifications', [
                'error' => $e->getMessage(),
                'payment_id' => $payment->id,
            ]);
        }
    }
}
