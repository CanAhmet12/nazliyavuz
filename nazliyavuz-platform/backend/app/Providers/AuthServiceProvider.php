<?php

namespace App\Providers;

use Illuminate\Foundation\Support\Providers\AuthServiceProvider as ServiceProvider;
use Illuminate\Support\Facades\Gate;

class AuthServiceProvider extends ServiceProvider
{
    /**
     * The model to policy mappings for the application.
     *
     * @var array<class-string, class-string>
     */
    protected $policies = [
        //
    ];

    /**
     * Register any authentication / authorization services.
     */
    public function boot(): void
    {
        // Admin gate
        Gate::define('admin', function ($user) {
            return $user->isAdmin();
        });

        // Teacher gate
        Gate::define('teacher', function ($user) {
            return $user->isTeacher();
        });

        // Student gate
        Gate::define('student', function ($user) {
            return $user->isStudent();
        });

        // User can manage their own profile
        Gate::define('manage-profile', function ($user, $profileUser) {
            return $user->id === $profileUser->id || $user->isAdmin();
        });

        // User can manage their own reservations
        Gate::define('manage-reservation', function ($user, $reservation) {
            return $user->id === $reservation->student_id || 
                   $user->id === $reservation->teacher_id || 
                   $user->isAdmin();
        });
    }
}
