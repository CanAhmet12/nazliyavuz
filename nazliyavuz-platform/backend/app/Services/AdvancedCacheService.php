<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\DB;
use App\Models\User;
use App\Models\Reservation;
use App\Models\Teacher;
use App\Models\Message;
use App\Models\Chat;

/**
 * Advanced Cache Service with Intelligent Invalidation
 * Implements multi-level caching with smart cache warming and invalidation
 */
class AdvancedCacheService
{
    // Cache duration constants
    const SHORT_TERM = 300; // 5 minutes
    const MEDIUM_TERM = 1800; // 30 minutes
    const LONG_TERM = 3600; // 1 hour
    const VERY_LONG_TERM = 86400; // 24 hours

    // Cache key prefixes
    const USER_PREFIX = 'user:';
    const TEACHER_PREFIX = 'teacher:';
    const RESERVATION_PREFIX = 'reservation:';
    const MESSAGE_PREFIX = 'message:';
    const CHAT_PREFIX = 'chat:';
    const STATISTICS_PREFIX = 'stats:';
    const DASHBOARD_PREFIX = 'dashboard:';

    /**
     * Cache user data with relationships
     */
    public function cacheUser(int $userId, int $duration = self::MEDIUM_TERM): array
    {
        $key = self::USER_PREFIX . $userId;
        
        return Cache::remember($key, $duration, function () use ($userId, $duration) {
            $user = User::with(['teacher', 'student'])
                ->select('id', 'name', 'email', 'role', 'profile_photo_url', 'is_active', 'email_verified_at')
                ->find($userId);
                
            if (!$user) {
                return null;
            }

            $userData = $user->toArray();
            
            // Add role-specific data
            if ($user->role === 'teacher' && $user->teacher) {
                $userData['teacher_data'] = [
                    'rating' => $user->teacher->rating,
                    'rating_count' => $user->teacher->rating_count,
                    'price_per_hour' => $user->teacher->price_per_hour,
                    'online_available' => $user->teacher->online_available,
                    'is_approved' => $user->teacher->is_approved,
                    'specialties' => $user->teacher->specialties,
                    'experience_years' => $user->teacher->experience_years,
                ];
            }

            Log::debug('User cached', ['user_id' => $userId, 'duration' => $duration]);
            return $userData;
        });
    }

    /**
     * Cache teacher data with statistics
     */
    public function cacheTeacher(int $teacherId, int $duration = self::MEDIUM_TERM): array
    {
        $key = self::TEACHER_PREFIX . $teacherId;
        
        return Cache::remember($key, $duration, function () use ($teacherId, $duration) {
            $teacher = Teacher::with(['user', 'categories'])
                ->find($teacherId);
                
            if (!$teacher) {
                return null;
            }

            $teacherData = $teacher->toArray();
            
            // Add statistics
            $teacherData['statistics'] = [
                'total_students' => $this->getTeacherStudentCount($teacherId),
                'total_lessons' => $this->getTeacherLessonCount($teacherId),
                'total_earnings' => $this->getTeacherEarnings($teacherId),
                'upcoming_lessons' => $this->getTeacherUpcomingLessons($teacherId),
            ];

            Log::debug('Teacher cached', ['teacher_id' => $teacherId, 'duration' => $duration]);
            return $teacherData;
        });
    }

    /**
     * Cache reservations with smart filtering
     */
    public function cacheReservations(string $type, int $userId, array $filters = [], int $duration = self::SHORT_TERM): array
    {
        $filterKey = md5(serialize($filters));
        $key = self::RESERVATION_PREFIX . "{$type}:{$userId}:{$filterKey}";
        
        return Cache::remember($key, $duration, function () use ($type, $userId, $filters) {
            $query = Reservation::with([
                'teacher.user:id,name,email,profile_photo_url',
                'student:id,name,email,profile_photo_url',
                'category:id,name,slug'
            ]);

            // Apply role-based filtering
            if ($type === 'teacher') {
                $query->where('teacher_id', $userId);
            } else {
                $query->where('student_id', $userId);
            }

            // Apply filters
            if (isset($filters['status'])) {
                $query->where('status', $filters['status']);
            }
            if (isset($filters['from_date'])) {
                $query->whereDate('proposed_datetime', '>=', $filters['from_date']);
            }
            if (isset($filters['to_date'])) {
                $query->whereDate('proposed_datetime', '<=', $filters['to_date']);
            }

            $reservations = $query->orderBy('proposed_datetime', 'desc')->get();

            Log::debug('Reservations cached', ['type' => $type, 'user_id' => $userId, 'count' => $reservations->count()]);
            return $reservations->toArray();
        });
    }

