<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\HealthCheckController;

Route::get('/', function () {
    return view('welcome');
});

// Health Check Endpoints
Route::get('/health', [HealthCheckController::class, 'basic']);
Route::get('/health/detailed', [HealthCheckController::class, 'detailed']);

// Swagger UI
Route::get('/api/documentation', function () {
    return view('l5-swagger::index');
});
