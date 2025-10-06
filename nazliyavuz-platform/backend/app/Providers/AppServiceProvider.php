<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // Register CacheService
        $this->app->singleton(\App\Services\CacheService::class, function ($app) {
            return new \App\Services\CacheService();
        });
        
        // Register MailService
        $this->app->singleton(\App\Services\MailService::class, function ($app) {
            return new \App\Services\MailService();
        });
        
        // Register PushNotificationService
        $this->app->singleton(\App\Services\PushNotificationService::class, function ($app) {
            return new \App\Services\PushNotificationService();
        });
        
        // Register RealTimeChatService
        $this->app->singleton(\App\Services\RealTimeChatService::class, function ($app) {
            return new \App\Services\RealTimeChatService();
        });
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        //
    }
}
