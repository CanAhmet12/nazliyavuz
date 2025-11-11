<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\RateLimiter;

class AdminSecurityMiddleware
{
    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next)
    {
        $user = Auth::user();
        
        // Admin yetkisi kontrolü
        if (!$user || !$user->isAdmin()) {
            Log::warning('Unauthorized admin access attempt', [
                'user_id' => $user?->id,
                'ip' => $request->ip(),
                'user_agent' => $request->userAgent(),
                'url' => $request->fullUrl(),
            ]);
            
            return response()->json([
                'error' => [
                    'code' => 'UNAUTHORIZED',
                    'message' => 'Admin yetkisi gerekli'
                ]
            ], 403);
        }

        // Admin hesap durumu kontrolü
        if ($user->isSuspended()) {
            Log::warning('Suspended admin access attempt', [
                'user_id' => $user->id,
                'ip' => $request->ip(),
            ]);
            
            return response()->json([
                'error' => [
                    'code' => 'ACCOUNT_SUSPENDED',
                    'message' => 'Hesabınız askıya alınmış'
                ]
            ], 403);
        }

        // Rate limiting for admin operations
        $key = 'admin:' . $user->id . ':' . $request->ip();
        $maxAttempts = 100; // 100 requests per minute
        $decayMinutes = 1;

        if (RateLimiter::tooManyAttempts($key, $maxAttempts)) {
            $seconds = RateLimiter::availableIn($key);
            
            Log::warning('Admin rate limit exceeded', [
                'user_id' => $user->id,
                'ip' => $request->ip(),
                'seconds_remaining' => $seconds,
            ]);
            
            return response()->json([
                'error' => [
                    'code' => 'RATE_LIMIT_EXCEEDED',
                    'message' => 'Çok fazla istek gönderildi. Lütfen ' . $seconds . ' saniye bekleyin.'
                ]
            ], 429);
        }

        RateLimiter::hit($key, $decayMinutes * 60);

        // Log admin actions for audit
        if ($request->isMethod('POST') || $request->isMethod('PUT') || $request->isMethod('DELETE')) {
            Log::info('Admin action performed', [
                'user_id' => $user->id,
                'action' => $request->method() . ' ' . $request->path(),
                'ip' => $request->ip(),
                'user_agent' => $request->userAgent(),
                'data' => $request->except(['password', 'token']),
            ]);
        }

        return $next($request);
    }
}
