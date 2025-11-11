<?php

namespace Database\Factories;

use App\Models\Teacher;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\Teacher>
 */
class TeacherFactory extends Factory
{
    protected $model = Teacher::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory()->teacher(),
            'bio' => $this->faker->paragraph(),
            'education' => [
                [
                    'school' => $this->faker->company() . ' Üniversitesi',
                    'degree' => 'Lisans',
                    'field' => $this->faker->randomElement(['Matematik', 'Fizik', 'Kimya', 'İngilizce']),
                    'year' => $this->faker->year(),
                ],
            ],
            'certifications' => [],
            'price_hour' => $this->faker->randomFloat(2, 150, 600),
            'languages' => $this->faker->randomElements(
                ['Türkçe', 'İngilizce', 'Almanca', 'Fransızca'],
                $this->faker->numberBetween(1, 3),
            ),
            'experience_years' => $this->faker->numberBetween(1, 15),
            'rating_avg' => $this->faker->randomFloat(2, 3, 5),
            'rating_count' => $this->faker->numberBetween(0, 250),
            'online_available' => $this->faker->boolean(80),
            'is_approved' => true,
            'approved_at' => now(),
            'approved_by' => null,
        ];
    }

    /**
     * Indicate that the teacher is not yet approved.
     */
    public function pending(): static
    {
        return $this->state(fn (array $attributes) => [
            'is_approved' => false,
            'approved_at' => null,
        ]);
    }
}


