<?php

namespace App\Http\Controllers;

use App\Models\Teacher;
use App\Models\TeacherException;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;

/**
 * TeacherExceptionController
 * 
 * Öğretmen özel günleri (tatil, izin, özel saatler) yönetimi
 */
class TeacherExceptionController extends Controller
{
    /**
     * Get teacher exceptions
     */
    public function index(Request $request): JsonResponse
    {
        $user = Auth::user();
        $teacher = Teacher::where('user_id', $user->id)->firstOrFail();

        $query = $teacher->exceptions()->active();

        // Filter by type
        if ($request->has('type')) {
            if ($request->type === 'unavailable') {
                $query->unavailable();
            } elseif ($request->type === 'custom_hours') {
                $query->customHours();
            }
        }

        // Filter by future/past
        if ($request->has('filter')) {
            if ($request->filter === 'future') {
                $query->future();
            } elseif ($request->filter === 'past') {
                $query->past();
            }
        }

        $exceptions = $query->orderBy('exception_date', 'asc')->get();

        return response()->json([
            'success' => true,
            'data' => $exceptions->map(function ($exception) {
                return [
                    'id' => $exception->id,
                    'date' => $exception->exception_date->format('Y-m-d'),
                    'formatted_date' => $exception->formatted_date,
                    'type' => $exception->type,
                    'start_time' => $exception->start_time?->format('H:i'),
                    'end_time' => $exception->end_time?->format('H:i'),
                    'reason' => $exception->reason,
                    'notes' => $exception->notes,
                    'display_text' => $exception->display_text,
                ];
            })
        ]);
    }

    /**
     * Add exception (izin/tatil günü veya özel saatler)
     */
    public function store(Request $request): JsonResponse
    {
        $user = Auth::user();
        $teacher = Teacher::where('user_id', $user->id)->firstOrFail();

        $validated = $request->validate([
            'exception_date' => 'required|date|after_or_equal:today',
            'type' => 'required|in:unavailable,custom_hours',
            'start_time' => 'required_if:type,custom_hours|date_format:H:i',
            'end_time' => 'required_if:type,custom_hours|date_format:H:i|after:start_time',
            'reason' => 'nullable|string|max:255',
            'notes' => 'nullable|string|max:1000',
        ]);

        // Check if exception already exists for this date
        $existing = $teacher->exceptions()
            ->where('exception_date', $validated['exception_date'])
            ->where('is_active', true)
            ->first();

        if ($existing) {
            return response()->json([
                'success' => false,
                'message' => 'Bu tarih için zaten bir istisna kaydı bulunmaktadır.'
            ], 422);
        }

        $exception = $teacher->exceptions()->create($validated);

        Log::info('Teacher exception created', [
            'teacher_id' => $teacher->user_id,
            'exception_date' => $validated['exception_date'],
            'type' => $validated['type'],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'İstisna kaydı başarıyla oluşturuldu.',
            'data' => [
                'id' => $exception->id,
                'date' => $exception->exception_date->format('Y-m-d'),
                'formatted_date' => $exception->formatted_date,
                'type' => $exception->type,
                'start_time' => $exception->start_time?->format('H:i'),
                'end_time' => $exception->end_time?->format('H:i'),
                'reason' => $exception->reason,
                'display_text' => $exception->display_text,
            ]
        ], 201);
    }

    /**
     * Update exception
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $user = Auth::user();
        $teacher = Teacher::where('user_id', $user->id)->firstOrFail();
        
        $exception = $teacher->exceptions()->findOrFail($id);

        $validated = $request->validate([
            'exception_date' => 'sometimes|date|after_or_equal:today',
            'type' => 'sometimes|in:unavailable,custom_hours',
            'start_time' => 'required_if:type,custom_hours|date_format:H:i',
            'end_time' => 'required_if:type,custom_hours|date_format:H:i|after:start_time',
            'reason' => 'nullable|string|max:255',
            'notes' => 'nullable|string|max:1000',
            'is_active' => 'sometimes|boolean',
        ]);

        $exception->update($validated);

        return response()->json([
            'success' => true,
            'message' => 'İstisna kaydı güncellendi.',
            'data' => [
                'id' => $exception->id,
                'date' => $exception->exception_date->format('Y-m-d'),
                'type' => $exception->type,
                'start_time' => $exception->start_time?->format('H:i'),
                'end_time' => $exception->end_time?->format('H:i'),
                'reason' => $exception->reason,
            ]
        ]);
    }

    /**
     * Delete exception
     */
    public function destroy(int $id): JsonResponse
    {
        $user = Auth::user();
        $teacher = Teacher::where('user_id', $user->id)->firstOrFail();
        
        $exception = $teacher->exceptions()->findOrFail($id);
        $exception->delete();

        return response()->json([
            'success' => true,
            'message' => 'İstisna kaydı silindi.'
        ]);
    }

    /**
     * Add bulk unavailable days (tatil dönemi vb.)
     */
    public function addBulkUnavailable(Request $request): JsonResponse
    {
        $user = Auth::user();
        $teacher = Teacher::where('user_id', $user->id)->firstOrFail();

        $validated = $request->validate([
            'start_date' => 'required|date|after_or_equal:today',
            'end_date' => 'required|date|after_or_equal:start_date',
            'reason' => 'required|string|max:255',
            'notes' => 'nullable|string|max:1000',
        ]);

        $startDate = \Carbon\Carbon::parse($validated['start_date']);
        $endDate = \Carbon\Carbon::parse($validated['end_date']);
        
        $addedCount = 0;
        $currentDate = $startDate->copy();

        while ($currentDate->lte($endDate)) {
            // Check if exception already exists
            $existing = $teacher->exceptions()
                ->where('exception_date', $currentDate->format('Y-m-d'))
                ->where('is_active', true)
                ->exists();

            if (!$existing) {
                $teacher->exceptions()->create([
                    'exception_date' => $currentDate->format('Y-m-d'),
                    'type' => 'unavailable',
                    'reason' => $validated['reason'],
                    'notes' => $validated['notes'],
                ]);
                $addedCount++;
            }

            $currentDate->addDay();
        }

        Log::info('Bulk unavailable days added', [
            'teacher_id' => $teacher->user_id,
            'start_date' => $validated['start_date'],
            'end_date' => $validated['end_date'],
            'count' => $addedCount,
        ]);

        return response()->json([
            'success' => true,
            'message' => "$addedCount gün için izin kaydı oluşturuldu.",
            'data' => [
                'added_count' => $addedCount,
            ]
        ]);
    }
}

