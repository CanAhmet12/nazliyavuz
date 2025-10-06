<?php

namespace Tests\Unit;

use Tests\TestCase;
use App\Models\User;
use App\Models\Teacher;
use App\Models\Reservation;
use App\Services\AdvancedCacheService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

class AdvancedCacheServiceTest extends TestCase
{
    use RefreshDatabase;

    protected AdvancedCacheService $cacheService;

    protected function setUp(): void
    {
        parent::setUp();
        $this->cacheService = new AdvancedCacheService();
    }

    /** @test */
    public function it_can_cache_user_data()
    {
        // Arrange
        $user = User::factory()->create([
            'name' => 'Test User',
            'email' => 'test@example.com',
            'role' => 'teacher',
        ]);

        // Act
        $result = $this->cacheService->cacheUser($user->id);

        // Assert
        $this->assertIsArray($result);
        $this->assertEquals($user->name, $result['name']);
        $this->assertEquals($user->email, $result['email']);
        $this->assertEquals($user->role, $result['role']);

        // Check if data is cached
        $cachedData = Cache::get('user:' . $user->id);
        $this->assertNotNull($cachedData);
        $this->assertEquals($user->name, $cachedData['name']);
    }

    /** @test */
    public function it_can_cache_teacher_data_with_statistics()
    {
        // Arrange
        $user = User::factory()->create(['role' => 'teacher']);
        $teacher = Teacher::factory()->create([
            'user_id' => $user->id,
            'rating' => 4.5,
            'rating_count' => 10,
        ]);

        // Act
        $result = $this->cacheService->cacheTeacher($teacher->id);

        // Assert
        $this->assertIsArray($result);
        $this->assertEquals($teacher->rating, $result['rating']);
        $this->assertEquals($teacher->rating_count, $result['rating_count']);
        $this->assertArrayHasKey('statistics', $result);

        // Check if data is cached
        $cachedData = Cache::get('teacher:' . $teacher->id);
        $this->assertNotNull($cachedData);
    }

    /** @test */
    public function it_can_cache_reservations_with_filters()
    {
        // Arrange
        $user = User::factory()->create(['role' => 'teacher']);
        $teacher = Teacher::factory()->create(['user_id' => $user->id]);
        
        Reservation::factory()->count(3)->create([
            'teacher_id' => $user->id,
            'status' => 'accepted',
        ]);

        $filters = ['status' => 'accepted'];

        // Act
        $result = $this->cacheService->cacheReservations('teacher', $user->id, $filters);

        // Assert
        $this->assertIsArray($result);
        $this->assertCount(3, $result);

        // Check if data is cached
        $cacheKey = 'reservation:teacher:' . $user->id . ':' . md5(serialize($filters));
        $cachedData = Cache::get($cacheKey);
        $this->assertNotNull($cachedData);
    }

    /** @test */
    public function it_can_invalidate_cache_by_pattern()
    {
        // Arrange
        Cache::put('user:1', ['name' => 'User 1'], 3600);
        Cache::put('user:2', ['name' => 'User 2'], 3600);
        Cache::put('teacher:1', ['name' => 'Teacher 1'], 3600);

        // Act
        $this->cacheService->invalidateByPattern('user:*');

        // Assert
        $this->assertNull(Cache::get('user:1'));
        $this->assertNull(Cache::get('user:2'));
        $this->assertNotNull(Cache::get('teacher:1'));
    }

    /** @test */
    public function it_can_invalidate_user_cache()
    {
        // Arrange
        $userId = 1;
        
        Cache::put('user:1', ['name' => 'User 1'], 3600);
        Cache::put('teacher:1', ['name' => 'Teacher 1'], 3600);
        Cache::put('reservation:teacher:1:abc', ['data' => 'test'], 3600);

        // Act
        $this->cacheService->invalidateUserCache($userId);

        // Assert
        $this->assertNull(Cache::get('user:1'));
        $this->assertNull(Cache::get('teacher:1'));
        $this->assertNull(Cache::get('reservation:teacher:1:abc'));
    }

