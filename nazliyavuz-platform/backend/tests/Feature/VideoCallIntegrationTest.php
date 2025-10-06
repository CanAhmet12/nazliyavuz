<?php

namespace Tests\Feature;

use Tests\TestCase;
use App\Models\User;
use App\Models\VideoCall;
use App\Models\VideoCallParticipant;
use App\Models\Reservation;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;

class VideoCallIntegrationTest extends TestCase
{
    use RefreshDatabase;

    protected $teacher;
    protected $student;

    protected function setUp(): void
    {
        parent::setUp();
        
        $this->teacher = User::factory()->create(['role' => 'teacher']);
        $this->student = User::factory()->create(['role' => 'student']);
        
        Notification::fake();
    }

    /** @test */
    public function complete_video_call_flow_works_correctly()
    {
        // Step 1: Teacher starts a video call
        $startResponse = $this->actingAs($this->teacher)
            ->postJson('/api/v1/video-call/start', [
                'receiver_id' => $this->student->id,
                'call_type' => 'video',
                'subject' => 'Math Lesson',
            ]);

        $startResponse->assertStatus(200)
                     ->assertJsonStructure([
                         'success',
                         'call_id',
                         'video_call',
                     ]);

        $callId = $startResponse->json('call_id');

        // Verify call was created
        $this->assertDatabaseHas('video_calls', [
            'caller_id' => $this->teacher->id,
            'receiver_id' => $this->student->id,
            'call_type' => 'video',
            'status' => 'initiated',
        ]);

        // Step 2: Student answers the call
        $answerResponse = $this->actingAs($this->student)
            ->postJson('/api/v1/video-call/answer', [
                'call_id' => $callId,
                'call_type' => 'video',
            ]);

        $answerResponse->assertStatus(200)
                      ->assertJson(['success' => true]);

        // Verify call status updated
        $this->assertDatabaseHas('video_calls', [
            'call_id' => $callId,
            'status' => 'active',
        ]);

        // Step 3: Teacher toggles mute
        $muteResponse = $this->actingAs($this->teacher)
            ->postJson('/api/v1/video-call/toggle-mute', [
                'call_id' => $callId,
                'muted' => true,
            ]);

        $muteResponse->assertStatus(200)
                    ->assertJson(['muted' => true]);

        // Step 4: Student toggles video
        $videoResponse = $this->actingAs($this->student)
            ->postJson('/api/v1/video-call/toggle-video', [
                'call_id' => $callId,
                'video_enabled' => false,
            ]);

        $videoResponse->assertStatus(200)
                     ->assertJson(['video_enabled' => false]);

        // Step 5: Teacher ends the call
        $endResponse = $this->actingAs($this->teacher)
            ->postJson('/api/v1/video-call/end', [
                'call_id' => $callId,
                'reason' => 'Lesson completed',
            ]);

        $endResponse->assertStatus(200)
                   ->assertJson(['success' => true]);

        // Verify call was ended
        $this->assertDatabaseHas('video_calls', [
            'call_id' => $callId,
            'status' => 'ended',
            'end_reason' => 'Lesson completed',
        ]);
    }

    /** @test */
    public function video_call_with_reservation_works_correctly()
    {
        // Create a reservation
        $reservation = Reservation::factory()->create([
            'teacher_id' => $this->teacher->id,
            'student_id' => $this->student->id,
            'status' => 'accepted',
        ]);

        // Start video call with reservation
        $response = $this->actingAs($this->teacher)
            ->postJson('/api/v1/video-call/start', [
                'receiver_id' => $this->student->id,
                'call_type' => 'video',
                'subject' => 'Math Lesson',
                'reservation_id' => $reservation->id,
            ]);

        $response->assertStatus(200);

        // Verify reservation is linked
        $this->assertDatabaseHas('video_calls', [
            'reservation_id' => $reservation->id,
            'caller_id' => $this->teacher->id,
            'receiver_id' => $this->student->id,
        ]);
    }

    /** @test */
    public function call_rejection_flow_works_correctly()
    {
        // Teacher starts call
        $startResponse = $this->actingAs($this->teacher)
            ->postJson('/api/v1/video-call/start', [
                'receiver_id' => $this->student->id,
                'call_type' => 'video',
            ]);

        $callId = $startResponse->json('call_id');

        // Student rejects call
        $rejectResponse = $this->actingAs($this->student)
            ->postJson('/api/v1/video-call/reject', [
                'call_id' => $callId,
                'reason' => 'Busy with another call',
            ]);

        $rejectResponse->assertStatus(200)
                      ->assertJson(['success' => true]);

        // Verify call was rejected
        $this->assertDatabaseHas('video_calls', [
            'call_id' => $callId,
            'status' => 'rejected',
            'end_reason' => 'Busy with another call',
        ]);
    }

