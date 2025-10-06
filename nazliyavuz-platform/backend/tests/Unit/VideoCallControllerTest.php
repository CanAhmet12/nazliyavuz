<?php

namespace Tests\Unit;

use Tests\TestCase;
use App\Models\User;
use App\Models\VideoCall;
use App\Models\VideoCallParticipant;
use App\Services\NotificationService;
use App\Services\AdvancedCacheService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Mockery;

class VideoCallControllerTest extends TestCase
{
    use RefreshDatabase;

    protected $user;
    protected $receiver;
    protected $notificationService;
    protected $cacheService;

    protected function setUp(): void
    {
        parent::setUp();

        // Create test users
        $this->user = User::factory()->create(['role' => 'teacher']);
        $this->receiver = User::factory()->create(['role' => 'student']);

        // Mock services
        $this->notificationService = Mockery::mock(NotificationService::class);
        $this->cacheService = Mockery::mock(AdvancedCacheService::class);

        // Bind mocks to container
        $this->app->instance(NotificationService::class, $this->notificationService);
        $this->app->instance(AdvancedCacheService::class, $this->cacheService);
    }

    protected function tearDown(): void
    {
        Mockery::close();
        parent::tearDown();
    }

    /** @test */
    public function it_can_start_a_video_call()
    {
        // Arrange
        Auth::login($this->user);

        $this->notificationService
            ->shouldReceive('sendVideoCallNotification')
            ->once()
            ->with($this->receiver->id, $this->user->name, 'video', Mockery::any());

        $this->cacheService
            ->shouldReceive('invalidateUserCache')
            ->twice();

        // Act
        $response = $this->postJson('/api/v1/video-call/start', [
            'receiver_id' => $this->receiver->id,
            'call_type' => 'video',
            'subject' => 'Test Call',
        ]);

        // Assert
        $response->assertStatus(200)
                ->assertJsonStructure([
                    'success',
                    'call_id',
                    'call_type',
                    'video_call',
                    'message',
                ]);

        $this->assertDatabaseHas('video_calls', [
            'caller_id' => $this->user->id,
            'receiver_id' => $this->receiver->id,
            'call_type' => 'video',
            'status' => 'initiated',
        ]);

        $this->assertDatabaseHas('video_call_participants', [
            'user_id' => $this->user->id,
            'role' => 'caller',
        ]);

        $this->assertDatabaseHas('video_call_participants', [
            'user_id' => $this->receiver->id,
            'role' => 'receiver',
        ]);
    }

