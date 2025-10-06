<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

class CreateTestUser extends Command
{
    protected $signature = 'user:create-test';
    protected $description = 'Create a test user for login testing';

    public function handle()
    {
        try {
            // Check if user already exists
            $existingUser = User::where('email', 'can65385@gmail.com')->first();
            
            if ($existingUser) {
                $this->info('User already exists with ID: ' . $existingUser->id);
                return;
            }

            // Create new user
            $user = User::create([
                'name' => 'Ahmet Can',
                'email' => 'can65385@gmail.com',
                'password' => Hash::make('Ahmetcan'),
                'role' => 'student',
                'email_verified_at' => now(),
            ]);

            $this->info('Test user created successfully!');
            $this->info('ID: ' . $user->id);
            $this->info('Email: ' . $user->email);
            $this->info('Password: Ahmetcan');
            $this->info('Role: ' . $user->role);

        } catch (\Exception $e) {
            $this->error('Error creating user: ' . $e->getMessage());
        }
    }
}