    /** @test */
    public function call_history_integration_works()
    {
        // Create multiple calls
        VideoCall::factory()->create([
            'caller_id' => $this->teacher->id,
            'receiver_id' => $this->student->id,
            'call_type' => 'video',
            'status' => 'ended',
            'duration_seconds' => 300,
        ]);

        VideoCall::factory()->create([
            'caller_id' => $this->student->id,
            'receiver_id' => $this->teacher->id,
            'call_type' => 'audio',
            'status' => 'ended',
            'duration_seconds' => 180,
        ]);

        // Get call history for teacher
        $historyResponse = $this->actingAs($this->teacher)
            ->getJson('/api/v1/video-call/history');

        $historyResponse->assertStatus(200)
                       ->assertJsonStructure([
                           'success',
                           'calls',
                           'pagination',
                       ]);

        $this->assertCount(2, $historyResponse->json('calls'));
    }

    /** @test */
    public function call_statistics_integration_works()
    {
        // Create calls with different statuses
        VideoCall::factory()->create([
            'caller_id' => $this->teacher->id,
            'receiver_id' => $this->student->id,
            'call_type' => 'video',
            'status' => 'ended',
            'duration_seconds' => 300,
        ]);

        VideoCall::factory()->create([
            'receiver_id' => $this->teacher->id,
            'caller_id' => $this->student->id,
            'call_type' => 'audio',
            'status' => 'rejected',
        ]);

        // Get statistics
        $statsResponse = $this->actingAs($this->teacher)
            ->getJson('/api/v1/video-call/statistics');

        $statsResponse->assertStatus(200)
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

        $stats = $statsResponse->json('statistics');
        $this->assertEquals(2, $stats['total_calls']);
        $this->assertEquals(300, $stats['total_duration']);
        $this->assertEquals(1, $stats['video_calls']);
        $this->assertEquals(1, $stats['audio_calls']);
        $this->assertEquals(1, $stats['completed_calls']);
        $this->assertEquals(1, $stats['missed_calls']);
    }

    /** @test */
    public function availability_status_integration_works()
    {
        // Set availability status
        $setResponse = $this->actingAs($this->teacher)
            ->postJson('/api/v1/video-call/set-availability', [
                'available' => false,
            ]);

        $setResponse->assertStatus(200)
                   ->assertJson(['available' => false]);

        // Check availability
        $checkResponse = $this->actingAs($this->student)
            ->getJson("/api/v1/video-call/availability/{$this->teacher->id}");

        $checkResponse->assertStatus(200)
                     ->assertJson(['available' => false]);
    }

    /** @test */
    public function unauthorized_access_is_prevented()
    {
        $videoCall = VideoCall::factory()->create([
            'caller_id' => $this->teacher->id,
            'receiver_id' => $this->student->id,
        ]);

        $unauthorizedUser = User::factory()->create();

        // Try to answer call as unauthorized user
        $response = $this->actingAs($unauthorizedUser)
            ->postJson('/api/v1/video-call/answer', [
                'call_id' => $videoCall->call_id,
                'call_type' => 'video',
            ]);

        $response->assertStatus(403)
                ->assertJson([
                    'success' => false,
                    'error' => [
                        'code' => 'UNAUTHORIZED',
                    ],
                ]);
    }

    /** @test */
    public function validation_errors_are_handled_correctly()
    {
        // Try to start call without required fields
        $response = $this->actingAs($this->teacher)
            ->postJson('/api/v1/video-call/start', []);

        $response->assertStatus(422)
                ->assertJsonValidationErrors(['receiver_id', 'call_type']);

        // Try to start call with invalid call type
        $response = $this->actingAs($this->teacher)
            ->postJson('/api/v1/video-call/start', [
                'receiver_id' => $this->student->id,
                'call_type' => 'invalid',
            ]);

        $response->assertStatus(422)
                ->assertJsonValidationErrors(['call_type']);
    }

    /** @test */
    public function concurrent_calls_are_handled_correctly()
    {
        // Start first call
        $call1Response = $this->actingAs($this->teacher)
            ->postJson('/api/v1/video-call/start', [
                'receiver_id' => $this->student->id,
                'call_type' => 'video',
            ]);

        $call1Response->assertStatus(200);
        $call1Id = $call1Response->json('call_id');

        // Try to start second call to same user
        $call2Response = $this->actingAs($this->teacher)
            ->postJson('/api/v1/video-call/start', [
                'receiver_id' => $this->student->id,
                'call_type' => 'audio',
            ]);

        // Should still work (different call types or times)
        $call2Response->assertStatus(200);
        $call2Id = $call2Response->json('call_id');

        // Verify both calls exist
        $this->assertDatabaseHas('video_calls', ['call_id' => $call1Id]);
        $this->assertDatabaseHas('video_calls', ['call_id' => $call2Id]);
    }
}
