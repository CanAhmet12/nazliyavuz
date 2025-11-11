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
            Log::info('Google authentication started', [
                'access_token_length' => strlen($request->access_token),
                'has_id_token' => !empty($request->id_token),
                'ip' => $request->ip()
            ]);

            // Try ID token first if available
            $googleUser = null;
            if (!empty($request->id_token)) {
                $googleUser = $this->getGoogleUserFromIdToken($request->id_token);
                Log::info('Tried ID token method', ['success' => $googleUser !== null]);
            }
            
            // Fallback to access token
            if (!$googleUser) {
                $googleUser = $this->getGoogleUserInfo($request->access_token);
                Log::info('Tried access token method', ['success' => $googleUser !== null]);
            }
            
            if (!$googleUser) {
                Log::error('Google user info retrieval failed', [
                    'access_token_length' => strlen($request->access_token),
                    'ip' => $request->ip()
                ]);
                
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_TOKEN',
                        'message' => 'Google token geçersiz veya süresi dolmuş. Lütfen tekrar deneyin.'
                    ]
                ], 400);
            }

            Log::info('Google user info retrieved successfully', [
                'user_id' => $googleUser['id'],
                'email' => $googleUser['email'],
                'name' => $googleUser['name']
            ]);

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
                'is_new_user' => $user->wasRecentlyCreated,
                'requires_email_verification' => $user->email_verified_at === null,
                'requires_role_selection' => $user->wasRecentlyCreated // New users need to select role
            ]);

        } catch (\Exception $e) {
            Log::error('Google login failed', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
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
     * Get Google user info from ID token (JWT)
     */
    private function getGoogleUserFromIdToken(string $idToken): ?array
    {
        try {
            Log::info('Decoding Google ID token', [
                'token_length' => strlen($idToken),
                'token_start' => substr($idToken, 0, 50) . '...'
            ]);

            // Decode JWT without verification (for development)
            $parts = explode('.', $idToken);
            if (count($parts) !== 3) {
                Log::error('Invalid JWT format');
                return null;
            }

            $payload = json_decode(base64_decode(str_pad(strtr($parts[1], '-_', '+/'), strlen($parts[1]) % 4, '=', STR_PAD_RIGHT)), true);
            
            if (!$payload) {
                Log::error('Failed to decode JWT payload');
                return null;
            }

            Log::info('ID token payload decoded', [
                'keys' => array_keys($payload),
                'sub' => $payload['sub'] ?? 'missing',
                'email' => $payload['email'] ?? 'missing',
                'name' => $payload['name'] ?? 'missing'
            ]);

            if (!isset($payload['sub']) || !isset($payload['email'])) {
                Log::error('ID token missing required fields', ['payload' => $payload]);
                return null;
            }

            $userInfo = [
                'id' => $payload['sub'],
                'name' => $payload['name'] ?? 'Google User',
                'email' => $payload['email'],
                'avatar' => $payload['picture'] ?? null,
                'verified' => $payload['email_verified'] ?? false,
            ];

            Log::info('Google user info extracted from ID token', [
                'id' => $userInfo['id'],
                'email' => $userInfo['email'],
                'name' => $userInfo['name']
            ]);

            return $userInfo;

        } catch (\Exception $e) {
            Log::error('ID token decode error', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);
            return null;
        }
    }

    /**
     * Get Google user info from access token
     */
    private function getGoogleUserInfo(string $accessToken): ?array
    {
        try {
            Log::info('Google API request started', [
                'token_length' => strlen($accessToken),
                'token_prefix' => substr($accessToken, 0, 20) . '...'
            ]);

            // Try Google People API first (most current)
            $response = Http::withHeaders([
                'Authorization' => 'Bearer ' . $accessToken
            ])->get('https://people.googleapis.com/v1/people/me?personFields=names,emailAddresses,photos');
            
            Log::info('Google People API response', [
                'status' => $response->status(),
                'successful' => $response->successful(),
                'body' => $response->body()
            ]);
            
            if ($response->successful()) {
                $data = $response->json();
                
                Log::info('Google People API successful response', [
                    'data_keys' => array_keys($data),
                    'full_data' => $data
                ]);
                
                // Extract user info from People API format
                if (isset($data['emailAddresses']) && isset($data['names'])) {
                    $email = $data['emailAddresses'][0]['value'] ?? null;
                    $name = $data['names'][0]['displayName'] ?? 'Google User';
                    $photo = $data['photos'][0]['url'] ?? null;
                    $resourceName = $data['resourceName'] ?? null;
                    $id = str_replace('people/', '', $resourceName ?? '');
                    
                    if ($email && $id) {
                        $userInfo = [
                            'id' => $id,
                            'name' => $name,
                            'email' => $email,
                            'avatar' => $photo,
                            'verified' => true,
                        ];
                        
                        Log::info('Google People API user info extracted', [
                            'id' => $userInfo['id'],
                            'email' => $userInfo['email'],
                            'name' => $userInfo['name']
                        ]);
                        
                        return $userInfo;
                    }
                }
            }
            
            // Fallback to OAuth2 v2 API
            $response = Http::withHeaders([
                'Authorization' => 'Bearer ' . $accessToken
            ])->get('https://www.googleapis.com/oauth2/v2/userinfo');

            Log::info('Google API response', [
                'status' => $response->status(),
                'successful' => $response->successful(),
                'body' => $response->body()
            ]);

            if ($response->successful()) {
                $data = $response->json();
                
                Log::info('Google API v2 successful response', [
                    'data_keys' => array_keys($data),
                    'has_id' => isset($data['id']),
                    'has_email' => isset($data['email']),
                    'full_data' => $data
                ]);
                
                // Validate required fields
                if (!isset($data['id']) || !isset($data['email'])) {
                    Log::error('Google API response missing required fields', ['data' => $data]);
                    return null;
                }

                $userInfo = [
                    'id' => $data['id'],
                    'name' => $data['name'] ?? 'Google User',
                    'email' => $data['email'],
                    'avatar' => $data['picture'] ?? null,
                    'verified' => $data['verified_email'] ?? false,
                ];

                Log::info('Google user info extracted', [
                    'id' => $userInfo['id'],
                    'email' => $userInfo['email'],
                    'name' => $userInfo['name']
                ]);

                return $userInfo;
            } else {
                Log::error('Google API v2 failed', [
                    'status' => $response->status(),
                    'body' => $response->body(),
                    'headers' => $response->headers()
                ]);
                
                // If v2 fails, try v1 endpoint
                Log::info('Trying Google API v1 endpoint');
                $response = Http::withHeaders([
                    'Authorization' => 'Bearer ' . $accessToken
                ])->get('https://www.googleapis.com/oauth2/v1/userinfo');

                Log::info('Google API v1 response', [
                    'status' => $response->status(),
                    'successful' => $response->successful(),
                    'body' => $response->body()
                ]);

                if ($response->successful()) {
                    $data = $response->json();
                    
                    if (!isset($data['id']) || !isset($data['email'])) {
                        Log::error('Google API v1 response missing required fields', ['data' => $data]);
                        return null;
                    }

                    $userInfo = [
                        'id' => $data['id'],
                        'name' => $data['name'] ?? 'Google User',
                        'email' => $data['email'],
                        'avatar' => $data['picture'] ?? null,
                        'verified' => $data['verified_email'] ?? false,
                    ];

                    Log::info('Google user info extracted from v1', [
                        'id' => $userInfo['id'],
                        'email' => $userInfo['email'],
                        'name' => $userInfo['name']
                    ]);

                    return $userInfo;
                }
            }
        } catch (\Exception $e) {
            Log::error('Google API error', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);
        }

        Log::error('Google API failed to get user info');
        return null;
    }

    /**
     * Test Google API endpoint
     */
    public function testGoogleApi(Request $request): JsonResponse
    {
        $request->validate([
            'access_token' => 'required|string',
        ]);

        $accessToken = $request->access_token;
        
        Log::info('Testing Google API with token', [
            'token_length' => strlen($accessToken),
            'token_start' => substr($accessToken, 0, 20) . '...'
        ]);

        // Test all endpoints
        $results = [];
        
        // Test People API
        try {
            $response = Http::withHeaders([
                'Authorization' => 'Bearer ' . $accessToken
            ])->get('https://people.googleapis.com/v1/people/me?personFields=names,emailAddresses,photos');
            
            $results['people_api'] = [
                'status' => $response->status(),
                'successful' => $response->successful(),
                'body' => $response->body(),
                'json' => $response->json()
            ];
        } catch (\Exception $e) {
            $results['people_api'] = ['error' => $e->getMessage()];
        }

        // Test OAuth2 v2
        try {
            $response = Http::withHeaders([
                'Authorization' => 'Bearer ' . $accessToken
            ])->get('https://www.googleapis.com/oauth2/v2/userinfo');
            
            $results['oauth2_v2'] = [
                'status' => $response->status(),
                'successful' => $response->successful(),
                'body' => $response->body(),
                'json' => $response->json()
            ];
        } catch (\Exception $e) {
            $results['oauth2_v2'] = ['error' => $e->getMessage()];
        }

        return response()->json([
            'message' => 'Google API test completed',
            'results' => $results
        ]);
    }

    /**
     * Set user role after social registration
     */
    public function setUserRole(Request $request): JsonResponse
    {
        $request->validate([
            'role' => 'required|in:student,teacher',
        ]);

        try {
            $user = auth()->user();
            
            if (!$user) {
                return response()->json([
                    'error' => [
                        'code' => 'UNAUTHORIZED',
                        'message' => 'Kullanıcı girişi gerekli'
                    ]
                ], 401);
            }

            // Only allow role change for new users or users without verified email
            if ($user->email_verified_at !== null && $user->created_at->diffInMinutes(now()) > 30) {
                return response()->json([
                    'error' => [
                        'code' => 'ROLE_CHANGE_NOT_ALLOWED',
                        'message' => 'Rol değişikliği artık yapılamaz'
                    ]
                ], 400);
            }

            $user->update(['role' => $request->role]);

            Log::info('User role updated', [
                'user_id' => $user->id,
                'new_role' => $request->role,
                'email' => $user->email
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Rol başarıyla güncellendi',
                'user' => $user->fresh(),
                'next_step' => $request->role === 'teacher' ? 'complete_teacher_profile' : 'verify_email'
            ]);

        } catch (\Exception $e) {
            Log::error('Role update failed', [
                'error' => $e->getMessage(),
                'user_id' => auth()->id()
            ]);

            return response()->json([
                'error' => [
                    'code' => 'ROLE_UPDATE_FAILED',
                    'message' => 'Rol güncellenirken hata oluştu'
                ]
            ], 500);
        }
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
                'role' => 'student', // Default role, can be changed later
                'email_verified_at' => null, // Require email verification even for social users
                'profile_photo_url' => $socialUser['avatar'],
                'verified_at' => null, // Don't auto-verify, require email verification
            ]);
            
            Log::info('New social user created', [
                'user_id' => $user->id,
                'email' => $user->email,
                'provider' => $provider,
                'requires_verification' => true
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