    /**
     * Cache messages for chat
     */
    public function cacheMessages(int $chatId, int $duration = self::SHORT_TERM): array
    {
        $key = self::MESSAGE_PREFIX . $chatId;
        
        return Cache::remember($key, $duration, function () use ($chatId) {
            $messages = Message::with(['sender:id,name,profile_photo_url', 'receiver:id,name,profile_photo_url'])
                ->where('chat_id', $chatId)
                ->orderBy('created_at', 'desc')
                ->limit(100) // Limit to last 100 messages
                ->get();

            Log::debug('Messages cached', ['chat_id' => $chatId, 'count' => $messages->count()]);
            return $messages->toArray();
        });
    }

    /**
     * Cache dashboard statistics
     */
    public function cacheDashboardStats(string $type, int $userId, int $duration = self::MEDIUM_TERM): array
    {
        $key = self::DASHBOARD_PREFIX . "{$type}:{$userId}";
        
        return Cache::remember($key, $duration, function () use ($type, $userId) {
            if ($type === 'teacher') {
                $stats = [
                    'total_students' => $this->getTeacherStudentCount($userId),
                    'total_lessons' => $this->getTeacherLessonCount($userId),
                    'total_earnings' => $this->getTeacherEarnings($userId),
                    'upcoming_lessons' => $this->getTeacherUpcomingLessons($userId),
                    'pending_reservations' => $this->getTeacherPendingReservations($userId),
                    'completed_lessons' => $this->getTeacherCompletedLessons($userId),
                ];
            } else {
                $stats = [
                    'total_teachers' => $this->getStudentTeacherCount($userId),
                    'total_lessons' => $this->getStudentLessonCount($userId),
                    'upcoming_lessons' => $this->getStudentUpcomingLessons($userId),
                    'completed_lessons' => $this->getStudentCompletedLessons($userId),
                    'pending_reservations' => $this->getStudentPendingReservations($userId),
                    'learning_progress' => $this->getStudentLearningProgress($userId),
                ];
            }

            Log::debug('Dashboard stats cached', ['type' => $type, 'user_id' => $userId]);
            return $stats;
        });
    }

    /**
     * Cache search results
     */
    public function cacheSearchResults(string $query, array $filters = [], int $duration = self::SHORT_TERM): array
    {
        $filterKey = md5(serialize($filters));
        $searchKey = md5($query . $filterKey);
        $key = 'search:' . $searchKey;
        
        return Cache::remember($key, $duration, function () use ($query, $filters) {
            $teachers = Teacher::with(['user', 'categories'])
                ->whereHas('user', function ($q) use ($query) {
                    $q->where('name', 'like', "%{$query}%")
                      ->orWhere('email', 'like', "%{$query}%");
                })
                ->where('is_approved', true)
                ->when(isset($filters['category']), function ($q) use ($filters) {
                    $q->whereHas('categories', function ($cat) use ($filters) {
                        $cat->where('id', $filters['category']);
                    });
                })
                ->when(isset($filters['min_price']), function ($q) use ($filters) {
                    $q->where('price_per_hour', '>=', $filters['min_price']);
                })
                ->when(isset($filters['max_price']), function ($q) use ($filters) {
                    $q->where('price_per_hour', '<=', $filters['max_price']);
                })
                ->orderBy('rating', 'desc')
                ->limit(20)
                ->get();

            Log::debug('Search results cached', ['query' => $query, 'count' => $teachers->count()]);
            return $teachers->toArray();
        });
    }

    /**
     * Invalidate cache by pattern
     */
    public function invalidateByPattern(string $pattern): void
    {
        try {
            $keys = Redis::keys($pattern);
            if (!empty($keys)) {
                Redis::del($keys);
                Log::info('Cache invalidated by pattern', ['pattern' => $pattern, 'keys_count' => count($keys)]);
            }
        } catch (\Exception $e) {
            Log::error('Cache invalidation failed', ['pattern' => $pattern, 'error' => $e->getMessage()]);
        }
    }

