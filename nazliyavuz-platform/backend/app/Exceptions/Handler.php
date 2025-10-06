<?php

namespace App\Exceptions;

use Illuminate\Foundation\Exceptions\Handler as ExceptionHandler;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Http\Exceptions\ThrottleRequestsException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Symfony\Component\HttpKernel\Exception\MethodNotAllowedHttpException;
use Symfony\Component\HttpKernel\Exception\HttpException;
use Tymon\JWTAuth\Exceptions\JWTException;
use Tymon\JWTAuth\Exceptions\TokenExpiredException;
use Tymon\JWTAuth\Exceptions\TokenInvalidException;
use Tymon\JWTAuth\Exceptions\TokenBlacklistedException;
use Throwable;
use Illuminate\Http\Response;

class Handler extends ExceptionHandler
{
    /**
     * A list of exception types with their corresponding custom log levels.
     *
     * @var array<class-string<\Throwable>, \Psr\Log\LogLevel::*>
     */
    protected $levels = [
        //
    ];

    /**
     * A list of the exception types that are not reported.
     *
     * @var array<int, class-string<\Throwable>>
     */
    protected $dontReport = [
        //
    ];

    /**
     * A list of the inputs that are never flashed to the session on validation exceptions.
     *
     * @var array<int, string>
     */
    protected $dontFlash = [
        'current_password',
        'password',
        'password_confirmation',
    ];

    /**
     * Register the exception handling callbacks for the application.
     */
    public function register(): void
    {
        $this->reportable(function (Throwable $e) {
            //
        });
    }

    /**
     * Render an exception into an HTTP response.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Throwable  $exception
     * @return \Symfony\Component\HttpFoundation\Response
     *
     * @throws \Throwable
     */
    public function render($request, Throwable $exception)
    {
        // Handle API requests with JSON responses
        if ($request->expectsJson() || $request->is('api/*')) {
            return $this->handleApiException($request, $exception);
        }

        return parent::render($request, $exception);
    }

    /**
     * Handle API exceptions with standardized JSON responses
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Throwable  $exception
     * @return \Illuminate\Http\JsonResponse
     */
    private function handleApiException(Request $request, Throwable $exception): JsonResponse
    {
        $statusCode = $this->getStatusCode($exception);
        $message = $this->getMessage($exception);
        $code = $this->getErrorCode($exception);

        // Log the exception for debugging
        if ($statusCode >= 500) {
            \Log::error('API Exception', [
                'exception' => get_class($exception),
                'message' => $exception->getMessage(),
                'file' => $exception->getFile(),
                'line' => $exception->getLine(),
                'trace' => $exception->getTraceAsString(),
                'request' => [
                    'url' => $request->fullUrl(),
                    'method' => $request->method(),
                    'ip' => $request->ip(),
                    'user_agent' => $request->userAgent(),
                ]
            ]);
        }

        return response()->json([
            'error' => true,
            'code' => $code,
            'message' => $message,
            'timestamp' => now()->toISOString(),
            'path' => $request->path(),
        ], $statusCode);
    }

    /**
     * Get HTTP status code for exception
     *
     * @param  \Throwable  $exception
     * @return int
     */
    private function getStatusCode(Throwable $exception): int
    {
        if ($exception instanceof ValidationException) {
            return 422;
        }

        if ($exception instanceof AuthenticationException) {
            return 401;
        }

        if ($exception instanceof AuthorizationException) {
            return 403;
        }

        if ($exception instanceof ModelNotFoundException) {
            return 404;
        }

        if ($exception instanceof NotFoundHttpException) {
            return 404;
        }

        if ($exception instanceof MethodNotAllowedHttpException) {
            return 405;
        }

        if ($exception instanceof ThrottleRequestsException) {
            return 429;
        }

        if ($exception instanceof TokenExpiredException) {
            return 401;
        }

        if ($exception instanceof TokenInvalidException) {
            return 401;
        }

        if ($exception instanceof TokenBlacklistedException) {
            return 401;
        }

        if ($exception instanceof JWTException) {
            return 401;
        }

        if ($exception instanceof HttpException) {
            return $exception->getStatusCode();
        }

        return 500;
    }

