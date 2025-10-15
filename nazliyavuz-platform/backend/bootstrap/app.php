<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
       ->withMiddleware(function (Middleware $middleware): void {
           // Global middleware
           $middleware->append(\App\Http\Middleware\CorsMiddleware::class);
           $middleware->append(\App\Http\Middleware\SecurityHeadersMiddleware::class);
           
           // API middleware configuration
           // $middleware->api(prepend: [
           //     \Laravel\Sanctum\Http\Middleware\EnsureFrontendRequestsAreStateful::class,
           // ]);
           
           $middleware->alias([
               'auth' => \App\Http\Middleware\Authenticate::class,
               'role' => \App\Http\Middleware\RoleMiddleware::class,
               'rate_limit' => \App\Http\Middleware\RateLimitMiddleware::class,
               'auth_rate_limit' => \App\Http\Middleware\AuthRateLimitMiddleware::class,
               'cache_response' => \App\Http\Middleware\CacheResponseMiddleware::class,
               'advanced_cache' => \App\Http\Middleware\AdvancedCacheMiddleware::class,
               'advanced_rate_limit' => \App\Http\Middleware\AdvancedRateLimitMiddleware::class,
               'sql_injection_protection' => \App\Http\Middleware\SqlInjectionProtectionMiddleware::class,
               'xss_protection' => \App\Http\Middleware\XssProtectionMiddleware::class,
           ]);
       })
    ->withExceptions(function (Exceptions $exceptions): void {
        //
    })->create();
