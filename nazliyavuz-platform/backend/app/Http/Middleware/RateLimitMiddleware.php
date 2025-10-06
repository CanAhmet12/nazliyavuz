<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Http\JsonResponse;

class RateLimitMiddleware
{
    /**
     * Handle an incoming request.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Closure(\Illuminate\Http\Request): (\Illuminate\Http\Response|\Illuminate\Http\JsonResponse)  $next
     * @param  string  $key
     * @param  int  $maxAttempts
     * @param  int  $decayMinutes
     * @return \Illuminate\Http\Response|\Illuminate\Http\JsonResponse
     */
    public function handle(Request $request, Closure $next, string $key = 'api', int $maxAttempts = 60, int $decayMinutes = 1)
    {
        $key = $this->resolveRequestSignature($request, $key);

        // Different limits for different endpoints
        $endpointLimits = $this->getEndpointLimits($request);
        if ($endpointLimits) {
            $maxAttempts = $endpointLimits['maxAttempts'];
            $decayMinutes = $endpointLimits['decayMinutes'];
        }

        if (RateLimiter::tooManyAttempts($key, $maxAttempts)) {
            return $this->buildResponse($key, $maxAttempts);
        }

        RateLimiter::hit($key, $decayMinutes * 60);

        $response = $next($request);

        return $this->addHeaders(
            $response,
            $maxAttempts,
            $this->calculateRemainingAttempts($key, $maxAttempts)
        );
    }

    /**
     * Get specific limits for different endpoints
     */
    private function getEndpointLimits(Request $request): ?array
    {
        $path = $request->path();
        
        // Authentication endpoints - relaxed limits for development
        if (str_contains($path, 'auth/login') || str_contains($path, 'auth/register')) {
            return ['maxAttempts' => 50, 'decayMinutes' => 1];
        }
        
        // Password reset - very strict
        if (str_contains($path, 'password/reset')) {
            return ['maxAttempts' => 3, 'decayMinutes' => 60];
        }
        
        // File upload - moderate limits
        if (str_contains($path, 'upload')) {
            return ['maxAttempts' => 20, 'decayMinutes' => 1];
        }
        
        // Search endpoints - higher limits
        if (str_contains($path, 'search')) {
            return ['maxAttempts' => 100, 'decayMinutes' => 1];
        }
        
        // Admin endpoints - strict limits
        if (str_contains($path, 'admin')) {
            return ['maxAttempts' => 30, 'decayMinutes' => 1];
        }
        
        return null;
    }

    /**
     * Resolve request signature.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  string  $key
     * @return string
     */
    protected function resolveRequestSignature(Request $request, string $key): string
    {
        if ($user = $request->user()) {
            return $key . '|' . $user->id;
        }

        return $key . '|' . $request->ip();
    }

    /**
     * Create a too many attempts response.
     *
     * @param  string  $key
     * @param  int  $maxAttempts
     * @return \Illuminate\Http\JsonResponse
     */
    protected function buildResponse(string $key, int $maxAttempts): JsonResponse
    {
        $retryAfter = RateLimiter::availableIn($key);

        return response()->json([
            'error' => [
                'code' => 'RATE_LIMIT_EXCEEDED',
                'message' => 'Çok fazla istek gönderildi. Lütfen ' . $retryAfter . ' saniye sonra tekrar deneyin.',
                'retry_after' => $retryAfter,
            ]
        ], 429);
    }

    /**
     * Add the limit header information to the given response.
     *
     * @param  \Illuminate\Http\Response|\Illuminate\Http\JsonResponse  $response
     * @param  int  $maxAttempts
     * @param  int  $remainingAttempts
     * @return \Illuminate\Http\Response|\Illuminate\Http\JsonResponse
     */
    protected function addHeaders($response, int $maxAttempts, int $remainingAttempts)
    {
        $response->headers->add([
            'X-RateLimit-Limit' => $maxAttempts,
            'X-RateLimit-Remaining' => $remainingAttempts,
        ]);

        return $response;
    }

    /**
     * Calculate the number of remaining attempts.
     *
     * @param  string  $key
     * @param  int  $maxAttempts
     * @return int
     */
    protected function calculateRemainingAttempts(string $key, int $maxAttempts): int
    {
        return max(0, $maxAttempts - RateLimiter::attempts($key));
    }
}