    /**
     * Get user-friendly error message
     *
     * @param  \Throwable  $exception
     * @return string
     */
    private function getMessage(Throwable $exception): string
    {
        if ($exception instanceof ValidationException) {
            return 'Girilen veriler geçersiz. Lütfen kontrol edin.';
        }

        if ($exception instanceof AuthenticationException) {
            return 'Kimlik doğrulama gerekli.';
        }

        if ($exception instanceof AuthorizationException) {
            return 'Bu işlem için yetkiniz bulunmuyor.';
        }

        if ($exception instanceof ModelNotFoundException) {
            return 'Aranan kayıt bulunamadı.';
        }

        if ($exception instanceof NotFoundHttpException) {
            return 'İstenen sayfa bulunamadı.';
        }

        if ($exception instanceof MethodNotAllowedHttpException) {
            return 'Bu HTTP metodu bu endpoint için desteklenmiyor.';
        }

        if ($exception instanceof ThrottleRequestsException) {
            return 'Çok fazla istek gönderildi. Lütfen daha sonra tekrar deneyin.';
        }

        if ($exception instanceof TokenExpiredException) {
            return 'Oturum süresi dolmuş. Lütfen tekrar giriş yapın.';
        }

        if ($exception instanceof TokenInvalidException) {
            return 'Geçersiz oturum bilgisi.';
        }

        if ($exception instanceof TokenBlacklistedException) {
            return 'Oturum geçersiz kılınmış.';
        }

        if ($exception instanceof JWTException) {
            return 'Oturum hatası. Lütfen tekrar giriş yapın.';
        }

        if ($exception instanceof HttpException) {
            return $exception->getMessage() ?: 'HTTP hatası oluştu.';
        }

        // For production, return generic message
        if (config('app.env') === 'production') {
            return 'Bir hata oluştu. Lütfen daha sonra tekrar deneyin.';
        }

        return $exception->getMessage() ?: 'Bilinmeyen hata oluştu.';
    }

    /**
     * Get error code for exception
     *
     * @param  \Throwable  $exception
     * @return string
     */
    private function getErrorCode(Throwable $exception): string
    {
        if ($exception instanceof ValidationException) {
            return 'VALIDATION_ERROR';
        }

        if ($exception instanceof AuthenticationException) {
            return 'AUTHENTICATION_REQUIRED';
        }

        if ($exception instanceof AuthorizationException) {
            return 'AUTHORIZATION_DENIED';
        }

        if ($exception instanceof ModelNotFoundException) {
            return 'MODEL_NOT_FOUND';
        }

        if ($exception instanceof NotFoundHttpException) {
            return 'ENDPOINT_NOT_FOUND';
        }

        if ($exception instanceof MethodNotAllowedHttpException) {
            return 'METHOD_NOT_ALLOWED';
        }

        if ($exception instanceof ThrottleRequestsException) {
            return 'RATE_LIMIT_EXCEEDED';
        }

        if ($exception instanceof TokenExpiredException) {
            return 'TOKEN_EXPIRED';
        }

        if ($exception instanceof TokenInvalidException) {
            return 'TOKEN_INVALID';
        }

        if ($exception instanceof TokenBlacklistedException) {
            return 'TOKEN_BLACKLISTED';
        }

        if ($exception instanceof JWTException) {
            return 'JWT_ERROR';
        }

        if ($exception instanceof HttpException) {
            return 'HTTP_ERROR_' . $exception->getStatusCode();
        }

        return 'INTERNAL_SERVER_ERROR';
    }

    /**
     * Convert a validation exception into a JSON response.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Illuminate\Validation\ValidationException  $exception
     * @return \Illuminate\Http\JsonResponse
     */
    protected function invalidJson($request, ValidationException $exception)
    {
        return response()->json([
            'error' => true,
            'code' => 'VALIDATION_ERROR',
            'message' => 'Girilen veriler geçersiz. Lütfen kontrol edin.',
            'errors' => $exception->errors(),
            'timestamp' => now()->toISOString(),
            'path' => $request->path(),
        ], $exception->status);
    }

    /**
     * Convert an authentication exception into a response.
     */
    protected function unauthenticated($request, AuthenticationException $exception)
    {
        return response()->json([
            'error' => true,
            'code' => 'UNAUTHENTICATED',
            'message' => 'Bu işlem için giriş yapmanız gerekiyor.',
            'timestamp' => now()->toISOString(),
            'path' => $request->path(),
        ], 401);
    }
}
