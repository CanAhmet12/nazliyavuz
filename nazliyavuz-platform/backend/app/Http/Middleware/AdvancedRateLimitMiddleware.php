<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

class AdvancedRateLimitMiddleware
{
    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next, string $rateLimitType = 'default', int $maxAttempts = 60, int $decayMinutes = 1): Response
    {
        $key = $this->generateKey($request, $rateLimitType);
        
        // Get current attempts
        $attempts = Cache::get($key, 0);
        
        // Check if rate limit exceeded
        if ($attempts >= $maxAttempts) {
            Log::warning('Rate limit exceeded', [
                'ip' => $request->ip(),
                'user_id' => Auth::id(),
                'endpoint' => $request->path(),
                'rate_limit_type' => $rateLimitType,
                'attempts' => $attempts,
                'max_attempts' => $maxAttempts,
            ]);
            
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => 'RATE_LIMIT_EXCEEDED',
                    'message' => 'Too many requests. Please try again later.',
                    'retry_after' => $decayMinutes * 60,
                ]
            ], 429)->header('Retry-After', $decayMinutes * 60);
        }
        
        // Increment attempts
        Cache::put($key, $attempts + 1, $decayMinutes * 60);
        
        // Add rate limit headers
        $response = $next($request);
        
        $remaining = max(0, $maxAttempts - ($attempts + 1));
        $resetTime = now()->addMinutes($decayMinutes)->timestamp;
        
        $response->headers->set('X-RateLimit-Limit', $maxAttempts);
        $response->headers->set('X-RateLimit-Remaining', $remaining);
        $response->headers->set('X-RateLimit-Reset', $resetTime);
        
        return $response;
    }

    /**
     * Generate rate limit key based on type and user/IP
     */
    private function generateKey(Request $request, string $rateLimitType): string
    {
        $user = Auth::user();
        
        switch ($rateLimitType) {
            case 'user':
                return $user ? "rate_limit:user:{$user->id}:{$request->path()}" : null;
                
            case 'ip':
                return "rate_limit:ip:{$request->ip()}:{$request->path()}";
                
            case 'global':
                return "rate_limit:global:{$request->path()}";
                
            case 'auth':
                return "rate_limit:auth:{$request->ip()}:{$request->path()}";
                
            case 'api':
                return $user ? "rate_limit:api:user:{$user->id}" : "rate_limit:api:ip:{$request->ip()}";
                
            case 'video_call':
                return $user ? "rate_limit:video_call:{$user->id}" : "rate_limit:video_call:ip:{$request->ip()}";
                
            case 'file_upload':
                return $user ? "rate_limit:file_upload:{$user->id}" : "rate_limit:file_upload:ip:{$request->ip()}";
                
            case 'message':
                return $user ? "rate_limit:message:{$user->id}" : "rate_limit:message:ip:{$request->ip()}";
                
            case 'search':
                return $user ? "rate_limit:search:{$user->id}" : "rate_limit:search:ip:{$request->ip()}";
                
            default:
                return $user ? "rate_limit:default:{$user->id}:{$request->path()}" : "rate_limit:default:ip:{$request->ip()}:{$request->path()}";
        }
    }
}
