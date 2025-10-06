<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use App\Services\AdvancedCacheService;
use Symfony\Component\HttpFoundation\Response as BaseResponse;

class AdvancedCacheMiddleware
{
    private AdvancedCacheService $cacheService;

    public function __construct(AdvancedCacheService $cacheService)
    {
        $this->cacheService = $cacheService;
    }

    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next, string $cacheType = 'default', int $ttl = 300): BaseResponse
    {
        // Only cache GET requests
        if (!$request->isMethod('GET')) {
            return $next($request);
        }

        // Skip caching for authenticated users on sensitive endpoints
        if ($this->shouldSkipCache($request)) {
            return $next($request);
        }

        // Generate cache key based on cache type
        $cacheKey = $this->generateCacheKey($request, $cacheType);

        // Try to get from cache
        $cachedResponse = Cache::get($cacheKey);
        if ($cachedResponse) {
            return response()->json($cachedResponse)
                ->header('X-Cache', 'HIT')
                ->header('X-Cache-Key', $cacheKey)
                ->header('X-Cache-Type', $cacheType);
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
                        ->header('X-Cache-Type', $cacheType)
                        ->header('X-Cache-TTL', $ttl);
            }
        }

        return $response;
    }

    /**
     * Generate cache key based on request and cache type
     */
    private function generateCacheKey(Request $request, string $cacheType): string
    {
        $userId = auth()->id();
        $route = $request->route()->getName();
        $queryParams = $request->query();
        
        // Sort query parameters for consistent cache keys
        ksort($queryParams);
        
        $keyData = [
            'type' => $cacheType,
            'route' => $route,
            'user_id' => $userId,
            'params' => $queryParams,
        ];
        
        return 'advanced_cache:' . md5(serialize($keyData));
    }

    /**
     * Determine if caching should be skipped for this request
     */
    private function shouldSkipCache(Request $request): bool
    {
        $route = $request->route();
        
        // Skip caching for authenticated users on sensitive endpoints
        if (auth()->check()) {
            $sensitiveRoutes = [
                'user.profile',
                'user.settings',
                'teacher.profile',
                'student.profile',
                'reservations.create',
                'reservations.update',
                'messages.send',
                'chats.create',
                'notifications.mark-read',
            ];
            
            if (in_array($route->getName(), $sensitiveRoutes)) {
                return true;
            }
        }

        // Skip caching for admin routes
        if (str_starts_with($route->uri(), 'admin/')) {
            return true;
        }

        // Skip caching for real-time data
        $realtimeRoutes = [
            'messages.latest',
            'notifications.unread',
            'online-status',
            'typing-status',
        ];
        
        if (in_array($route->getName(), $realtimeRoutes)) {
            return true;
        }

        return false;
    }
}