    /** @test */
    public function it_can_cache_dashboard_statistics()
    {
        // Arrange
        $user = User::factory()->create(['role' => 'teacher']);
        $teacher = Teacher::factory()->create(['user_id' => $user->id]);

        // Act
        $result = $this->cacheService->cacheDashboardStats('teacher', $user->id);

        // Assert
        $this->assertIsArray($result);
        $this->assertArrayHasKey('total_students', $result);
        $this->assertArrayHasKey('total_lessons', $result);
        $this->assertArrayHasKey('total_earnings', $result);
        $this->assertArrayHasKey('upcoming_lessons', $result);

        // Check if data is cached
        $cacheKey = 'dashboard:teacher:' . $user->id;
        $cachedData = Cache::get($cacheKey);
        $this->assertNotNull($cachedData);
    }

    /** @test */
    public function it_can_cache_search_results()
    {
        // Arrange
        $user = User::factory()->create(['role' => 'teacher']);
        $teacher = Teacher::factory()->create([
            'user_id' => $user->id,
            'is_approved' => true,
        ]);

        $query = 'Test Teacher';
        $filters = ['category' => 1];

        // Act
        $result = $this->cacheService->cacheSearchResults($query, $filters);

        // Assert
        $this->assertIsArray($result);

        // Check if data is cached
        $filterKey = md5(serialize($filters));
        $searchKey = md5($query . $filterKey);
        $cacheKey = 'search:' . $searchKey;
        $cachedData = Cache::get($cacheKey);
        $this->assertNotNull($cachedData);
    }

    /** @test */
    public function it_can_warm_up_cache()
    {
        // Arrange
        User::factory()->create(['role' => 'teacher']);
        Teacher::factory()->create([
            'is_approved' => true,
            'online_available' => true,
            'rating' => 5.0,
        ]);

        DB::table('categories')->insert([
            'name' => 'Test Category',
            'slug' => 'test-category',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Act
        $this->cacheService->warmUpCache();

        // Assert
        $categories = Cache::get('categories:all');
        $this->assertNotNull($categories);
        $this->assertCount(1, $categories);
    }

    /** @test */
    public function it_returns_cached_data_when_available()
    {
        // Arrange
        $user = User::factory()->create(['name' => 'Cached User']);
        
        // First call to cache the data
        $this->cacheService->cacheUser($user->id);
        
        // Modify the user to ensure we get cached data
        $user->update(['name' => 'Modified User']);

        // Act
        $result = $this->cacheService->cacheUser($user->id);

        // Assert
        $this->assertEquals('Cached User', $result['name']);
    }

    /** @test */
    public function it_handles_missing_user_gracefully()
    {
        // Act
        $result = $this->cacheService->cacheUser(99999);

        // Assert
        $this->assertNull($result);
    }

    /** @test */
    public function it_handles_missing_teacher_gracefully()
    {
        // Act
        $result = $this->cacheService->cacheTeacher(99999);

        // Assert
        $this->assertNull($result);
    }

    /** @test */
    public function it_can_get_teacher_student_count()
    {
        // Arrange
        $user = User::factory()->create(['role' => 'teacher']);
        $teacher = Teacher::factory()->create(['user_id' => $user->id]);
        
        $student1 = User::factory()->create(['role' => 'student']);
        $student2 = User::factory()->create(['role' => 'student']);
        
        Reservation::factory()->create([
            'teacher_id' => $user->id,
            'student_id' => $student1->id,
            'status' => 'accepted',
        ]);
        
        Reservation::factory()->create([
            'teacher_id' => $user->id,
            'student_id' => $student2->id,
            'status' => 'accepted',
        ]);

        // Act
        $result = $this->cacheService->cacheTeacher($teacher->id);

        // Assert
        $this->assertEquals(2, $result['statistics']['total_students']);
    }

    /** @test */
    public function it_can_get_student_learning_progress()
    {
        // Arrange
        $user = User::factory()->create(['role' => 'student']);
        
        DB::table('assignments')->insert([
            'teacher_id' => 1,
            'student_id' => $user->id,
            'title' => 'Test Assignment',
            'status' => 'graded',
            'grade' => 'A',
            'due_date' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Act
        $result = $this->cacheService->cacheDashboardStats('student', $user->id);

        // Assert
        $this->assertArrayHasKey('learning_progress', $result);
        $this->assertEquals(1, $result['learning_progress']['completed_assignments']);
        $this->assertEquals(1, $result['learning_progress']['total_assignments']);
    }
}
