<?php

namespace App\Observers;

use App\Models\Reservation;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

class ReservationObserver
{
    /**
     * Handle the Reservation "created" event.
     */
    public function created(Reservation $reservation): void
    {
        $this->clearReservationCache($reservation);
        
        Log::info('Reservation created - cache cleared', [
            'reservation_id' => $reservation->id,
            'teacher_id' => $reservation->teacher_id,
            'student_id' => $reservation->student_id,
        ]);
    }

    /**
     * Handle the Reservation "updated" event.
     */
    public function updated(Reservation $reservation): void
    {
        $this->clearReservationCache($reservation);
        
        // Check if status changed to cancelled
        if ($reservation->status === 'cancelled' && $reservation->getOriginal('status') !== 'cancelled') {
            // Calculate and apply cancellation fee
            $cancellationInfo = $reservation->calculateCancellationFee();
            
            $reservation->update([
                'cancellation_fee' => $cancellationInfo['fee'],
                'refund_amount' => $cancellationInfo['refund'],
                'cancelled_at' => now(),
            ]);

            Log::info('Reservation cancelled with fee calculated', [
                'reservation_id' => $reservation->id,
                'cancellation_fee' => $cancellationInfo['fee'],
                'refund_amount' => $cancellationInfo['refund'],
                'policy' => $cancellationInfo['policy'],
            ]);
        }
        
        Log::debug('Reservation updated - cache cleared', [
            'reservation_id' => $reservation->id,
            'changed_fields' => array_keys($reservation->getDirty()),
        ]);
    }

    /**
     * Handle the Reservation "deleted" event.
     */
    public function deleted(Reservation $reservation): void
    {
        $this->clearReservationCache($reservation);
        
        Log::info('Reservation deleted - cache cleared', [
            'reservation_id' => $reservation->id,
        ]);
    }

    /**
     * Clear all related reservation caches
     */
    private function clearReservationCache(Reservation $reservation): void
    {
        try {
            // Tag-based cache clear (Redis/Memcached)
            if (config('cache.default') !== 'file') {
                Cache::tags([
                    'reservations',
                    'user_' . $reservation->teacher_id,
                    'user_' . $reservation->student_id,
                ])->flush();
            }

            // Key-based cache clear (all drivers)
            $keysToDelete = [
                'reservations:teacher:' . $reservation->teacher_id,
                'reservations:student:' . $reservation->student_id,
                'reservation_statistics_' . $reservation->teacher_id,
                'reservation_statistics_' . $reservation->student_id,
            ];

            foreach ($keysToDelete as $key) {
                Cache::forget($key);
            }

            // Clear wildcard patterns (if Redis)
            $patterns = [
                'reservations:teacher:' . $reservation->teacher_id . ':*',
                'reservations:student:' . $reservation->student_id . ':*',
            ];

            foreach ($patterns as $pattern) {
                try {
                    Cache::forget($pattern);
                } catch (\Exception $e) {
                    // Silent fail for drivers that don't support patterns
                }
            }

            Log::debug('Reservation cache cleared successfully', [
                'reservation_id' => $reservation->id,
            ]);

        } catch (\Exception $e) {
            Log::error('Failed to clear reservation cache', [
                'reservation_id' => $reservation->id,
                'error' => $e->getMessage(),
            ]);
        }
    }
}

