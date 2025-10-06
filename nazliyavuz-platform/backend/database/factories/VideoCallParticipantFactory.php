<?php

namespace Database\Factories;

use App\Models\VideoCallParticipant;
use App\Models\VideoCall;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\VideoCallParticipant>
 */
class VideoCallParticipantFactory extends Factory
{
    /**
     * The name of the factory's corresponding model.
     *
     * @var string
     */
    protected $model = VideoCallParticipant::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $videoCallId = VideoCall::factory()->create()->id;
        $userId = User::factory()->create()->id;
        $role = $this->faker->randomElement(['caller', 'receiver']);
        $status = $this->faker->randomElement(['invited', 'active', 'left', 'disconnected']);
        
        $joinedAt = $this->faker->optional(0.8)->dateTimeBetween('-1 hour', 'now');
        $leftAt = null;
        
        if (in_array($status, ['left', 'disconnected'])) {
            $leftAt = $this->faker->dateTimeBetween($joinedAt ?? '-1 hour', 'now');
        }

        return [
            'video_call_id' => $videoCallId,
            'user_id' => $userId,
            'role' => $role,
            'status' => $status,
            'joined_at' => $joinedAt,
            'left_at' => $leftAt,
            'is_muted' => $this->faker->boolean(30),
            'video_enabled' => $this->faker->boolean(85),
            'screen_sharing' => $this->faker->boolean(5),
            'connection_quality' => $this->faker->optional(0.6)->randomElements([
                'bitrate' => $this->faker->numberBetween(100, 1000),
                'latency' => $this->faker->numberBetween(50, 500),
                'packet_loss' => $this->faker->randomFloat(2, 0, 0.1),
                'resolution' => $this->faker->randomElement(['720p', '1080p', '4K']),
                'fps' => $this->faker->randomElement([15, 30, 60]),
                'codec' => $this->faker->randomElement(['H.264', 'VP8', 'VP9']),
            ], $this->faker->numberBetween(3, 6)),
        ];
    }

    /**
     * Indicate that the participant is a caller.
     */
    public function caller(): static
    {
        return $this->state(fn (array $attributes) => [
            'role' => 'caller',
        ]);
    }

    /**
     * Indicate that the participant is a receiver.
     */
    public function receiver(): static
    {
        return $this->state(fn (array $attributes) => [
            'role' => 'receiver',
        ]);
    }

    /**
     * Indicate that the participant is active.
     */
    public function active(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'active',
            'joined_at' => now()->subMinutes(5),
            'left_at' => null,
        ]);
    }

    /**
     * Indicate that the participant has left.
     */
    public function left(): static
    {
        $joinedAt = $this->faker->dateTimeBetween('-1 hour', 'now');
        $leftAt = $this->faker->dateTimeBetween($joinedAt, 'now');
        
        return $this->state(fn (array $attributes) => [
            'status' => 'left',
            'joined_at' => $joinedAt,
            'left_at' => $leftAt,
        ]);
    }

    /**
     * Indicate that the participant is disconnected.
     */
    public function disconnected(): static
    {
        $joinedAt = $this->faker->dateTimeBetween('-1 hour', 'now');
        $leftAt = $this->faker->dateTimeBetween($joinedAt, 'now');
        
        return $this->state(fn (array $attributes) => [
            'status' => 'disconnected',
            'joined_at' => $joinedAt,
            'left_at' => $leftAt,
        ]);
    }

    /**
     * Indicate that the participant is muted.
     */
    public function muted(): static
    {
        return $this->state(fn (array $attributes) => [
            'is_muted' => true,
        ]);
    }

    /**
     * Indicate that the participant is unmuted.
     */
    public function unmuted(): static
    {
        return $this->state(fn (array $attributes) => [
            'is_muted' => false,
        ]);
    }

    /**
     * Indicate that the participant has video enabled.
     */
    public function videoEnabled(): static
    {
        return $this->state(fn (array $attributes) => [
            'video_enabled' => true,
        ]);
    }

    /**
     * Indicate that the participant has video disabled.
     */
    public function videoDisabled(): static
    {
        return $this->state(fn (array $attributes) => [
            'video_enabled' => false,
        ]);
    }

    /**
     * Indicate that the participant is screen sharing.
     */
    public function screenSharing(): static
    {
        return $this->state(fn (array $attributes) => [
            'screen_sharing' => true,
        ]);
    }

    /**
     * Indicate that the participant has high connection quality.
     */
    public function highConnectionQuality(): static
    {
        return $this->state(fn (array $attributes) => [
            'connection_quality' => [
                'bitrate' => $this->faker->numberBetween(500, 1000),
                'latency' => $this->faker->numberBetween(50, 150),
                'packet_loss' => $this->faker->randomFloat(2, 0, 0.02),
                'resolution' => '1080p',
                'fps' => 30,
                'codec' => 'H.264',
            ],
        ]);
    }

    /**
     * Indicate that the participant has low connection quality.
     */
    public function lowConnectionQuality(): static
    {
        return $this->state(fn (array $attributes) => [
            'connection_quality' => [
                'bitrate' => $this->faker->numberBetween(100, 300),
                'latency' => $this->faker->numberBetween(300, 500),
                'packet_loss' => $this->faker->randomFloat(2, 0.05, 0.1),
                'resolution' => '720p',
                'fps' => 15,
                'codec' => 'VP8',
            ],
        ]);
    }
}
