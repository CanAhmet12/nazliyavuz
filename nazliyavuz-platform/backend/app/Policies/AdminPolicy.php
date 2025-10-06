<?php

namespace App\Policies;

use App\Models\User;

class AdminPolicy
{
    /**
     * Determine if the user can access admin panel
     */
    public function admin(User $user): bool
    {
        return $user->isAdmin();
    }
}
