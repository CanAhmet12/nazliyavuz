<?php

namespace App\Http\Controllers;

use App\Services\MailService;
use App\Models\EmailVerification;
use App\Models\User;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Tymon\JWTAuth\Facades\JWTAuth;
use Tymon\JWTAuth\Exceptions\JWTException;
use Carbon\Carbon;

class AuthController extends Controller
{
    protected MailService $mailService;

    public function __construct(MailService $mailService)
    {
        $this->mailService = $mailService;
        
        // Rate limiting for auth operations will be handled in routes
    }

    /**
     * Register new user
     */
    public function register(Request $request): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'name' => 'required|string|max:255',
                'email' => 'required|string|email|max:255|unique:users',
                'password' => 'required|string|min:8|confirmed',
                'role' => 'required|in:student,teacher',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => true,
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'Geçersiz veri',
                    'errors' => $validator->errors(),
                    'timestamp' => now()->toISOString(),
                    'path' => $request->path(),
                ], 422);
            }

            $user = User::create([
                'name' => $request->name,
                'email' => $request->email,
                'password' => Hash::make($request->password),
                'role' => $request->role,
            ]);

            // Create email verification
            $verification = EmailVerification::createForUser($user);

            // Send verification email
            try {
                $this->mailService->sendEmailVerification($user, $verification->token, $verification->verification_code);
            } catch (\Exception $e) {
                Log::warning('Failed to send verification email: ' . $e->getMessage());
            }

            // Generate JWT token
            $token = JWTAuth::fromUser($user);

            return response()->json([
                'success' => true,
                'message' => 'Kullanıcı başarıyla oluşturuldu',
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'role' => $user->role,
                    'email_verified_at' => $user->email_verified_at,
                ],
                'token' => [
                    'access_token' => $token,
                    'token_type' => 'bearer',
                    'expires_in' => config('jwt.ttl') * 60,
                ],
                'verification_required' => $user->email_verified_at === null,
            ], 201);

        } catch (\Exception $e) {
            Log::error('Registration error: ' . $e->getMessage());

            return response()->json([
                'error' => true,
                'code' => 'REGISTRATION_ERROR',
                'message' => 'Kayıt sırasında bir hata oluştu',
                'timestamp' => now()->toISOString(),
                'path' => $request->path(),
            ], 500);
        }
    }

    /**
     * User login
     */
    public function login(Request $request): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'email' => 'required|email',
                'password' => 'required|string|min:8',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => true,
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'Geçersiz veri',
                    'errors' => $validator->errors(),
                    'timestamp' => now()->toISOString(),
                    'path' => $request->path(),
                ], 422);
            }

            $credentials = $request->only('email', 'password');

            if (!$token = JWTAuth::attempt($credentials)) {
                return response()->json([
                    'error' => true,
                    'code' => 'INVALID_CREDENTIALS',
                    'message' => 'E-posta veya şifre hatalı',
                    'timestamp' => now()->toISOString(),
                    'path' => $request->path(),
                ], 401);
            }

            $user = Auth::user();

            // Update last login (if column exists)
            try {
                $user->update(['last_login_at' => now()]);
            } catch (\Exception $e) {
                Log::info('last_login_at column not found, skipping update');
            }

            return response()->json([
                'success' => true,
                'message' => 'Giriş başarılı',
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'role' => $user->role,
                    'email_verified_at' => $user->email_verified_at,
                    'profile_photo_url' => $user->profile_photo_url,
                ],
                'token' => [
                    'access_token' => $token,
                    'token_type' => 'bearer',
                    'expires_in' => config('jwt.ttl') * 60,
                ],
                'verification_required' => $user->email_verified_at === null,
            ]);

        } catch (JWTException $e) {
            Log::error('JWT error during login: ' . $e->getMessage());

            return response()->json([
                'error' => true,
                'code' => 'TOKEN_ERROR',
                'message' => 'Token oluşturulamadı',
                'timestamp' => now()->toISOString(),
                'path' => $request->path(),
            ], 500);
        } catch (\Exception $e) {
            Log::error('Login error: ' . $e->getMessage());

            return response()->json([
                'error' => true,
                'code' => 'LOGIN_ERROR',
                'message' => 'Giriş sırasında bir hata oluştu',
                'timestamp' => now()->toISOString(),
                'path' => $request->path(),
            ], 500);
        }
    }

    /**
     * Logout user
     */
    public function logout(): JsonResponse
    {
        try {
            JWTAuth::invalidate(JWTAuth::getToken());

            return response()->json([
                'success' => true,
                'message' => 'Başarıyla çıkış yapıldı'
            ]);

        } catch (JWTException $e) {
            Log::error('Logout error: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'LOGOUT_ERROR',
                    'message' => 'Çıkış sırasında bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Refresh JWT token
     */
    public function refresh(): JsonResponse
    {
        try {
            $token = JWTAuth::refresh(JWTAuth::getToken());

            return response()->json([
                'success' => true,
                'token' => [
                    'access_token' => $token,
                    'token_type' => 'bearer',
                    'expires_in' => config('jwt.ttl') * 60,
                ]
            ]);

        } catch (JWTException $e) {
            Log::error('Token refresh error: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'TOKEN_REFRESH_ERROR',
                    'message' => 'Token yenilenemedi'
                ]
            ], 401);
        }
    }

    /**
     * Verify email with code
     */
    public function verifyEmailCode(Request $request): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'email' => 'required|email',
                'verification_code' => 'required|string|size:6',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => true,
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'Geçersiz veri',
                    'errors' => $validator->errors(),
                    'timestamp' => now()->toISOString(),
                    'path' => $request->path(),
                ], 422);
            }

            $user = User::where('email', $request->email)->first();
            if (!$user) {
                return response()->json([
                    'error' => [
                        'code' => 'USER_NOT_FOUND',
                        'message' => 'Kullanıcı bulunamadı'
                    ]
                ], 404);
            }

            $verification = EmailVerification::where('user_id', $user->id)
                ->where('verification_code', $request->verification_code)
                ->where('expires_at', '>', now())
                ->first();

            if (!$verification) {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_CODE',
                        'message' => 'Geçersiz veya süresi dolmuş doğrulama kodu'
                    ]
                ], 400);
            }

            // Mark user as verified
            $user->update([
                'email_verified_at' => now(),
                'verified_at' => now(),
            ]);

            // Delete verification record
            $verification->delete();

            return response()->json([
                'success' => true,
                'message' => 'E-posta başarıyla doğrulandı'
            ]);

        } catch (\Exception $e) {
            Log::error('Email verification error: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'VERIFICATION_ERROR',
                    'message' => 'E-posta doğrulanırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Resend verification email
     */
    public function resendVerification(Request $request): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'email' => 'required|email|exists:users,email',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Geçersiz e-posta adresi',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $user = User::where('email', $request->email)->first();

            if ($user->email_verified_at) {
                return response()->json([
                    'error' => [
                        'code' => 'ALREADY_VERIFIED',
                        'message' => 'E-posta adresi zaten doğrulanmış'
                    ]
                ], 400);
            }

            // Delete old verification records
            EmailVerification::where('email', $user->email)->delete();

            // Create new verification
            $verification = EmailVerification::createForUser($user);

            // Send verification email
            try {
                $this->mailService->sendEmailVerification($user, $verification->token, $verification->verification_code);
            } catch (\Exception $e) {
                Log::warning('Failed to send verification email: ' . $e->getMessage());
            }

            return response()->json([
                'success' => true,
                'message' => 'Doğrulama e-postası tekrar gönderildi'
            ]);

        } catch (\Exception $e) {
            Log::error('Resend verification error: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'RESEND_ERROR',
                    'message' => 'E-posta gönderilirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Forgot password
     */
    public function forgotPassword(Request $request): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'email' => 'required|email|exists:users,email',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Geçersiz e-posta adresi',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $status = Password::sendResetLink($request->only('email'));

            if ($status === Password::RESET_LINK_SENT) {
                return response()->json([
                    'success' => true,
                    'message' => 'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi'
                ]);
            }

            return response()->json([
                'error' => [
                    'code' => 'RESET_LINK_ERROR',
                    'message' => 'Şifre sıfırlama bağlantısı gönderilemedi'
                ]
            ], 500);

        } catch (\Exception $e) {
            Log::error('Forgot password error: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'FORGOT_PASSWORD_ERROR',
                    'message' => 'Şifre sıfırlama işleminde bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Reset password
     */
    public function resetPassword(Request $request): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'token' => 'required',
                'email' => 'required|email',
                'password' => 'required|string|min:8|confirmed',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => true,
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'Geçersiz veri',
                    'errors' => $validator->errors(),
                    'timestamp' => now()->toISOString(),
                    'path' => $request->path(),
                ], 422);
            }

            $status = Password::reset(
                $request->only('email', 'password', 'password_confirmation', 'token'),
                function (User $user, string $password) {
                    $user->forceFill([
                        'password' => Hash::make($password)
                    ])->setRememberToken(\Str::random(60));

                    $user->save();
                }
            );

            if ($status === Password::PASSWORD_RESET) {
                return response()->json([
                    'success' => true,
                    'message' => 'Şifre başarıyla sıfırlandı'
                ]);
            }

            return response()->json([
                'error' => [
                    'code' => 'RESET_ERROR',
                    'message' => 'Şifre sıfırlanamadı'
                ]
            ], 400);

        } catch (\Exception $e) {
            Log::error('Reset password error: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'PASSWORD_RESET_ERROR',
                    'message' => 'Şifre sıfırlama işleminde bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get mail configuration status
     */
    public function getMailStatus(): JsonResponse
    {
        try {
            $isConfigured = $this->mailService->isMailConfigured();

            return response()->json([
                'success' => true,
                'mail_configured' => $isConfigured,
                'smtp_host' => config('mail.mailers.smtp.host'),
                'smtp_port' => config('mail.mailers.smtp.port'),
                'from_address' => config('mail.from.address'),
            ]);

        } catch (\Exception $e) {
            Log::error('Mail status error: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'MAIL_STATUS_ERROR',
                    'message' => 'Mail durumu kontrol edilemedi'
                ]
            ], 500);
        }
    }
}