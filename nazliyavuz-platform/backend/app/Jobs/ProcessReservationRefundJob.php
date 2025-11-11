<?php

namespace App\Jobs;

use App\Models\ReservationRefund;
use App\Services\ReservationRefundService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class ProcessReservationRefundJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;

    public ?ReservationRefund $refund = null;

    /**
     * Create a new job instance.
     */
    public function __construct(ReservationRefund $refund)
    {
        $this->refund = $refund;
        $this->onQueue('payments');
    }

    /**
     * Execute the job.
     */
    public function handle(ReservationRefundService $refundService): void
    {
        if (!$this->refund) {
            return;
        }

        $refund = ReservationRefund::find($this->refund->id);

        if (!$refund) {
            return;
        }

        $result = $refundService->processRefund($refund);

        if (!($result['success'] ?? false) && $refund->attempts < $refund->max_attempts) {
            $this->release(120); // retry after 2 minutes
        }
    }

    public function failed(\Throwable $exception): void
    {
        if (!$this->refund) {
            return;
        }

        try {
            $refund = ReservationRefund::find($this->refund->id);
            if ($refund) {
                $refund->status = 'failed';
                $refund->failure_message = $exception->getMessage();
                $refund->save();
            }
        } catch (\Throwable $e) {
            Log::error('Failed to mark reservation refund as failed', [
                'refund_id' => $this->refund?->id,
                'error' => $e->getMessage(),
            ]);
        }

        Log::error('ProcessReservationRefundJob failed', [
            'refund_id' => $this->refund?->id,
            'error' => $exception->getMessage(),
        ]);
    }
}

