<?php

namespace App\Services;

use App\Models\Reservation;
use Carbon\Carbon;
use Illuminate\Support\Facades\Log;

class ReservationConflictService
{
    /**
     * Check if a reservation time conflicts with existing reservations
     *
     * @param int $teacherId
     * @param Carbon $proposedStart
     * @param int $durationMinutes
     * @param int|null $excludeReservationId
     * @return bool
     */
    public function hasConflict(
        int $teacherId,
        Carbon $proposedStart,
        int $durationMinutes,
        ?int $excludeReservationId = null
    ): bool {
        $proposedEnd = $proposedStart->copy()->addMinutes($durationMinutes);

        // Get all reservations for this teacher
        $existingReservations = Reservation::where('teacher_id', $teacherId)
            ->whereIn('status', ['accepted', 'pending'])
            ->when($excludeReservationId, function ($query, $id) {
                $query->where('id', '!=', $id);
            })
            ->get();

        $conflictingCount = 0;
        
        foreach ($existingReservations as $reservation) {
            $existingStart = Carbon::parse($reservation->proposed_datetime);
            $existingEnd = $existingStart->copy()->addMinutes($reservation->duration_minutes);
            
            // Check for overlap
            if (($proposedStart->lt($existingEnd) && $proposedEnd->gt($existingStart))) {
                $conflictingCount++;
            }
        }

        $hasConflict = $conflictingCount > 0;

        if ($hasConflict) {
            Log::warning('Reservation conflict detected', [
                'teacher_id' => $teacherId,
                'proposed_start' => $proposedStart->toDateTimeString(),
                'proposed_end' => $proposedEnd->toDateTimeString(),
                'conflicting_count' => $conflictingCount,
            ]);
        }

        return $hasConflict;
    }

    /**
     * Get conflicting reservations
     *
     * @param int $teacherId
     * @param Carbon $proposedStart
     * @param int $durationMinutes
     * @param int|null $excludeReservationId
     * @return \Illuminate\Support\Collection
     */
    public function getConflictingReservations(
        int $teacherId,
        Carbon $proposedStart,
        int $durationMinutes,
        ?int $excludeReservationId = null
    ) {
        $proposedEnd = $proposedStart->copy()->addMinutes($durationMinutes);

        // Get all reservations for this teacher
        $allReservations = Reservation::where('teacher_id', $teacherId)
            ->whereIn('status', ['accepted', 'pending'])
            ->when($excludeReservationId, function ($query, $id) {
                $query->where('id', '!=', $id);
            })
            ->with(['student', 'category'])
            ->get();

        $conflictingReservations = collect();
        
        foreach ($allReservations as $reservation) {
            $existingStart = Carbon::parse($reservation->proposed_datetime);
            $existingEnd = $existingStart->copy()->addMinutes($reservation->duration_minutes);
            
            // Check for overlap
            if (($proposedStart->lt($existingEnd) && $proposedEnd->gt($existingStart))) {
                $conflictingReservations->push($reservation);
            }
        }

        return $conflictingReservations;
    }

    /**
     * Check student's reservation limit (prevent spam)
     *
     * @param int $studentId
     * @param int $maxPendingPerDay
     * @return bool
     */
    public function exceedsDailyLimit(int $studentId, int $maxPendingPerDay = 5): bool
    {
        $todayPendingCount = Reservation::where('student_id', $studentId)
            ->where('status', 'pending')
            ->whereDate('created_at', today())
            ->count();

        return $todayPendingCount >= $maxPendingPerDay;
    }

    /**
     * Check if reservation is too close (minimum notice period)
     *
     * @param Carbon $proposedStart
     * @param int $minimumHoursNotice
     * @return bool
     */
    public function isTooClose(Carbon $proposedStart, int $minimumHoursNotice = 2): bool
    {
        $minimumStart = now()->addHours($minimumHoursNotice);
        return $proposedStart->lt($minimumStart);
    }
}

