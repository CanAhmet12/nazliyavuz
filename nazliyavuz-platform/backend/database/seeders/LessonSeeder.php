<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Lesson;
use App\Models\Reservation;
use App\Models\User;
use Carbon\Carbon;

class LessonSeeder extends Seeder
{
    public function run(): void
    {
        // Get some users and reservations
        $students = User::where('role', 'student')->take(3)->get();
        $teachers = User::where('role', 'teacher')->take(3)->get();
        $reservations = Reservation::take(5)->get();

        if ($students->isEmpty() || $teachers->isEmpty() || $reservations->isEmpty()) {
            $this->command->info('⚠️  Not enough users or reservations found. Creating sample data...');
            
            // Create sample users if needed
            if ($students->isEmpty()) {
                $students = collect([
                    User::create([
                        'name' => 'Ahmet Öğrenci',
                        'email' => 'ahmet@student.com',
                        'password' => bcrypt('password'),
                        'role' => 'student',
                        'email_verified_at' => now(),
                    ])
                ]);
            }
            
            if ($teachers->isEmpty()) {
                $teachers = collect([
                    User::create([
                        'name' => 'Ayşe Öğretmen',
                        'email' => 'ayse@teacher.com',
                        'password' => bcrypt('password'),
                        'role' => 'teacher',
                        'email_verified_at' => now(),
                    ])
                ]);
            }
            
            // Create sample reservations if needed
            if ($reservations->isEmpty()) {
                $reservations = collect([
                    Reservation::create([
                        'student_id' => $students->first()->id,
                        'teacher_id' => $teachers->first()->id,
                        'scheduled_at' => now()->addDays(1),
                        'duration' => 60,
                        'status' => 'confirmed',
                        'price' => 100.00,
                    ])
                ]);
            }
        }

        $lessonStatuses = ['scheduled', 'in_progress', 'completed', 'cancelled'];
        $lessonTypes = ['online', 'in_person'];

        foreach ($reservations as $index => $reservation) {
            $status = $lessonStatuses[array_rand($lessonStatuses)];
            $type = $lessonTypes[array_rand($lessonTypes)];
            
            $scheduledAt = $reservation->scheduled_at ?? now()->addDays($index);
            $startTime = null;
            $endTime = null;
            
            if (in_array($status, ['in_progress', 'completed'])) {
                $startTime = $scheduledAt->copy()->addMinutes(5);
            }
            
            if ($status === 'completed' && $startTime) {
                $endTime = $startTime->copy()->addMinutes(60);
            }

            Lesson::create([
                'reservation_id' => $reservation->id,
                'student_id' => $reservation->student_id,
                'teacher_id' => $reservation->teacher_id,
                'start_time' => $startTime,
                'end_time' => $endTime,
                'duration_minutes' => 60,
                'status' => $status,
                'notes' => $status === 'completed' ? 'Ders başarıyla tamamlandı.' : null,
                'rating' => $status === 'completed' ? rand(4, 5) : null,
                'feedback' => $status === 'completed' ? 'Çok faydalı bir ders oldu.' : null,
            ]);
        }

        $this->command->info('✅ Created ' . $reservations->count() . ' lessons successfully!');
    }
}