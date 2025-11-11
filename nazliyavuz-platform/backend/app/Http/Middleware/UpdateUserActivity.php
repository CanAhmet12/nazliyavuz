<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use App\Services\UserActivityService;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;

/**
 * Update User Activity Middleware
 * Automatically updates user activity on every API request
 */
class UpdateUserActivity
{
    protected $userActivityService;

    public function __construct(UserActivityService $userActivityService)
    {
        $this->userActivityService = $userActivityService;
    }

    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next)
    {
        // Check if user is authenticated
        if (Auth::check()) {
            $userId = Auth::id();
            
            try {
                // Update user activity
                $this->userActivityService->updateUserActivity($userId);
                
                Log::debug('User activity updated via middleware', [
                    'user_id' => $userId,
                    'endpoint' => $request->path(),
                    'method' => $request->method()
                ]);
                
            } catch (\Exception $e) {
                Log::error('Failed to update user activity via middleware', [
                    'user_id' => $userId,
                    'error' => $e->getMessage()
                ]);
            }
        }

        return $next($request);
    }
}
