<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;

class TestUserSeeder extends Seeder
{
    public function run(): void
    {
        // Create test student
        $student = User::firstOrCreate(
            ['email' => 'test@student.com'],
            [
                'name' => 'Test Student',
                'password' => bcrypt('password'),
                'role' => 'student',
                'email_verified_at' => now(),
            ]
        );

        // Create test teacher
        $teacher = User::firstOrCreate(
            ['email' => 'test@teacher.com'],
            [
                'name' => 'Test Teacher',
                'password' => bcrypt('password'),
                'role' => 'teacher',
                'email_verified_at' => now(),
            ]
        );

        $this->command->info('✅ Test users created successfully!');
        $this->command->info('Student: test@student.com / password');
        $this->command->info('Teacher: test@teacher.com / password');
    }
}