    /**
     * Invalidate user-related cache
     */
    public function invalidateUserCache(int $userId): void
    {
        $patterns = [
            self::USER_PREFIX . $userId,
            self::TEACHER_PREFIX . $userId,
            self::RESERVATION_PREFIX . "*:{$userId}:*",
            self::DASHBOARD_PREFIX . "*:{$userId}",
            self::MESSAGE_PREFIX . "*",
            self::CHAT_PREFIX . "*",
        ];

        foreach ($patterns as $pattern) {
            $this->invalidateByPattern($pattern);
        }

        Log::info('User cache invalidated', ['user_id' => $userId]);
    }

    /**
     * Warm up cache for frequently accessed data
     */
    public function warmUpCache(): void
    {
        // Warm up popular teachers
        $popularTeachers = Teacher::with(['user', 'categories'])
            ->where('is_approved', true)
            ->where('online_available', true)
            ->orderBy('rating', 'desc')
            ->limit(50)
            ->get();

        foreach ($popularTeachers as $teacher) {
            $this->cacheTeacher($teacher->id, self::LONG_TERM);
        }

        // Warm up categories
        $categories = DB::table('categories')->get();
        Cache::put('categories:all', $categories, self::VERY_LONG_TERM);

        Log::info('Cache warmed up', ['teachers_count' => $popularTeachers->count(), 'categories_count' => $categories->count()]);
    }

    // Helper methods for statistics
    private function getTeacherStudentCount(int $teacherId): int
    {
        return DB::table('reservations')
            ->where('teacher_id', $teacherId)
            ->where('status', 'accepted')
            ->distinct('student_id')
            ->count();
    }

    private function getTeacherLessonCount(int $teacherId): int
    {
        return DB::table('lessons')
            ->where('teacher_id', $teacherId)
            ->count();
    }

    private function getTeacherEarnings(int $teacherId): float
    {
        return DB::table('payments')
            ->where('teacher_id', $teacherId)
            ->where('status', 'completed')
            ->sum('amount');
    }

    private function getTeacherUpcomingLessons(int $teacherId): int
    {
        return DB::table('lessons')
            ->where('teacher_id', $teacherId)
            ->where('start_datetime', '>', now())
            ->count();
    }

    private function getTeacherPendingReservations(int $teacherId): int
    {
        return DB::table('reservations')
            ->where('teacher_id', $teacherId)
            ->where('status', 'pending')
            ->count();
    }

    private function getTeacherCompletedLessons(int $teacherId): int
    {
        return DB::table('lessons')
            ->where('teacher_id', $teacherId)
            ->where('end_datetime', '<', now())
            ->count();
    }

    private function getStudentTeacherCount(int $studentId): int
    {
        return DB::table('reservations')
            ->where('student_id', $studentId)
            ->where('status', 'accepted')
            ->distinct('teacher_id')
            ->count();
    }

    private function getStudentLessonCount(int $studentId): int
    {
        return DB::table('lessons')
            ->where('student_id', $studentId)
            ->count();
    }

    private function getStudentUpcomingLessons(int $studentId): int
    {
        return DB::table('lessons')
            ->where('student_id', $studentId)
            ->where('start_datetime', '>', now())
            ->count();
    }

    private function getStudentCompletedLessons(int $studentId): int
    {
        return DB::table('lessons')
            ->where('student_id', $studentId)
            ->where('end_datetime', '<', now())
            ->count();
    }

    private function getStudentPendingReservations(int $studentId): int
    {
        return DB::table('reservations')
            ->where('student_id', $studentId)
            ->where('status', 'pending')
            ->count();
    }

    private function getStudentLearningProgress(int $studentId): array
    {
        return [
            'completed_assignments' => DB::table('assignments')
                ->where('student_id', $studentId)
                ->where('status', 'graded')
                ->count(),
            'total_assignments' => DB::table('assignments')
                ->where('student_id', $studentId)
                ->count(),
            'average_grade' => DB::table('assignments')
                ->where('student_id', $studentId)
                ->where('status', 'graded')
                ->avg('grade'),
        ];
    }
}
