<?php

namespace App\Http\Controllers;

use App\Models\TeacherAvailability;
use App\Models\Teacher;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Gate;

class AvailabilityController extends Controller
{
    /**
     * Get teacher availabilities
     */
    public function index(Request $request, int $teacherId): JsonResponse
    {
        $teacher = Teacher::findOrFail($teacherId);
        
        $availabilities = $teacher->availabilities()
            ->where('is_available', true)
            ->orderBy('day_of_week')
            ->orderBy('start_time')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $availabilities->map(function ($availability) {
                return [
                    'id' => $availability->id,
                    'day_of_week' => $availability->day_of_week,
                    'day_name' => $availability->day_name,
                    'start_time' => $availability->start_time->format('H:i'),
                    'end_time' => $availability->end_time->format('H:i'),
                    'formatted_time_range' => $availability->formatted_time_range,
                ];
            })
        ]);
    }

    /**
     * Store teacher availability
     */
    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'day_of_week' => 'required|in:monday,tuesday,wednesday,thursday,friday,saturday,sunday',
            'start_time' => 'required|date_format:H:i',
            'end_time' => 'required|date_format:H:i|after:start_time',
        ]);

        $user = Auth::user();
        $teacher = Teacher::where('user_id', $user->id)->firstOrFail();

        // Check for overlapping times
        $overlapping = $teacher->availabilities()
            ->where('day_of_week', $request->day_of_week)
            ->where('is_available', true)
            ->where(function ($query) use ($request) {
                $query->whereBetween('start_time', [$request->start_time, $request->end_time])
                      ->orWhereBetween('end_time', [$request->start_time, $request->end_time])
                      ->orWhere(function ($q) use ($request) {
                          $q->where('start_time', '<=', $request->start_time)
                            ->where('end_time', '>=', $request->end_time);
                      });
            })
            ->exists();

        if ($overlapping) {
            return response()->json([
                'success' => false,
                'message' => 'Bu saat aralığında zaten bir uygunluk kaydı bulunmaktadır.'
            ], 422);
        }

        $availability = $teacher->availabilities()->create([
            'day_of_week' => $request->day_of_week,
            'start_time' => $request->start_time,
            'end_time' => $request->end_time,
            'is_available' => true,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Uygunluk kaydı başarıyla eklendi.',
            'data' => [
                'id' => $availability->id,
                'day_of_week' => $availability->day_of_week,
                'day_name' => $availability->day_name,
                'start_time' => $availability->start_time->format('H:i'),
                'end_time' => $availability->end_time->format('H:i'),
                'formatted_time_range' => $availability->formatted_time_range,
            ]
        ], 201);
    }

    /**
     * Update teacher availability
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $request->validate([
            'day_of_week' => 'sometimes|in:monday,tuesday,wednesday,thursday,friday,saturday,sunday',
            'start_time' => 'sometimes|date_format:H:i',
            'end_time' => 'sometimes|date_format:H:i|after:start_time',
            'is_available' => 'sometimes|boolean',
        ]);

        $user = Auth::user();
        $teacher = Teacher::where('user_id', $user->id)->firstOrFail();
        
        $availability = $teacher->availabilities()->findOrFail($id);

        // Check for overlapping times if updating time
        if ($request->has(['start_time', 'end_time', 'day_of_week'])) {
            $overlapping = $teacher->availabilities()
                ->where('day_of_week', $request->day_of_week ?? $availability->day_of_week)
                ->where('is_available', true)
                ->where('id', '!=', $id)
                ->where(function ($query) use ($request, $availability) {
                    $startTime = $request->start_time ?? $availability->start_time->format('H:i');
                    $endTime = $request->end_time ?? $availability->end_time->format('H:i');
                    
                    $query->whereBetween('start_time', [$startTime, $endTime])
                          ->orWhereBetween('end_time', [$startTime, $endTime])
                          ->orWhere(function ($q) use ($startTime, $endTime) {
                              $q->where('start_time', '<=', $startTime)
                                ->where('end_time', '>=', $endTime);
                          });
                })
                ->exists();

            if ($overlapping) {
                return response()->json([
                    'success' => false,
                    'message' => 'Bu saat aralığında zaten bir uygunluk kaydı bulunmaktadır.'
                ], 422);
            }
        }

        $availability->update($request->only(['day_of_week', 'start_time', 'end_time', 'is_available']));

        return response()->json([
            'success' => true,
            'message' => 'Uygunluk kaydı başarıyla güncellendi.',
            'data' => [
                'id' => $availability->id,
                'day_of_week' => $availability->day_of_week,
                'day_name' => $availability->day_name,
                'start_time' => $availability->start_time->format('H:i'),
                'end_time' => $availability->end_time->format('H:i'),
                'formatted_time_range' => $availability->formatted_time_range,
                'is_available' => $availability->is_available,
            ]
        ]);
    }

    /**
     * Delete teacher availability
     */
    public function destroy(int $id): JsonResponse
    {
        $user = Auth::user();
        $teacher = Teacher::where('user_id', $user->id)->firstOrFail();
        
        $availability = $teacher->availabilities()->findOrFail($id);
        $availability->delete();

        return response()->json([
            'success' => true,
            'message' => 'Uygunluk kaydı başarıyla silindi.'
        ]);
    }

    /**
     * Get available time slots for a specific date
     */
    public function getAvailableSlots(Request $request, int $teacherId): JsonResponse
    {
        $request->validate([
            'date' => 'required|date|after_or_equal:today',
        ]);

        $teacher = Teacher::findOrFail($teacherId);
        $date = $request->date;
        $dayOfWeek = strtolower(date('l', strtotime($date)));

        // Get teacher's availability for this day
        $availabilities = $teacher->availabilities()
            ->where('day_of_week', $dayOfWeek)
            ->where('is_available', true)
            ->orderBy('start_time')
            ->get();

        if ($availabilities->isEmpty()) {
            return response()->json([
                'success' => true,
                'data' => [],
                'message' => 'Bu tarihte uygun saat bulunmamaktadır.'
            ]);
        }

        // Get existing reservations for this date
        $existingReservations = $teacher->reservations()
            ->whereDate('proposed_datetime', $date)
            ->whereIn('status', ['accepted', 'pending'])
            ->get();

        $availableSlots = [];

        foreach ($availabilities as $availability) {
            $startTime = $availability->start_time;
            $endTime = $availability->end_time;
            
            // Generate 1-hour slots
            $currentTime = $startTime->copy();
            while ($currentTime->addHour()->lte($endTime)) {
                $slotStart = $currentTime->copy()->subHour();
                $slotEnd = $currentTime->copy();
                
                // Check if this slot conflicts with existing reservations
                $hasConflict = $existingReservations->contains(function ($reservation) use ($slotStart, $slotEnd) {
                    $reservationStart = \Carbon\Carbon::parse($reservation->proposed_datetime);
                    $reservationEnd = $reservationStart->copy()->addMinutes($reservation->duration_minutes);
                    
                    return $slotStart->lt($reservationEnd) && $slotEnd->gt($reservationStart);
                });

                if (!$hasConflict) {
                    $availableSlots[] = [
                        'start_time' => $slotStart->format('H:i'),
                        'end_time' => $slotEnd->format('H:i'),
                        'formatted_time' => $slotStart->format('H:i') . ' - ' . $slotEnd->format('H:i'),
                    ];
                }
            }
        }

        return response()->json([
            'success' => true,
            'data' => $availableSlots
        ]);
    }
}