    /** @test */
    public function it_can_answer_a_video_call()
    {
        // Arrange
        $videoCall = VideoCall::factory()->create([
            'caller_id' => $this->user->id,
            'receiver_id' => $this->receiver->id,
            'status' => 'initiated',
        ]);

        VideoCallParticipant::factory()->create([
            'video_call_id' => $videoCall->id,
            'user_id' => $this->receiver->id,
            'role' => 'receiver',
        ]);

        Auth::login($this->receiver);

        $this->cacheService
            ->shouldReceive('invalidateUserCache')
            ->twice();

        // Act
        $response = $this->postJson('/api/v1/video-call/answer', [
            'call_id' => $videoCall->call_id,
            'call_type' => 'video',
        ]);

        // Assert
        $response->assertStatus(200)
                ->assertJson([
                    'success' => true,
                    'call_type' => 'video',
                ]);

        $this->assertDatabaseHas('video_calls', [
            'id' => $videoCall->id,
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('video_call_participants', [
            'video_call_id' => $videoCall->id,
            'user_id' => $this->receiver->id,
            'status' => 'active',
        ]);
    }

    /** @test */
    public function it_can_reject_a_video_call()
    {
        // Arrange
        $videoCall = VideoCall::factory()->create([
            'caller_id' => $this->user->id,
            'receiver_id' => $this->receiver->id,
            'status' => 'initiated',
        ]);

        Auth::login($this->receiver);

        $this->cacheService
            ->shouldReceive('invalidateUserCache')
            ->twice();

        // Act
        $response = $this->postJson('/api/v1/video-call/reject', [
            'call_id' => $videoCall->call_id,
            'reason' => 'Busy',
        ]);

        // Assert
        $response->assertStatus(200)
                ->assertJson([
                    'success' => true,
                ]);

        $this->assertDatabaseHas('video_calls', [
            'id' => $videoCall->id,
            'status' => 'rejected',
            'end_reason' => 'Busy',
        ]);
    }

    /** @test */
    public function it_can_end_a_video_call()
    {
        // Arrange
        $videoCall = VideoCall::factory()->create([
            'caller_id' => $this->user->id,
            'receiver_id' => $this->receiver->id,
            'status' => 'active',
            'started_at' => now()->subMinutes(5),
        ]);

        VideoCallParticipant::factory()->create([
            'video_call_id' => $videoCall->id,
            'user_id' => $this->user->id,
            'role' => 'caller',
            'status' => 'active',
        ]);

        Auth::login($this->user);

        $this->cacheService
            ->shouldReceive('invalidateUserCache')
            ->times(3);

        // Act
        $response = $this->postJson('/api/v1/video-call/end', [
            'call_id' => $videoCall->call_id,
            'reason' => 'Call completed',
        ]);

        // Assert
        $response->assertStatus(200)
                ->assertJsonStructure([
                    'success',
                    'duration',
                    'message',
                ]);

        $this->assertDatabaseHas('video_calls', [
            'id' => $videoCall->id,
            'status' => 'ended',
            'end_reason' => 'Call completed',
        ]);

        $this->assertDatabaseHas('video_call_participants', [
            'video_call_id' => $videoCall->id,
            'user_id' => $this->user->id,
            'status' => 'left',
        ]);
    }

    /** @test */
    public function it_can_toggle_mute()
    {
        // Arrange
        $videoCall = VideoCall::factory()->create([
            'caller_id' => $this->user->id,
            'receiver_id' => $this->receiver->id,
            'status' => 'active',
        ]);

        VideoCallParticipant::factory()->create([
            'video_call_id' => $videoCall->id,
            'user_id' => $this->user->id,
            'role' => 'caller',
            'is_muted' => false,
        ]);

        Auth::login($this->user);

        // Act
        $response = $this->postJson('/api/v1/video-call/toggle-mute', [
            'call_id' => $videoCall->call_id,
            'muted' => true,
        ]);

        // Assert
        $response->assertStatus(200)
                ->assertJson([
                    'success' => true,
                    'muted' => true,
                ]);

        $this->assertDatabaseHas('video_call_participants', [
            'video_call_id' => $videoCall->id,
            'user_id' => $this->user->id,
            'is_muted' => true,
        ]);
    }

    /** @test */
    public function it_can_toggle_video()
    {
        // Arrange
        $videoCall = VideoCall::factory()->create([
            'caller_id' => $this->user->id,
            'receiver_id' => $this->receiver->id,
            'call_type' => 'video',
            'status' => 'active',
        ]);

        VideoCallParticipant::factory()->create([
            'video_call_id' => $videoCall->id,
            'user_id' => $this->user->id,
            'role' => 'caller',
            'video_enabled' => true,
        ]);

        Auth::login($this->user);

        // Act
        $response = $this->postJson('/api/v1/video-call/toggle-video', [
            'call_id' => $videoCall->call_id,
            'video_enabled' => false,
        ]);

        // Assert
        $response->assertStatus(200)
                ->assertJson([
                    'success' => true,
                    'video_enabled' => false,
                ]);

        $this->assertDatabaseHas('video_call_participants', [
            'video_call_id' => $videoCall->id,
            'user_id' => $this->user->id,
            'video_enabled' => false,
        ]);
    }

    /** @test */
    public function it_can_get_call_history()
    {
        // Arrange
        VideoCall::factory()->count(3)->create([
            'caller_id' => $this->user->id,
            'receiver_id' => $this->receiver->id,
        ]);

        Auth::login($this->user);

        // Act
        $response = $this->getJson('/api/v1/video-call/history');

        // Assert
        $response->assertStatus(200)
                ->assertJsonStructure([
                    'success',
                    'calls',
                    'pagination' => [
                        'current_page',
                        'last_page',
                        'per_page',
                        'total',
                    ],
                ]);

        $this->assertCount(3, $response->json('calls'));
    }

    /** @test */
    public function it_can_get_call_statistics()
    {
        // Arrange
        VideoCall::factory()->create([
            'caller_id' => $this->user->id,
            'call_type' => 'video',
            'status' => 'ended',
            'duration_seconds' => 300,
        ]);

        VideoCall::factory()->create([
            'receiver_id' => $this->user->id,
            'call_type' => 'audio',
            'status' => 'ended',
            'duration_seconds' => 180,
        ]);

        Auth::login($this->user);

        // Act
        $response = $this->getJson('/api/v1/video-call/statistics');

        // Assert
        $response->assertStatus(200)
                ->assertJsonStructure([
                    'success',
                    'statistics' => [
                        'total_calls',
                        'total_duration',
                        'video_calls',
                        'audio_calls',
                        'completed_calls',
                        'missed_calls',
                    ],
                ]);

        $stats = $response->json('statistics');
        $this->assertEquals(2, $stats['total_calls']);
        $this->assertEquals(480, $stats['total_duration']);
        $this->assertEquals(1, $stats['video_calls']);
        $this->assertEquals(1, $stats['audio_calls']);
    }

    /** @test */
    public function it_validates_required_fields_when_starting_call()
    {
        // Arrange
        Auth::login($this->user);

        // Act
        $response = $this->postJson('/api/v1/video-call/start', []);

        // Assert
        $response->assertStatus(422)
                ->assertJsonValidationErrors(['receiver_id', 'call_type']);
    }

    /** @test */
    public function it_prevents_starting_call_to_nonexistent_user()
    {
        // Arrange
        Auth::login($this->user);

        // Act
        $response = $this->postJson('/api/v1/video-call/start', [
            'receiver_id' => 99999,
            'call_type' => 'video',
        ]);

        // Assert
        $response->assertStatus(422)
                ->assertJsonValidationErrors(['receiver_id']);
    }

    /** @test */
    public function it_prevents_unauthorized_user_from_answering_call()
    {
        // Arrange
        $videoCall = VideoCall::factory()->create([
            'caller_id' => $this->user->id,
            'receiver_id' => $this->receiver->id,
        ]);

        $unauthorizedUser = User::factory()->create();

        Auth::login($unauthorizedUser);

        // Act
        $response = $this->postJson('/api/v1/video-call/answer', [
            'call_id' => $videoCall->call_id,
            'call_type' => 'video',
        ]);

        // Assert
        $response->assertStatus(403)
                ->assertJson([
                    'success' => false,
                    'error' => [
                        'code' => 'UNAUTHORIZED',
                    ],
                ]);
    }
}
