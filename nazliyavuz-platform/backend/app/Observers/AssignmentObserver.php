<?php

namespace App\Observers;

use App\Models\Assignment;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

class AssignmentObserver
{
    /**
     * Handle the Assignment "created" event.
     */
    public function created(Assignment $assignment): void
    {
        $this->clearAssignmentCache($assignment);
        
        Log::info('Assignment created - cache cleared', [
            'assignment_id' => $assignment->id,
            'teacher_id' => $assignment->teacher_id,
            'student_id' => $assignment->student_id,
        ]);
    }

    /**
     * Handle the Assignment "updated" event.
     */
    public function updated(Assignment $assignment): void
    {
        $this->clearAssignmentCache($assignment);
        
        Log::debug('Assignment updated - cache cleared', [
            'assignment_id' => $assignment->id,
            'changed_fields' => array_keys($assignment->getDirty()),
        ]);
    }

    /**
     * Handle the Assignment "deleted" event.
     */
    public function deleted(Assignment $assignment): void
    {
        $this->clearAssignmentCache($assignment);
        
        Log::info('Assignment deleted - cache cleared', [
            'assignment_id' => $assignment->id,
        ]);
    }

    /**
     * Clear all related assignment caches
     */
    private function clearAssignmentCache(Assignment $assignment): void
    {
        try {
            // Method 1: Clear with tags (if Redis/Memcached)
            if (config('cache.default') !== 'file') {
                Cache::tags([
                    'assignments',
                    'user_' . $assignment->teacher_id,
                    'user_' . $assignment->student_id,
                ])->flush();
            }

            // Method 2: Clear specific keys (works with all cache drivers)
            $patterns = [
                'assignments_' . $assignment->teacher_id . '_*',
                'assignments_' . $assignment->student_id . '_*',
                'assignments_list_*',
                'assignment_statistics_*',
            ];

            // For file cache or when tags not available
            foreach ($patterns as $pattern) {
                // Try to delete by pattern (may not work with all drivers)
                try {
                    Cache::forget($pattern);
                } catch (\Exception $e) {
                    // Silent fail - not all cache drivers support wildcard deletion
                }
            }

            // Clear specific known cache keys
            $specificKeys = [
                'assignments_' . $assignment->teacher_id,
                'assignments_' . $assignment->student_id,
                'teacher_assignments_' . $assignment->teacher_id,
                'student_assignments_' . $assignment->student_id,
                'assignment_statistics_' . $assignment->student_id,
            ];

            foreach ($specificKeys as $key) {
                Cache::forget($key);
            }

            Log::debug('Assignment cache cleared successfully', [
                'assignment_id' => $assignment->id,
            ]);

        } catch (\Exception $e) {
            Log::error('Failed to clear assignment cache', [
                'assignment_id' => $assignment->id,
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * Handle the Assignment "restored" event.
     */
    public function restored(Assignment $assignment): void
    {
        $this->clearAssignmentCache($assignment);
    }

    /**
     * Handle the Assignment "force deleted" event.
     */
    public function forceDeleted(Assignment $assignment): void
    {
        $this->clearAssignmentCache($assignment);
    }
}

