<?php

namespace App\Services;

use App\Models\AuditLog;
use App\Models\Payment;
use App\Models\Reservation;
use App\Models\ReservationRefund;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class ReservationRefundService
{
    public function __construct(
        protected PaytrService $paytrService,
        protected NotificationService $notificationService
    ) {
    }

    /**
     * Create refund record for reservation.
     *
     * @param array<string, mixed> $attributes
     */
    public function createRefund(
        Reservation $reservation,
        Payment $payment,
        array $attributes
    ): ReservationRefund {
        return ReservationRefund::create([
            'reservation_id' => $reservation->id,
            'payment_id' => $payment->id,
            'amount' => $attributes['amount'],
            'currency' => $attributes['currency'] ?? ($reservation->currency ?? $payment->currency ?? 'TRY'),
            'reason' => $attributes['reason'] ?? null,
            'status' => 'pending',
            'notify_participants' => (bool) ($attributes['notify_participants'] ?? true),
            'cancel_reservation' => (bool) ($attributes['cancel_reservation'] ?? false),
            'attempts' => 0,
            'max_attempts' => $attributes['max_attempts'] ?? 3,
            'provider_name' => $attributes['provider_name'] ?? ($payment->paytr_order_id ? 'paytr' : 'manual'),
            'provider_payload' => $attributes['provider_payload'] ?? null,
            'meta' => $attributes['meta'] ?? [],
            'created_by' => $attributes['created_by'] ?? null,
        ]);
    }

    /**
     * Process reservation refund using payment provider.
     */
    public function processRefund(ReservationRefund $refund): array
    {
        $refund->refresh();
        $reservation = $refund->reservation;
        $payment = $refund->payment;

        if (!$reservation || !$payment) {
            $refund->status = 'failed';
            $refund->failure_message = 'Reservation or payment record missing.';
            $refund->save();

            return [
                'success' => false,
                'code' => 'MISSING_RECORDS',
                'message' => 'Reservation or payment record missing.',
            ];
        }

        if (!in_array($refund->status, ['pending', 'processing'], true)) {
            return [
                'success' => $refund->status === 'completed',
                'status' => $refund->status,
            ];
        }

        return DB::transaction(function () use ($refund, $reservation, $payment) {
            $refund->status = 'processing';
            $refund->attempts += 1;
            $refund->last_attempt_at = now();
            $refund->save();

            $paytrResult = null;
            $providerReference = null;

            if ($payment->paytr_order_id) {
                $paytrResult = $this->paytrService->refundPayment(
                    $payment->paytr_order_id,
                    (float) $refund->amount,
                    $refund->reason
                );

                if (!($paytrResult['success'] ?? false)) {
                $refund->status = $refund->attempts >= $refund->max_attempts ? 'failed' : 'pending';
                    $refund->failure_code = $paytrResult['code'] ?? 'PAYTR_ERROR';
                    $refund->failure_message = $paytrResult['message'] ?? 'PayTR refund unsuccessful';
                    $refund->provider_response = $paytrResult['response'] ?? $paytrResult;
                    $refund->save();

                    return [
                        'success' => false,
                        'code' => 'PAYTR_ERROR',
                        'message' => $refund->failure_message,
                        'response' => $paytrResult,
                    ];
                }

                $providerReference = $paytrResult['response']['refund_id'] ?? null;
            }

            $existingRefund = (float) ($reservation->refund_amount ?? 0);
            $maxRefund = (float) ($reservation->price ?? $payment->amount ?? $refund->amount);
            $newTotalRefunded = $existingRefund + (float) $refund->amount;
            $isFullRefund = abs($newTotalRefunded - $maxRefund) < 0.01;

            $paymentData = $payment->payment_data ?? [];
            $refundHistory = $paymentData['refund_history'] ?? [];
            $historyEntry = [
                'amount' => (float) $refund->amount,
                'reason' => $refund->reason,
                'refunded_at' => now()->toIso8601String(),
                'attempts' => $refund->attempts,
                'admin_id' => $refund->created_by,
            ];

            if ($paytrResult) {
                $historyEntry['provider'] = $paytrResult;
            }

            $refundHistory[] = $historyEntry;
            $paymentData['refund_history'] = $refundHistory;
            $payment->payment_data = $paymentData;

            if ($isFullRefund) {
                $payment->status = 'refunded';
            }

            $payment->save();

            $reservation->refund_amount = $newTotalRefunded;
            $reservation->refund_reason = $refund->reason;
            $reservation->refunded_at = now();
            $reservation->payment_status = $isFullRefund ? 'refunded' : 'partial_refund';

            if ($refund->cancel_reservation && $reservation->status !== 'cancelled') {
                $reservation->status = 'cancelled';
                $reservation->cancelled_by_id = $refund->created_by;
                $reservation->cancelled_reason = $reservation->cancelled_reason ?? $refund->reason;
                $reservation->cancelled_at = $reservation->cancelled_at ?? now();
            }

            $reservation->save();

            $refund->status = 'completed';
            $refund->processed_at = now();
            $refund->provider_response = $paytrResult['response'] ?? $paytrResult;
            $refund->provider_reference = $providerReference;
            $refund->save();

            if ($refund->notify_participants) {
                $this->notifyParticipants($reservation, (float) $refund->amount, $refund->reason);
            }

            AuditLog::createLog(
                $refund->created_by,
                'reservation_refund_processed',
                ReservationRefund::class,
                $refund->id,
                [
                    'reservation_id' => $reservation->id,
                    'payment_id' => $payment->id,
                    'amount' => (float) $refund->amount,
                    'currency' => $refund->currency,
                    'status' => $refund->status,
                    'provider_reference' => $refund->provider_reference,
                ]
            );

            return [
                'success' => true,
                'status' => 'completed',
                'paytr' => $paytrResult,
                'reservation' => $reservation->fresh([
                    'student',
                    'teacher',
                    'category',
                    'payments',
                    'refunds',
                ]),
                'refund' => $refund->fresh(),
            ];
        });
    }

    /**
     * Notify participants about refund completion.
     */
    protected function notifyParticipants(Reservation $reservation, float $amount, ?string $reason = null): void
    {
        $message = sprintf(
            '%.2f %s tutarındaki ödemeniz iade edildi.',
            $amount,
            $reservation->currency ?? 'TRY'
        );

        try {
            if ($reservation->student) {
                $this->notificationService->sendCompleteNotification(
                    $reservation->student,
                    'reservation_refund',
                    '💸 Ödeme İadesi Tamamlandı',
                    $message,
                    [
                        'reservation_id' => $reservation->id,
                        'refund_amount' => $amount,
                        'refund_reason' => $reason,
                    ]
                );
            }

            if ($reservation->teacher) {
                $this->notificationService->sendCompleteNotification(
                    $reservation->teacher,
                    'reservation_refund',
                    '💸 Rezervasyon İadesi',
                    'Öğrenci ödemesi iade edildi.',
                    [
                        'reservation_id' => $reservation->id,
                        'refund_amount' => $amount,
                        'refund_reason' => $reason,
                    ]
                );
            }
        } catch (\Throwable $exception) {
            Log::warning('Refund notification failed', [
                'reservation_id' => $reservation->id,
                'error' => $exception->getMessage(),
            ]);
        }
    }
}

