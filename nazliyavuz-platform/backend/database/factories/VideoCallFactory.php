<?php

namespace Database\Factories;

use App\Models\VideoCall;
use App\Models\User;
use App\Models\Reservation;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\VideoCall>
 */
class VideoCallFactory extends Factory
{
    /**
     * The name of the factory's corresponding model.
     *
     * @var string
     */
    protected $model = VideoCall::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $callerId = User::factory()->create(['role' => 'teacher'])->id;
        $receiverId = User::factory()->create(['role' => 'student'])->id;
        
        $status = $this->faker->randomElement(['initiated', 'active', 'ended', 'rejected', 'missed']);
        $callType = $this->faker->randomElement(['video', 'audio']);
        
        $startedAt = $this->faker->dateTimeBetween('-1 week', 'now');
        $endedAt = null;
        $durationSeconds = null;
        
        if (in_array($status, ['ended', 'rejected', 'missed'])) {
            $endedAt = $this->faker->dateTimeBetween($startedAt, 'now');
            $durationSeconds = $endedAt->getTimestamp() - $startedAt->getTimestamp();
        }

        return [
            'call_id' => 'call_' . $this->faker->uuid(),
            'caller_id' => $callerId,
            'receiver_id' => $receiverId,
            'call_type' => $callType,
            'subject' => $this->faker->optional(0.7)->sentence(3),
            'reservation_id' => $this->faker->optional(0.3)->randomElement(
                Reservation::pluck('id')->toArray() ?: [null]
            ),
            'status' => $status,
            'started_at' => $startedAt,
            'answered_at' => $status === 'active' ? $this->faker->dateTimeBetween($startedAt, 'now') : null,
            'ended_at' => $endedAt,
            'duration_seconds' => $durationSeconds,
            'end_reason' => $endedAt ? $this->faker->randomElement([
                'Call completed',
                'Call ended by user',
                'Connection lost',
                'Call rejected by user',
                'Missed call',
            ]) : null,
            'call_quality_metrics' => $this->faker->optional(0.5)->randomElements([
                'video_quality' => $this->faker->randomFloat(2, 0, 5),
                'audio_quality' => $this->faker->randomFloat(2, 0, 5),
                'connection_stability' => $this->faker->randomFloat(2, 0, 5),
                'latency' => $this->faker->numberBetween(50, 500),
                'bitrate' => $this->faker->numberBetween(100, 1000),
                'packet_loss' => $this->faker->randomFloat(2, 0, 0.1),
            ], $this->faker->numberBetween(3, 6)),
            'is_recorded' => $this->faker->boolean(20),
            'recording_url' => $this->faker->optional(0.2)->url(),
            'screen_shared' => $this->faker->boolean(10),
            'metadata' => $this->faker->optional(0.3)->randomElements([
                'device_type' => $this->faker->randomElement(['mobile', 'desktop', 'tablet']),
                'platform' => $this->faker->randomElement(['android', 'ios', 'web', 'windows', 'mac']),
                'browser' => $this->faker->randomElement(['chrome', 'firefox', 'safari', 'edge']),
                'network_type' => $this->faker->randomElement(['wifi', 'cellular', 'ethernet']),
                'resolution' => $this->faker->randomElement(['720p', '1080p', '4K']),
            ], $this->faker->numberBetween(2, 5)),
        ];
    }

    /**
     * Indicate that the call is active.
     */
    public function active(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'active',
            'started_at' => now()->subMinutes(5),
            'answered_at' => now()->subMinutes(4),
            'ended_at' => null,
            'duration_seconds' => null,
            'end_reason' => null,
        ]);
    }

    /**
     * Indicate that the call is ended.
     */
    public function ended(): static
    {
        $startedAt = $this->faker->dateTimeBetween('-1 hour', 'now');
        $endedAt = $this->faker->dateTimeBetween($startedAt, 'now');
        
        return $this->state(fn (array $attributes) => [
            'status' => 'ended',
            'started_at' => $startedAt,
            'answered_at' => $this->faker->dateTimeBetween($startedAt, $endedAt),
            'ended_at' => $endedAt,
            'duration_seconds' => $endedAt->getTimestamp() - $startedAt->getTimestamp(),
            'end_reason' => $this->faker->randomElement([
                'Call completed',
                'Call ended by user',
                'Connection lost',
            ]),
        ]);
    }

    /**
     * Indicate that the call is rejected.
     */
    public function rejected(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'rejected',
            'started_at' => now()->subMinutes(2),
            'answered_at' => null,
            'ended_at' => now()->subMinutes(1),
            'duration_seconds' => 0,
            'end_reason' => $this->faker->randomElement([
                'Call rejected by user',
                'User busy',
                'No answer',
            ]),
        ]);
    }

    /**
     * Indicate that the call is missed.
     */
    public function missed(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'missed',
            'started_at' => now()->subMinutes(2),
            'answered_at' => null,
            'ended_at' => now()->subMinutes(1),
            'duration_seconds' => 0,
            'end_reason' => 'Missed call',
        ]);
    }

    /**
     * Indicate that the call is a video call.
     */
    public function video(): static
    {
        return $this->state(fn (array $attributes) => [
            'call_type' => 'video',
        ]);
    }

    /**
     * Indicate that the call is an audio call.
     */
    public function audio(): static
    {
        return $this->state(fn (array $attributes) => [
            'call_type' => 'audio',
        ]);
    }

    /**
     * Indicate that the call is recorded.
     */
    public function recorded(): static
    {
        return $this->state(fn (array $attributes) => [
            'is_recorded' => true,
            'recording_url' => $this->faker->url(),
        ]);
    }

    /**
     * Indicate that the call has screen sharing.
     */
    public function withScreenShare(): static
    {
        return $this->state(fn (array $attributes) => [
            'screen_shared' => true,
        ]);
    }

    /**
     * Indicate that the call has high quality metrics.
     */
    public function highQuality(): static
    {
        return $this->state(fn (array $attributes) => [
            'call_quality_metrics' => [
                'video_quality' => $this->faker->randomFloat(2, 4, 5),
                'audio_quality' => $this->faker->randomFloat(2, 4, 5),
                'connection_stability' => $this->faker->randomFloat(2, 4, 5),
                'latency' => $this->faker->numberBetween(50, 150),
                'bitrate' => $this->faker->numberBetween(500, 1000),
                'packet_loss' => $this->faker->randomFloat(2, 0, 0.02),
            ],
        ]);
    }

    /**
     * Indicate that the call has low quality metrics.
     */
    public function lowQuality(): static
    {
        return $this->state(fn (array $attributes) => [
            'call_quality_metrics' => [
                'video_quality' => $this->faker->randomFloat(2, 1, 2.5),
                'audio_quality' => $this->faker->randomFloat(2, 1, 2.5),
                'connection_stability' => $this->faker->randomFloat(2, 1, 2.5),
                'latency' => $this->faker->numberBetween(300, 500),
                'bitrate' => $this->faker->numberBetween(100, 300),
                'packet_loss' => $this->faker->randomFloat(2, 0.05, 0.1),
            ],
        ]);
    }
}
