<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Symfony\Component\HttpFoundation\Response;

class ResponseCacheMiddleware
{
    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next): Response
    {
        // Sadece GET istekleri için cache uygula
        if ($request->method() !== 'GET') {
            return $next($request);
        }

        // Cache key oluştur
        $cacheKey = 'response_' . md5($request->fullUrl() . $request->header('Authorization', ''));
        
        // Cache'den kontrol et
        if (Cache::has($cacheKey)) {
            $cachedResponse = Cache::get($cacheKey);
            
            return response($cachedResponse['content'])
                ->withHeaders($cachedResponse['headers'])
                ->setStatusCode($cachedResponse['status']);
        }

        // Response'u yakala
        $response = $next($request);
        
        // Başarılı response'ları cache'le
        if ($response->getStatusCode() === 200) {
            $cacheData = [
                'content' => $response->getContent(),
                'headers' => $response->headers->all(),
                'status' => $response->getStatusCode(),
            ];
            
            // Cache süresi belirle
            $cacheTime = $this->getCacheTime($request);
            Cache::put($cacheKey, $cacheData, $cacheTime);
        }

        return $response;
    }

    /**
     * Request'e göre cache süresini belirle
     */
    private function getCacheTime(Request $request): int
    {
        $path = $request->path();
        
        // Öğretmenler listesi - 5 dakika
        if (str_contains($path, 'teachers') && !str_contains($path, 'featured')) {
            return 300;
        }
        
        // Kategoriler - 1 saat
        if (str_contains($path, 'categories')) {
            return 3600;
        }
        
        // İstatistikler - 10 dakika
        if (str_contains($path, 'statistics')) {
            return 600;
        }
        
        // Diğer endpoint'ler - 2 dakika
        return 120;
    }
}
