<?php

namespace Database\Factories;

use App\Models\Category;
use App\Models\Reservation;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Carbon;

/**
 * @extends Factory<Reservation>
 */
class ReservationFactory extends Factory
{
    protected $model = Reservation::class;

    public function definition(): array
    {
        $start = Carbon::now()->addDays($this->faker->numberBetween(1, 14))->setMinutes(0);

        return [
            'student_id' => User::factory()->student(),
            'teacher_id' => User::factory()->teacher(),
            'category_id' => Category::factory(),
            'subject' => $this->faker->sentence(3),
            'proposed_datetime' => $start,
            'duration_minutes' => $this->faker->randomElement([30, 45, 60, 90]),
            'price' => $this->faker->randomFloat(2, 100, 500),
            'status' => $this->faker->randomElement(['pending', 'accepted', 'completed']),
            'notes' => $this->faker->optional()->sentence(),
            'teacher_notes' => null,
            'payment_status' => 'unpaid',
            'payment_method' => null,
        ];
    }

    public function accepted(): static
    {
        return $this->state(fn () => ['status' => 'accepted']);
    }

    public function withTeacher(User $teacher): static
    {
        return $this->state(fn () => ['teacher_id' => $teacher->id]);
    }

    public function withStudent(User $student): static
    {
        return $this->state(fn () => ['student_id' => $student->id]);
    }
}


