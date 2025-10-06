<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use App\Models\User;
use App\Models\SocialAccount;
use Tymon\JWTAuth\Facades\JWTAuth;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Log;

/**
 * @OA\Tag(
 *     name="Social Auth",
 *     description="Sosyal medya giriş işlemleri"
 * )
 */
class SocialAuthController extends Controller
{
    /**
     * @OA\Post(
     *     path="/auth/social/google",
     *     tags={"Social Auth"},
     *     summary="Google ile giriş",
     *     description="Google OAuth token ile giriş yapar",
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"access_token"},
     *             @OA\Property(property="access_token", type="string", example="ya29.a0AfH6SMC..."),
     *             @OA\Property(property="id_token", type="string", example="eyJhbGciOiJSUzI1NiIs...")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Giriş başarılı",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string", example="Giriş başarılı"),
     *             @OA\Property(property="user", type="object"),
     *             @OA\Property(property="token", type="string"),
     *             @OA\Property(property="is_new_user", type="boolean")
     *         )
     *     )
     * )
     */
    public function googleAuth(Request $request): JsonResponse
    {
        $request->validate([
            'access_token' => 'required|string',
            'id_token' => 'sometimes|string',
        ]);

        try {
            $googleUser = $this->getGoogleUserInfo($request->access_token);
            
            if (!$googleUser) {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_TOKEN',
                        'message' => 'Geçersiz Google token'
                    ]
                ], 400);
            }

            $user = $this->findOrCreateUser($googleUser, 'google');
            $token = JWTAuth::fromUser($user);

            // Log successful login
            Log::info('Google login successful', [
                'user_id' => $user->id,
                'email' => $user->email,
                'is_new_user' => $user->wasRecentlyCreated
            ]);

            return response()->json([
                'message' => 'Google ile giriş başarılı',
                'user' => $user,
                'token' => $token,
                'is_new_user' => $user->wasRecentlyCreated
            ]);

        } catch (\Exception $e) {
            Log::error('Google login failed', [
                'error' => $e->getMessage(),
                'ip' => $request->ip()
            ]);

            return response()->json([
                'error' => [
                    'code' => 'SOCIAL_AUTH_FAILED',
                    'message' => 'Google girişi başarısız: ' . $e->getMessage()
                ]
            ], 400);
        }
    }

    /**
     * @OA\Post(
     *     path="/auth/social/facebook",
     *     tags={"Social Auth"},
     *     summary="Facebook ile giriş",
     *     description="Facebook OAuth token ile giriş yapar",
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"access_token"},
     *             @OA\Property(property="access_token", type="string", example="EAABwzLixnjYBO...")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Giriş başarılı",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string", example="Giriş başarılı"),
     *             @OA\Property(property="user", type="object"),
     *             @OA\Property(property="token", type="string"),
     *             @OA\Property(property="is_new_user", type="boolean")
     *         )
     *     )
     * )
     */
    public function facebookAuth(Request $request): JsonResponse
    {
        $request->validate([
            'access_token' => 'required|string',
        ]);

        try {
            $facebookUser = $this->getFacebookUserInfo($request->access_token);
            
            if (!$facebookUser) {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_TOKEN',
                        'message' => 'Geçersiz Facebook token'
                    ]
                ], 400);
            }

            $user = $this->findOrCreateUser($facebookUser, 'facebook');
            $token = JWTAuth::fromUser($user);

            Log::info('Facebook login successful', [
                'user_id' => $user->id,
                'email' => $user->email,
                'is_new_user' => $user->wasRecentlyCreated
            ]);

            return response()->json([
                'message' => 'Facebook ile giriş başarılı',
                'user' => $user,
                'token' => $token,
                'is_new_user' => $user->wasRecentlyCreated
            ]);

        } catch (\Exception $e) {
            Log::error('Facebook login failed', [
                'error' => $e->getMessage(),
                'ip' => $request->ip()
            ]);

            return response()->json([
                'error' => [
                    'code' => 'SOCIAL_AUTH_FAILED',
                    'message' => 'Facebook girişi başarısız: ' . $e->getMessage()
                ]
            ], 400);
        }
    }

    /**
     * @OA\Post(
     *     path="/auth/social/apple",
     *     tags={"Social Auth"},
     *     summary="Apple ile giriş",
     *     description="Apple OAuth token ile giriş yapar",
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"identity_token"},
     *             @OA\Property(property="identity_token", type="string", example="eyJhbGciOiJSUzI1NiIs..."),
     *             @OA\Property(property="authorization_code", type="string", example="c1234567890abcdef...")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Giriş başarılı",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string", example="Giriş başarılı"),
     *             @OA\Property(property="user", type="object"),
     *             @OA\Property(property="token", type="string"),
     *             @OA\Property(property="is_new_user", type="boolean")
     *         )
     *     )
     * )
     */
    public function appleAuth(Request $request): JsonResponse
    {
        $request->validate([
            'identity_token' => 'required|string',
            'authorization_code' => 'sometimes|string',
        ]);

        try {
            $appleUser = $this->getAppleUserInfo($request->identity_token);
            
            if (!$appleUser) {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_TOKEN',
                        'message' => 'Geçersiz Apple token'
                    ]
                ], 400);
            }

            $user = $this->findOrCreateUser($appleUser, 'apple');
            $token = JWTAuth::fromUser($user);

            Log::info('Apple login successful', [
                'user_id' => $user->id,
                'email' => $user->email,
                'is_new_user' => $user->wasRecentlyCreated
            ]);

            return response()->json([
                'message' => 'Apple ile giriş başarılı',
                'user' => $user,
                'token' => $token,
                'is_new_user' => $user->wasRecentlyCreated
            ]);

        } catch (\Exception $e) {
            Log::error('Apple login failed', [
                'error' => $e->getMessage(),
                'ip' => $request->ip()
            ]);

            return response()->json([
                'error' => [
                    'code' => 'SOCIAL_AUTH_FAILED',
                    'message' => 'Apple girişi başarısız: ' . $e->getMessage()
                ]
            ], 400);
        }
    }

    /**
     * Get Google user info from access token
     */
    private function getGoogleUserInfo(string $accessToken): ?array
    {
        try {
            $response = Http::withHeaders([
                'Authorization' => 'Bearer ' . $accessToken
            ])->get('https://www.googleapis.com/oauth2/v2/userinfo');

            if ($response->successful()) {
                $data = $response->json();
                return [
                    'id' => $data['id'],
                    'name' => $data['name'],
                    'email' => $data['email'],
                    'avatar' => $data['picture'] ?? null,
                    'verified' => $data['verified_email'] ?? false,
                ];
            }
        } catch (\Exception $e) {
            Log::error('Google API error', ['error' => $e->getMessage()]);
        }

        return null;
    }

    /**
     * Get Facebook user info from access token
     */
    private function getFacebookUserInfo(string $accessToken): ?array
    {
        try {
            $response = Http::get('https://graph.facebook.com/me', [
                'access_token' => $accessToken,
                'fields' => 'id,name,email,picture'
            ]);

            if ($response->successful()) {
                $data = $response->json();
                return [
                    'id' => $data['id'],
                    'name' => $data['name'],
                    'email' => $data['email'] ?? null,
                    'avatar' => $data['picture']['data']['url'] ?? null,
                    'verified' => true,
                ];
            }
        } catch (\Exception $e) {
            Log::error('Facebook API error', ['error' => $e->getMessage()]);
        }

        return null;
    }

    /**
     * Get Apple user info from identity token
     */
    private function getAppleUserInfo(string $identityToken): ?array
    {
        try {
            // Decode JWT token (simplified - in production, verify signature)
            $parts = explode('.', $identityToken);
            if (count($parts) !== 3) {
                return null;
            }

            $payload = json_decode(base64_decode($parts[1]), true);
            
            return [
                'id' => $payload['sub'],
                'name' => $payload['name'] ?? 'Apple User',
                'email' => $payload['email'] ?? null,
                'avatar' => null,
                'verified' => true,
            ];
        } catch (\Exception $e) {
            Log::error('Apple token decode error', ['error' => $e->getMessage()]);
        }

        return null;
    }

    /**
     * Find or create user from social account
     */
    private function findOrCreateUser(array $socialUser, string $provider): User
    {
        // First, try to find by email
        $user = User::where('email', $socialUser['email'])->first();

        if (!$user) {
            // Create new user
            $user = User::create([
                'name' => $socialUser['name'],
                'email' => $socialUser['email'],
                'password' => Hash::make(Str::random(32)),
                'role' => 'student',
                'email_verified_at' => $socialUser['verified'] ? now() : null,
                'profile_photo_url' => $socialUser['avatar'],
                'verified_at' => now(), // Auto-verify social users
            ]);
        }

        // Update or create social account
        SocialAccount::updateOrCreate(
            [
                'user_id' => $user->id,
                'provider' => $provider,
            ],
            [
                'provider_id' => $socialUser['id'],
                'provider_data' => $socialUser,
            ]
        );

        // Update profile photo if not set
        if (!$user->profile_photo_url && $socialUser['avatar']) {
            $user->update(['profile_photo_url' => $socialUser['avatar']]);
        }

        return $user;
    }

    /**
     * @OA\Get(
     *     path="/auth/social/accounts",
     *     tags={"Social Auth"},
     *     summary="Kullanıcının sosyal hesapları",
     *     description="Kullanıcının bağlı sosyal medya hesaplarını listeler",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="Sosyal hesaplar başarıyla getirildi",
     *         @OA\JsonContent(
     *             @OA\Property(property="success", type="boolean", example=true),
     *             @OA\Property(property="data", type="array", @OA\Items(type="object"))
     *         )
     *     )
     * )
     */
    public function getSocialAccounts(Request $request): JsonResponse
    {
        $user = $request->user();
        
        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Authentication required'
            ], 401);
        }

        $socialAccounts = $user->socialAccounts()->select([
            'id', 'provider', 'provider_id', 'created_at'
        ])->get();

        return response()->json([
            'success' => true,
            'data' => $socialAccounts
        ]);
    }

    /**
     * @OA\Delete(
     *     path="/auth/social/accounts/{provider}",
     *     tags={"Social Auth"},
     *     summary="Sosyal hesap bağlantısını kes",
     *     description="Belirtilen sosyal medya hesabının bağlantısını keser",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="provider",
     *         in="path",
     *         required=true,
     *         description="Sosyal medya sağlayıcısı",
     *         @OA\Schema(type="string", enum={"google","facebook","apple","twitter","linkedin"})
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Sosyal hesap bağlantısı kesildi",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string", example="Sosyal medya hesabı başarıyla bağlantısı kesildi")
     *         )
     *     )
     * )
     */
    public function disconnectSocialAccount(Request $request, string $provider): JsonResponse
    {
        $user = $request->user();
        
        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Authentication required'
            ], 401);
        }

        $socialAccount = SocialAccount::where('user_id', $user->id)
            ->where('provider', $provider)
            ->first();

        if (!$socialAccount) {
            return response()->json([
                'error' => [
                    'code' => 'NOT_FOUND',
                    'message' => 'Sosyal medya hesabı bulunamadı'
                ]
            ], 404);
        }

        // Check if user has password (can't disconnect if no other auth method)
        if (!$user->password || Hash::check(Str::random(32), $user->password)) {
            return response()->json([
                'error' => [
                    'code' => 'CANNOT_DISCONNECT',
                    'message' => 'Şifre belirlemeden sosyal hesap bağlantısını kesemezsiniz'
                ]
            ], 400);
        }

        $socialAccount->delete();

        Log::info('Social account disconnected', [
            'user_id' => $user->id,
            'provider' => $provider
        ]);

        return response()->json([
            'message' => 'Sosyal medya hesabı başarıyla bağlantısı kesildi'
        ]);
    }

    /**
     * @OA\Post(
     *     path="/auth/social/link",
     *     tags={"Social Auth"},
     *     summary="Mevcut hesaba sosyal hesap bağla",
     *     description="Mevcut kullanıcı hesabına sosyal medya hesabı bağlar",
     *     security={{"bearerAuth":{}}},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"provider","access_token"},
     *             @OA\Property(property="provider", type="string", enum={"google","facebook","apple"}, example="google"),
     *             @OA\Property(property="access_token", type="string", example="ya29.a0AfH6SMC...")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Sosyal hesap başarıyla bağlandı",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string", example="Sosyal hesap başarıyla bağlandı")
     *         )
     *     )
     * )
     */
    public function linkSocialAccount(Request $request): JsonResponse
    {
        $user = $request->user();
        
        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Authentication required'
            ], 401);
        }

        $request->validate([
            'provider' => 'required|in:google,facebook,apple',
            'access_token' => 'required|string',
        ]);

        try {
            $provider = $request->provider;
            $accessToken = $request->access_token;

            // Get user info based on provider
            $socialUser = match($provider) {
                'google' => $this->getGoogleUserInfo($accessToken),
                'facebook' => $this->getFacebookUserInfo($accessToken),
                'apple' => $this->getAppleUserInfo($accessToken),
                default => null,
            };

            if (!$socialUser) {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_TOKEN',
                        'message' => 'Geçersiz token'
                    ]
                ], 400);
            }

            // Check if social account already exists
            $existingAccount = SocialAccount::where('provider', $provider)
                ->where('provider_id', $socialUser['id'])
                ->first();

            if ($existingAccount && $existingAccount->user_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'ACCOUNT_ALREADY_LINKED',
                        'message' => 'Bu sosyal hesap başka bir kullanıcıya bağlı'
                    ]
                ], 400);
            }

            // Link the account
            SocialAccount::updateOrCreate(
                [
                    'user_id' => $user->id,
                    'provider' => $provider,
                ],
                [
                    'provider_id' => $socialUser['id'],
                    'provider_data' => $socialUser,
                ]
            );

            Log::info('Social account linked', [
                'user_id' => $user->id,
                'provider' => $provider,
                'provider_id' => $socialUser['id']
            ]);

            return response()->json([
                'message' => 'Sosyal hesap başarıyla bağlandı'
            ]);

        } catch (\Exception $e) {
            Log::error('Social account linking failed', [
                'error' => $e->getMessage(),
                'user_id' => $user->id,
                'provider' => $request->provider
            ]);

            return response()->json([
                'error' => [
                    'code' => 'LINKING_FAILED',
                    'message' => 'Sosyal hesap bağlama başarısız: ' . $e->getMessage()
                ]
            ], 400);
        }
    }

    /**
     * @OA\Get(
     *     path="/auth/social/providers",
     *     tags={"Social Auth"},
     *     summary="Desteklenen sosyal medya sağlayıcıları",
     *     description="Sistemde desteklenen sosyal medya giriş sağlayıcılarını listeler",
     *     @OA\Response(
     *         response=200,
     *         description="Sağlayıcılar başarıyla getirildi",
     *         @OA\JsonContent(
     *             @OA\Property(property="success", type="boolean", example=true),
     *             @OA\Property(property="data", type="array", @OA\Items(type="object"))
     *         )
     *     )
     * )
     */
    public function getSupportedProviders(): JsonResponse
    {
        $providers = [
            [
                'id' => 'google',
                'name' => 'Google',
                'icon' => 'google',
                'color' => '#4285F4',
                'enabled' => true,
            ],
            [
                'id' => 'facebook',
                'name' => 'Facebook',
                'icon' => 'facebook',
                'color' => '#1877F2',
                'enabled' => true,
            ],
            [
                'id' => 'apple',
                'name' => 'Apple',
                'icon' => 'apple',
                'color' => '#000000',
                'enabled' => true,
            ],
        ];

        return response()->json([
            'success' => true,
            'data' => $providers
        ]);
    }
}
