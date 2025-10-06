<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Response;
use Symfony\Component\HttpFoundation\Response as BaseResponse;

class CacheResponseMiddleware
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next, int $ttl = 300): BaseResponse
    {
        // Only cache GET requests
        if (!$request->isMethod('GET')) {
            return $next($request);
        }

        // Skip caching for authenticated users on sensitive endpoints
        if ($this->shouldSkipCache($request)) {
            return $next($request);
        }

        // Generate cache key
        $cacheKey = $this->generateCacheKey($request);

        // Try to get from cache
        $cachedResponse = Cache::get($cacheKey);
        if ($cachedResponse) {
            return response()->json($cachedResponse)
                ->header('X-Cache', 'HIT')
                ->header('X-Cache-Key', $cacheKey);
        }

        // Process request
        $response = $next($request);

        // Cache successful responses
        if ($response->getStatusCode() === 200 && $response instanceof \Illuminate\Http\JsonResponse) {
            $data = $response->getData(true);
            
            // Only cache if response is not too large
            if (strlen(json_encode($data)) < 1024 * 1024) { // 1MB limit
                Cache::put($cacheKey, $data, $ttl);
                
                $response->header('X-Cache', 'MISS')
                        ->header('X-Cache-Key', $cacheKey)
                        ->header('X-Cache-TTL', $ttl);
            }
        }

        return $response;
    }

    /**
     * Determine if caching should be skipped for this request
     */
    private function shouldSkipCache(Request $request): bool
    {
        // Skip for authenticated users on sensitive endpoints
        if (auth()->check()) {
            $sensitivePaths = [
                'admin',
                'profile',
                'reservations',
                'notifications',
                'ratings',
            ];

            foreach ($sensitivePaths as $path) {
                if (str_contains($request->path(), $path)) {
                    return true;
                }
            }
        }

        // Skip for requests with certain query parameters
        $skipParams = ['page', 'per_page', 'sort_by', 'sort_order'];
        foreach ($skipParams as $param) {
            if ($request->has($param)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Generate cache key for the request
     */
    private function generateCacheKey(Request $request): string
    {
        $key = 'response:' . $request->method() . ':' . $request->path();
        
        // Include query parameters (except pagination)
        $queryParams = $request->query();
        unset($queryParams['page'], $queryParams['per_page']);
        
        if (!empty($queryParams)) {
            ksort($queryParams);
            $key .= ':' . md5(serialize($queryParams));
        }

        // Include user role if authenticated
        if (auth()->check()) {
            $key .= ':' . auth()->user()->role;
        }

        return $key;
    }
}