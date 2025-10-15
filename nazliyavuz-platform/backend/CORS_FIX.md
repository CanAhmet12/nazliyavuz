# CORS Sorunu Çözümü

## Problem
VM'de backend çalışırken frontend'den gelen istekler 500 Server Error veriyor. CORS paketi eksik.

## Çözüm Adımları

### 1. CORS Paketi Ekle
```bash
cd nazliyavuz-platform/backend
composer require fruitcake/laravel-cors
```

### 2. CORS Middleware Ekle
`bootstrap/app.php` dosyasına ekle:
```php
$middleware->api(prepend: [
    \Fruitcake\Cors\HandleCors::class,
]);
```

### 3. CORS Config Oluştur
```bash
php artisan vendor:publish --tag="cors"
```

### 4. Config Ayarla
`config/cors.php` dosyasında:
```php
return [
    'paths' => ['api/*', 'sanctum/csrf-cookie'],
    'allowed_methods' => ['*'],
    'allowed_origins' => ['*'], // Production'da specific domain'ler
    'allowed_origins_patterns' => [],
    'allowed_headers' => ['*'],
    'exposed_headers' => [],
    'max_age' => 0,
    'supports_credentials' => false,
];
```

### 5. Restart Backend
```bash
php artisan config:clear
php artisan cache:clear
```

## Alternatif Çözüm (Hızlı)
Eğer composer erişimi yoksa, middleware'de manuel CORS header'ları ekle:

```php
// Middleware oluştur
php artisan make:middleware CorsMiddleware

// CorsMiddleware.php içeriği:
public function handle($request, Closure $next)
{
    return $next($request)
        ->header('Access-Control-Allow-Origin', '*')
        ->header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        ->header('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With');
}
```
