import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' hide Category;
import '../models/user.dart';
import '../models/teacher.dart';
import '../models/reservation.dart';
import '../models/rating.dart';
import '../models/category.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/message_thread.dart';
import '../models/message_translation.dart';
import '../models/assignment.dart';
import '../models/lesson.dart';

class ApiService {
  static const String baseUrl = 'http://34.14.61.40/api/v1';  // Production VM
  late Dio _dio;
  String? _token;

  
  // Callback for unauthorized access
  Function()? onUnauthorized;
  final Map<String, dynamic> _cache = {};
  
  // Performance optimization
  Timer? _cacheCleanupTimer;
  final Map<String, DateTime> _cacheTimestamps = {};
  
  // Activity tracking for sliding session
  DateTime? _lastActivity;
  Timer? _activityTimer;
  static const Duration _activityCheckInterval = Duration(minutes: 10); // Check every 10 minutes
  static const Duration _tokenRefreshThreshold = Duration(minutes: 30); // Refresh if less than 30 min left

  ApiService() {
    if (kDebugMode) {
      print('🚀 [API_SERVICE] Initializing ApiService...');
      
      print('🌐 [API_SERVICE] Base URL: $baseUrl');
    }
    
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (kDebugMode) {
          print('📤 [API_REQUEST] ${options.method} ${options.path}');
          print('📤 [API_REQUEST] Headers: ${options.headers}');
          print('📤 [API_REQUEST] Data: ${options.data}');
        }
        
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
          if (kDebugMode) {
            print('🔑 [API_REQUEST] Token added to headers');
          }
        }
        handler.next(options);
      },
      onResponse: (response, handler) async {
        if (kDebugMode) {
          print('📥 [API_RESPONSE] Status: ${response.statusCode}');
          print('📥 [API_RESPONSE] Data: ${response.data}');
        }
        
        // Record activity for successful API calls
        if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
          recordActivity();
        }
        
        handler.next(response);
      },
      onError: (error, handler) async {
        if (kDebugMode) {
          print('❌ [API_ERROR] ${error.requestOptions.path} - ${error.response?.statusCode}: ${error.message}');
        }
        
        if (error.response?.statusCode == 401) {
          // Don't retry refresh for login/profile check requests
          final skipRefreshPaths = [
            '/auth/refresh', 
            '/user', 
            '/auth/me'
          ];
          
          if (skipRefreshPaths.contains(error.requestOptions.path)) {
            if (kDebugMode) {
              print('🔓 [API_ERROR] 401 on ${error.requestOptions.path} - skipping refresh, clearing token');
            }
            await _clearToken();
            _currentUser = null;
            if (onUnauthorized != null) {
              onUnauthorized!();
            }
            handler.next(error);
            return;
          }
          
          if (kDebugMode) {
            print('🔓 [API_ERROR] Unauthorized - attempting token refresh...');
          }
          
          // Try to refresh token first
          try {
            await refreshToken();
            if (kDebugMode) {
              print('✅ [API_ERROR] Token refreshed successfully, retrying request...');
            }
            // Retry the original request
            final response = await _dio.fetch(error.requestOptions);
            handler.resolve(response);
            return;
          } catch (refreshError) {
            if (kDebugMode) {
              print('❌ [API_ERROR] Token refresh failed');
              print('❌ [API_ERROR] Refresh error: $refreshError');
            }
            
            // Only clear token if it's a real authentication failure
            // Don't clear token for network errors or temporary issues
            if (refreshError.toString().contains('401') || 
                refreshError.toString().contains('Unauthorized') ||
                refreshError.toString().contains('Token bulunamadı') ||
                refreshError.toString().contains('Oturum süreniz dolmuş')) {
              if (kDebugMode) {
                print('🔓 [API_ERROR] Real auth failure detected, clearing token');
              }
              await _clearToken();
              _currentUser = null;
              // Notify AuthBloc about unauthorized access
              if (onUnauthorized != null) {
                onUnauthorized!();
              }
            } else {
              if (kDebugMode) {
                print('🔄 [API_ERROR] Network/temporary error, keeping token');
              }
            }
            
            // Don't retry the original request, let it fail
            handler.next(error);
            return;
          }
        }
        handler.next(error);
      },
    ));

    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    await _loadToken();
    if (kDebugMode) {
      print('🔑 [API_SERVICE] Auth initialization complete. Token: ${_token != null ? "EXISTS" : "NULL"}');
    }
    
    // Start activity tracking for sliding session
    _startActivityTracking();
  }

  // Activity tracking methods for sliding session
  void _startActivityTracking() {
    _lastActivity = DateTime.now();
    _activityTimer?.cancel();
    _activityTimer = Timer.periodic(_activityCheckInterval, (timer) {
      _checkAndRefreshTokenIfNeeded();
    });
    
    if (kDebugMode) {
      print('🔄 [ACTIVITY_TRACKING] Started activity tracking');
    }
  }

  void _stopActivityTracking() {
    _activityTimer?.cancel();
    _activityTimer = null;
    _lastActivity = null;
    
    if (kDebugMode) {
      print('⏹️ [ACTIVITY_TRACKING] Stopped activity tracking');
    }
  }

  void recordActivity() {
    _lastActivity = DateTime.now();
    if (kDebugMode) {
      print('📱 [ACTIVITY_TRACKING] Activity recorded at ${_lastActivity}');
    }
  }

  Future<void> _checkAndRefreshTokenIfNeeded() async {
    if (_token == null || _lastActivity == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenExpiry = prefs.getString('token_expiry');
      
      if (tokenExpiry != null) {
        final expiryDate = DateTime.parse(tokenExpiry);
        final now = DateTime.now();
        final timeUntilExpiry = expiryDate.difference(now);
        
        // If token will expire within the threshold, refresh it
        if (timeUntilExpiry < _tokenRefreshThreshold) {
          if (kDebugMode) {
            print('🔄 [ACTIVITY_TRACKING] Token expires in ${timeUntilExpiry.inMinutes} minutes, refreshing...');
          }
          
          try {
            await refreshToken();
            if (kDebugMode) {
              print('✅ [ACTIVITY_TRACKING] Token refreshed due to activity');
            }
          } catch (e) {
            if (kDebugMode) {
              print('❌ [ACTIVITY_TRACKING] Failed to refresh token: $e');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [ACTIVITY_TRACKING] Error checking token: $e');
      }
    }
  }

  


  void dispose() {
    _cacheCleanupTimer?.cancel();
    _activityTimer?.cancel();
    _cache.clear();
    _cacheTimestamps.clear();
    _lastActivity = null;
    
    if (kDebugMode) {
      print('🧹 [API_SERVICE] ApiService disposed');
    }
  }


  Future<void> _loadToken() async {
    if (kDebugMode) {
      print('🔑 [API_SERVICE] Loading token from SharedPreferences...');
    }
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    
    // Check if token is expired or will expire soon
    if (_token != null) {
      final tokenExpiry = prefs.getString('token_expiry');
      if (tokenExpiry != null) {
        final expiryDate = DateTime.parse(tokenExpiry);
        final now = DateTime.now();
        
        // Check if token is already expired
        if (now.isAfter(expiryDate)) {
          if (kDebugMode) {
            print('🔑 [API_SERVICE] Token expired, clearing...');
          }
          await _clearToken();
        } 
        // Check if token will expire in the next 5 minutes
        else if (expiryDate.difference(now).inMinutes < 5) {
          if (kDebugMode) {
            print('⚠️ [API_SERVICE] Token will expire soon (${expiryDate.difference(now).inMinutes} minutes)');
          }
          // Try to refresh token proactively
          try {
            await refreshToken();
            if (kDebugMode) {
              print('✅ [API_SERVICE] Token refreshed proactively');
            }
          } catch (e) {
            if (kDebugMode) {
              print('❌ [API_SERVICE] Proactive refresh failed: $e');
            }
          }
        }
      }
    }
    
    if (kDebugMode) {
      print('🔑 [API_SERVICE] Token loaded: ${_token != null ? "EXISTS" : "NULL"}');
    }
  }

  bool get isAuthenticated => _token != null;
  
  // Public method to force token loading
  Future<void> loadTokenFromStorage() async {
    await _loadToken();
  }
  
  User? _currentUser;
  User? get currentUser => _currentUser;
  
  int get currentUserId => _currentUser?.id ?? 0;

  Future<void> _saveToken(String token, {int? expiresInSeconds}) async {
    if (kDebugMode) {
      print('💾 [API_SERVICE] Saving token to SharedPreferences...');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    
    // Backend'den gelen gerçek süreyi kullan, yoksa 1 saat fallback (backend JWT TTL is 60 minutes)
    final expiryDate = expiresInSeconds != null 
      ? DateTime.now().add(Duration(seconds: expiresInSeconds))
      : DateTime.now().add(const Duration(minutes: 60));
    await prefs.setString('token_expiry', expiryDate.toIso8601String());
    
    _token = token;
    if (kDebugMode) {
      print('💾 [API_SERVICE] Token saved successfully with expiry: ${expiryDate.toIso8601String()}');
    }
  }

  Future<void> _clearToken() async {
    if (kDebugMode) {
      print('🗑️ [API_SERVICE] Clearing token from SharedPreferences...');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('token_expiry');
    _token = null;
    _currentUser = null;
    if (kDebugMode) {
      print('🗑️ [API_SERVICE] Token cleared successfully');
    }
  }

  // Auth endpoints
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await _dio.get('/auth/me');
      return response.data['user'];
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String role,
  }) async {
    if (kDebugMode) {
      print('📝 [REGISTER] Starting registration process...');
      print('📝 [REGISTER] Name: $name');
      print('📝 [REGISTER] Email: $email');
      print('📝 [REGISTER] Role: $role');
      print('📝 [REGISTER] Password length: ${password.length}');
      print('📝 [REGISTER] Password confirmation length: ${passwordConfirmation.length}');
    }
    
    try {
      final requestData = {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'role': role,
      };
      
      if (kDebugMode) {
        print('📝 [REGISTER] Sending request to: /auth/register');
        print('📝 [REGISTER] Request data: $requestData');
      }
      
      final response = await _dio.post('/auth/register', data: requestData);

      if (kDebugMode) {
        print('✅ [REGISTER] Registration successful!');
        print('✅ [REGISTER] Response status: ${response.statusCode}');
        print('✅ [REGISTER] Response data: ${response.data}');
      }

      final token = response.data['token']['access_token'];
      await _saveToken(token);

      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [REGISTER] Registration failed: ${e.message}');
      }
      throw Exception(handleError(e));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [REGISTER] Registration failed: $e');
      }
      rethrow;
    }
  }

  // Social Authentication Methods
  Future<Map<String, dynamic>> googleLogin({
    required String accessToken,
    String? idToken,
  }) async {
    if (kDebugMode) {
      print('🔐 [GOOGLE_LOGIN] Starting Google login...');
      print('🔐 [GOOGLE_LOGIN] Access token length: ${accessToken.length}');
      print('🔐 [GOOGLE_LOGIN] ID token length: ${idToken?.length ?? 0}');
    }
    
    try {
      final requestData = {
        'access_token': accessToken,
        if (idToken != null) 'id_token': idToken,
      };
      
      if (kDebugMode) {
        print('🔐 [GOOGLE_LOGIN] Request data: ${requestData.keys.join(', ')}');
      }
      
      final response = await _dio.post('/auth/social/google', data: requestData);
      
      if (kDebugMode) {
        print('✅ [GOOGLE_LOGIN] Google login successful!');
        print('✅ [GOOGLE_LOGIN] Response: ${response.data}');
      }
      
      final data = response.data;
      if (data['token'] != null) {
        await _saveToken(data['token']);
      }
      
      return data;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [GOOGLE_LOGIN] Google login failed: $e');
        if (e is DioException) {
          print('❌ [GOOGLE_LOGIN] DioException details:');
          print('❌ [GOOGLE_LOGIN] Status code: ${e.response?.statusCode}');
          print('❌ [GOOGLE_LOGIN] Response data: ${e.response?.data}');
          print('❌ [GOOGLE_LOGIN] Request data: ${e.requestOptions.data}');
        }
      }
      rethrow;
    }
  }

  // Set user role after social authentication
  Future<Map<String, dynamic>> setUserRole(String role) async {
    if (kDebugMode) {
      print('🎭 [SET_ROLE] Setting user role: $role');
    }
    
    try {
      final response = await _dio.post('/auth/set-role', data: {
        'role': role,
      });
      
      if (kDebugMode) {
        print('✅ [SET_ROLE] Role set successfully');
        print('✅ [SET_ROLE] Response: ${response.data}');
      }
      
      return response.data;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SET_ROLE] Role setting failed: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> facebookLogin({
    required String accessToken,
  }) async {
    if (kDebugMode) {
      print('🔐 [FACEBOOK_LOGIN] Starting Facebook login...');
    }
    
    try {
      final requestData = {
        'access_token': accessToken,
      };
      
      final response = await _dio.post('/auth/social/facebook', data: requestData);
      
      if (kDebugMode) {
        print('✅ [FACEBOOK_LOGIN] Facebook login successful!');
      }
      
      final data = response.data;
      if (data['token'] != null) {
        await _saveToken(data['token']);
      }
      
      return data;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [FACEBOOK_LOGIN] Facebook login failed: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> appleLogin({
    required String identityToken,
    String? authorizationCode,
  }) async {
    if (kDebugMode) {
      print('🔐 [APPLE_LOGIN] Starting Apple login...');
    }
    
    try {
      final requestData = {
        'identity_token': identityToken,
        if (authorizationCode != null) 'authorization_code': authorizationCode,
      };
      
      final response = await _dio.post('/auth/social/apple', data: requestData);
      
      if (kDebugMode) {
        print('✅ [APPLE_LOGIN] Apple login successful!');
      }
      
      final data = response.data;
      if (data['token'] != null) {
        await _saveToken(data['token']);
      }
      
      return data;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [APPLE_LOGIN] Apple login failed: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> linkSocialAccount({
    required String provider,
    required String accessToken,
  }) async {
    try {
      final response = await _dio.post('/auth/social/link', data: {
        'provider': provider,
        'access_token': accessToken,
      });
      
      return response.data;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [LINK_SOCIAL] Failed to link social account: $e');
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getLinkedAccounts() async {
    try {
      final response = await _dio.get('/auth/social/accounts');
      return List<Map<String, dynamic>>.from(response.data['accounts'] ?? []);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [GET_LINKED_ACCOUNTS] Failed to get linked accounts: $e');
      }
      rethrow;
    }
  }

  Future<void> unlinkSocialAccount(String provider) async {
    try {
      await _dio.delete('/auth/social/unlink/$provider');
    } catch (e) {
      if (kDebugMode) {
        print('❌ [UNLINK_SOCIAL] Failed to unlink social account: $e');
      }
      rethrow;
    }
  }

  // Profile management
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final response = await _dio.put('/profile', data: profileData);
      return response.data;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [UPDATE_PROFILE] Failed to update profile: $e');
      }
      rethrow;
    }
  }

  Future<void> updatePassword(Map<String, dynamic> passwordData) async {
    try {
      await _dio.put('/profile/password', data: passwordData);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [UPDATE_PASSWORD] Failed to update password: $e');
      }
      rethrow;
    }
  }

  // Mail status check
  Future<Map<String, dynamic>> getMailStatus() async {
    try {
      final response = await _dio.get('/auth/mail-status');
      return response.data;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [API_SERVICE] Mail status check failed: $e');
      }
      rethrow;
    }
  }

  // Admin Analytics
  Future<Map<String, dynamic>> getAdminAnalytics() async {
    try {
      final response = await _dio.get('/admin/analytics');
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // Admin Users with pagination
  Future<Map<String, dynamic>> getAdminUsers({
    int page = 1,
    String? role,
    String? status,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
      };
      
      if (role != null) queryParams['role'] = role;
      if (status != null) queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _dio.get('/admin/users', queryParameters: queryParams);
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // Suspend User
  Future<void> suspendUser(int userId, String reason) async {
    try {
      await _dio.post('/admin/users/$userId/suspend', data: {'reason': reason});
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // Unsuspend User
  Future<void> unsuspendUser(int userId) async {
    try {
      await _dio.post('/admin/users/$userId/unsuspend');
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    if (kDebugMode) {
      print('🔐 [LOGIN] Starting login process...');
      print('🔐 [LOGIN] Email: $email');
      print('🔐 [LOGIN] Password length: ${password.length}');
    }
    
    try {
      // Input validation
      if (email.trim().isEmpty || password.trim().isEmpty) {
        throw Exception('E-posta ve şifre gerekli');
      }
      
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        throw Exception('Geçerli bir e-posta adresi girin');
      }
      
      if (password.length < 8) {
        throw Exception('Şifre en az 8 karakter olmalı');
      }

      final requestData = {
        'email': email.trim(),
        'password': password,
      };
      
      if (kDebugMode) {
        print('🔐 [LOGIN] Sending request to: /auth/login');
        print('🔐 [LOGIN] Request data: $requestData');
      }
      
      final response = await _dio.post('/auth/login', data: requestData);

      if (kDebugMode) {
        print('✅ [LOGIN] Login successful!');
        print('✅ [LOGIN] Response status: ${response.statusCode}');
        print('✅ [LOGIN] Response data: ${response.data}');
      }

      final token = response.data['token']['access_token'];
      final expiresIn = response.data['token']['expires_in']; // Backend'den gelen saniye cinsinden süre
      await _saveToken(token, expiresInSeconds: expiresIn);
      
      // Token süresini kaydet
      if (kDebugMode) {
        print('🔐 [LOGIN] Token expires in: ${expiresIn} seconds');
      }

      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [LOGIN] Login failed: ${e.message}');
      }
      throw Exception(handleError(e));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [LOGIN] Login failed: $e');
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (e) {
      // Ignore logout errors
    } finally {
      await _clearToken();
    }
  }

  Future<Map<String, dynamic>> refreshToken() async {
    if (kDebugMode) {
      print('🔄 [REFRESH_TOKEN] Attempting to refresh token...');
    }
    
    // First, try to load token from SharedPreferences
    await _loadToken();
    
    // Check if we have a valid token to refresh
    if (_token == null) {
      if (kDebugMode) {
        print('❌ [REFRESH_TOKEN] No token to refresh - user needs to login');
      }
      throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
    }
    
    try {
      // Create a new Dio instance without interceptors for refresh request
      final refreshDio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      ));
      
      final response = await refreshDio.post('/auth/refresh');
      final token = response.data['token']['access_token'];
      final expiresIn = response.data['token']['expires_in'];
      await _saveToken(token, expiresInSeconds: expiresIn);
      
      if (kDebugMode) {
        print('✅ [REFRESH_TOKEN] Token refreshed successfully');
      }
      
      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [REFRESH_TOKEN] Token refresh failed: ${e.message}');
        print('❌ [REFRESH_TOKEN] Status Code: ${e.response?.statusCode}');
        print('❌ [REFRESH_TOKEN] Response: ${e.response?.data}');
      }
      
      // Only clear token if it's a real 401/403 error
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        if (kDebugMode) {
          print('🔓 [REFRESH_TOKEN] Real auth failure (${e.response?.statusCode}), clearing token');
        }
        await _clearToken();
        if (onUnauthorized != null) {
          onUnauthorized!();
        }
        throw Exception('Token yenileme başarısız. Lütfen tekrar giriş yapın.');
      } else {
        if (kDebugMode) {
          print('🔄 [REFRESH_TOKEN] Network error, keeping token: ${e.message}');
        }
        throw Exception('Ağ hatası: ${e.message}');
      }
    }
  }

  // User endpoints
  Future<User> getProfile() async {
    try {
      final response = await _dio.get('/user');
      return User.fromJson(response.data['user']);
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }


  // Teacher endpoints
  Future<Map<String, dynamic>> createTeacherProfile(Map<String, dynamic> profileData) async {
    if (kDebugMode) {
      print('📝 [CREATE_TEACHER_PROFILE] Starting teacher profile creation...');
      print('📝 [CREATE_TEACHER_PROFILE] Profile data: $profileData');
    }
    
    try {
      final response = await _dio.post('/teacher/profile', data: profileData);

      if (kDebugMode) {
        print('✅ [CREATE_TEACHER_PROFILE] Teacher profile created successfully!');
        print('✅ [CREATE_TEACHER_PROFILE] Response: ${response.data}');
      }

      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [CREATE_TEACHER_PROFILE] Teacher profile creation failed');
        print('❌ [CREATE_TEACHER_PROFILE] Error: ${e.response?.data}');
      }
      throw Exception(handleError(e));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [CREATE_TEACHER_PROFILE] Unexpected error: $e');
      }
      throw Exception('Eğitimci profili oluşturulurken bir hata oluştu: $e');
    }
  }

  Future<List<User>> getTeacherStudents() async {
    try {
      final response = await _dio.get('/teacher/students');
      return (response.data['students'] as List)
          .map((json) => User.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<List<dynamic>> getTeacherLessons() async {
    try {
      final response = await _dio.get('/teacher/lessons');
      return response.data['lessons'] as List;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> getTeacherStatistics() async {
    try {
      final response = await _dio.get('/teacher/statistics');
      return response.data['statistics'];
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<List<Teacher>> getTeachers({
    String? category,
    List<int>? categoryIds,
    String? level,
    double? priceMin,
    double? priceMax,
    double? minRating,
    bool? onlineOnly,
    String? sortBy,
    String? search,
    int page = 1,
  }) async {
    try {
      // Cache disabled to prevent duplicate data issues

      final queryParams = <String, dynamic>{
        'page': page,
      };

      if (category != null && category.isNotEmpty) queryParams['category'] = category;
      if (categoryIds != null && categoryIds.isNotEmpty) {
        queryParams['category_ids'] = categoryIds.join(',');
      }
      if (level != null) queryParams['level'] = level;
      if (priceMin != null && priceMin > 0) queryParams['min_price'] = priceMin;
      if (priceMax != null && priceMax < 1000) queryParams['max_price'] = priceMax;
      if (minRating != null && minRating > 0) queryParams['min_rating'] = minRating;
      if (onlineOnly != null && onlineOnly) queryParams['online_only'] = onlineOnly;
      if (sortBy != null && sortBy.isNotEmpty) queryParams['sort_by'] = sortBy;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _dio.get('/teachers', queryParameters: queryParams);
      
      if (kDebugMode) {
        print('📡 Teachers API Response: ${response.statusCode}');
        print('📡 Query Params: $queryParams');
        print('📡 Response Data: ${response.data}');
      }
      
      // Handle different response structures
      List<dynamic> teachersData = [];
      if (response.data != null) {
        if (response.data['teachers'] != null && response.data['teachers']['data'] != null) {
          teachersData = response.data['teachers']['data'] as List;
        } else if (response.data['data'] != null) {
          teachersData = response.data['data'] as List;
        } else if (response.data is List) {
          teachersData = response.data as List;
        }
        
        if (kDebugMode) {
          print('📡 Parsed teachers data length: ${teachersData.length}');
        }
      }
      
      final teachers = teachersData
          .map((json) => Teacher.fromJson(json))
          .toList();

      return teachers;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<List<Teacher>> getFeaturedTeachers() async {
    try {
      final response = await _dio.get('/teachers/featured');
      return (response.data['featured_teachers'] as List?)
          ?.map((json) => Teacher.fromJson(json))
          .toList() ?? [];
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }


  Future<Teacher> getTeacher(int teacherId) async {
    try {
      final response = await _dio.get('/teachers/$teacherId');
      return Teacher.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }


  Future<Teacher> updateTeacherProfile(Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/teacher/profile', data: data);
      return Teacher.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // User Activity endpoints
  Future<void> updateUserActivity() async {
    try {
      await _dio.post('/user/activity');
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<void> updateUserOnlineStatus(bool isOnline) async {
    try {
      await _dio.post('/user/online-status', data: {
        'is_online': isOnline,
      });
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // Video Call History endpoints
  Future<Map<String, dynamic>> getCallHistory({
    int page = 1,
    int limit = 20,
    String? callType,
    String? status,
  }) async {
    try {
      final response = await _dio.get('/video-call/history', queryParameters: {
        'page': page,
        'limit': limit,
        if (callType != null) 'call_type': callType,
        if (status != null) 'status': status,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> getCallStatistics() async {
    try {
      final response = await _dio.get('/video-call/statistics');
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // Category endpoints
  Future<List<Category>> getCategories() async {
    try {
      final response = await _dio.get('/categories');
      return (response.data as List)
          .map((json) => Category.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Category> getCategory(String slug) async {
    try {
      final response = await _dio.get('/categories/$slug');
      return Category.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // Reservation endpoints
  Future<Map<String, dynamic>> createReservation(Map<String, dynamic> reservationData) async {
    if (kDebugMode) {
      print('📅 [CREATE_RESERVATION] Starting reservation creation...');
      print('📅 [CREATE_RESERVATION] Reservation data: $reservationData');
    }
    
    try {
      final response = await _dio.post('/reservations', data: reservationData);

      if (kDebugMode) {
        print('✅ [CREATE_RESERVATION] Reservation created successfully!');
        print('✅ [CREATE_RESERVATION] Response: ${response.data}');
      }

      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [CREATE_RESERVATION] Reservation creation failed');
        print('❌ [CREATE_RESERVATION] Error: ${e.response?.data}');
      }
      throw Exception(handleError(e));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [CREATE_RESERVATION] Unexpected error: $e');
      }
      throw Exception('Rezervasyon oluşturulurken bir hata oluştu: $e');
    }
  }

  // Chat endpoints
  Future<List<Chat>> getChats() async {
    if (kDebugMode) {
      print('💬 [GET_CHATS] Fetching chats...');
    }
    
    try {
      final response = await _dio.get('/chats');
      
      if (kDebugMode) {
        print('✅ [GET_CHATS] Chats fetched successfully!');
      }

      return (response.data['chats'] as List)
          .map((json) => Chat.fromJson(json))
          .toList();
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [GET_CHATS] Failed to fetch chats');
        print('❌ [GET_CHATS] Error: ${e.response?.data}');
      }
      throw Exception(handleError(e));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [GET_CHATS] Unexpected error: $e');
      }
      throw Exception('Chatler yüklenirken bir hata oluştu: $e');
    }
  }

  Future<Map<String, dynamic>> getOrCreateChat(int otherUserId) async {
    if (kDebugMode) {
      print('💬 [GET_OR_CREATE_CHAT] Getting or creating chat with user: $otherUserId');
    }
    
    try {
      final response = await _dio.post('/chats/get-or-create', data: {
        'other_user_id': otherUserId,
      });

      if (kDebugMode) {
        print('✅ [GET_OR_CREATE_CHAT] Chat retrieved successfully!');
      }

      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [GET_OR_CREATE_CHAT] Failed to get or create chat');
        print('❌ [GET_OR_CREATE_CHAT] Error: ${e.response?.data}');
      }
      throw Exception(handleError(e));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [GET_OR_CREATE_CHAT] Unexpected error: $e');
      }
      throw Exception('Chat oluşturulurken bir hata oluştu: $e');
    }
  }

  Future<Message> sendMessage(int chatId, String content, {String type = 'text'}) async {
    if (kDebugMode) {
      print('💬 [SEND_MESSAGE] Sending message to chat: $chatId');
    }
    
    try {
      // Check if token exists before sending
      if (_token == null) {
        if (kDebugMode) {
          print('❌ [SEND_MESSAGE] No token available');
        }
        throw Exception('Oturum süresi dolmuş. Lütfen tekrar giriş yapın.');
      }

      final response = await _dio.post('/chats/messages', data: {
        'chat_id': chatId,
        'content': content,
        'type': type,
      });

      if (kDebugMode) {
        print('✅ [SEND_MESSAGE] Message sent successfully!');
      }

      return Message.fromJson(response.data['message']);
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [SEND_MESSAGE] Failed to send message');
        print('❌ [SEND_MESSAGE] Error: ${e.response?.data}');
        print('❌ [SEND_MESSAGE] Status Code: ${e.response?.statusCode}');
      }
      
      // Handle 401 specifically for message sending - don't clear token here
      // Let the interceptor handle it properly
      if (e.response?.statusCode == 401) {
        if (kDebugMode) {
          print('🔓 [SEND_MESSAGE] 401 Unauthorized - token may be expired');
        }
        throw Exception('Oturum süresi dolmuş. Lütfen tekrar giriş yapın.');
      }
      
      throw Exception(handleError(e));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SEND_MESSAGE] Unexpected error: $e');
      }
      throw Exception('Mesaj gönderilirken bir hata oluştu: $e');
    }
  }

  Future<void> markMessagesAsRead(int chatId) async {
    if (kDebugMode) {
      print('💬 [MARK_AS_READ] Marking messages as read in chat: $chatId');
    }
    
    try {
      await _dio.put('/chats/mark-read', data: {
        'chat_id': chatId,
      });

      if (kDebugMode) {
        print('✅ [MARK_AS_READ] Messages marked as read successfully!');
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [MARK_AS_READ] Failed to mark messages as read');
        print('❌ [MARK_AS_READ] Error: ${e.response?.data}');
      }
      throw Exception(handleError(e));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [MARK_AS_READ] Unexpected error: $e');
      }
      throw Exception('Mesajlar okundu olarak işaretlenirken bir hata oluştu: $e');
    }
  }


  // Upload voice message
  Future<Message> uploadVoiceMessage(int chatId, String audioPath, int duration) async {
    if (kDebugMode) {
      print('🎤 [UPLOAD_VOICE] Uploading voice message to chat: $chatId, duration: $duration');
    }
    
    try {
      FormData formData = FormData.fromMap({
        'chat_id': chatId,
        'duration': duration,
        'audio_file': await MultipartFile.fromFile(
          audioPath,
          filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
        ),
      });

      final response = await _dio.post('/chat/voice-message', data: formData);
      
      if (kDebugMode) {
        print('✅ [UPLOAD_VOICE] Voice message uploaded successfully');
      }
      
      return Message.fromJson(response.data['message']);
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [UPLOAD_VOICE] Error: ${e.message}');
      }
      throw Exception(handleError(e));
    }
  }

  // Delete message
  Future<void> deleteMessage(int messageId) async {
    if (kDebugMode) {
      print('🗑️ [DELETE_MESSAGE] Deleting message: $messageId');
    }
    
    try {
      await _dio.delete('/chat/messages/$messageId');
      
      if (kDebugMode) {
        print('✅ [DELETE_MESSAGE] Message deleted successfully');
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [DELETE_MESSAGE] Error: ${e.message}');
      }
      throw Exception(handleError(e));
    }
  }

  // Send message reaction
  Future<void> sendMessageReaction(int messageId, String emoji) async {
    if (kDebugMode) {
      print('⭐ [MESSAGE_REACTION] Sending reaction to message: $messageId');
    }
    
    try {
      await _dio.post('/chat/messages/$messageId/reaction', data: {
        'reaction': emoji,
      });
      
      if (kDebugMode) {
        print('✅ [MESSAGE_REACTION] Reaction sent successfully');
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [MESSAGE_REACTION] Error: ${e.message}');
      }
      throw Exception(handleError(e));
    }
  }


  // Search endpoints
  Future<Map<String, dynamic>> searchTeachers({
    String? query,
    String? category,
    double? minPrice,
    double? maxPrice,
    double? rating,
    String? location,
    String? sortBy,
    bool? onlineOnly,
    int page = 1,
    int perPage = 20,
  }) async {
    if (kDebugMode) {
      print('🔍 [SEARCH_TEACHERS] Searching teachers...');
    }
    
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };

      if (query != null && query.isNotEmpty) {
        queryParams['q'] = query;
      }
      if (category != null) {
        queryParams['category'] = category;
      }
      if (minPrice != null) {
        queryParams['min_price'] = minPrice;
      }
      if (maxPrice != null) {
        queryParams['max_price'] = maxPrice;
      }
      if (rating != null) {
        queryParams['rating'] = rating;
      }
      if (location != null) {
        queryParams['location'] = location;
      }
      if (sortBy != null) {
        queryParams['sort_by'] = sortBy;
      }
      if (onlineOnly != null) {
        queryParams['online_only'] = onlineOnly;
      }

      final response = await _dio.get('/search/teachers', queryParameters: queryParams);

      if (kDebugMode) {
        print('✅ [SEARCH_TEACHERS] Search completed successfully!');
      }

      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [SEARCH_TEACHERS] Search failed');
        print('❌ [SEARCH_TEACHERS] Error: ${e.response?.data}');
      }
      throw Exception(handleError(e));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SEARCH_TEACHERS] Unexpected error: $e');
      }
      throw Exception('Eğitimci arama sırasında bir hata oluştu: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSearchSuggestions(String query, {int limit = 10}) async {
    if (kDebugMode) {
      print('🔍 [GET_SUGGESTIONS] Getting search suggestions for: $query');
    }
    
    try {
      final response = await _dio.get('/search/suggestions', queryParameters: {
        'q': query,
        'limit': limit,
      });

      if (kDebugMode) {
        print('✅ [GET_SUGGESTIONS] Suggestions retrieved successfully!');
      }

      if (response.data['suggestions'] != null && response.data['suggestions'] is List) {
        return (response.data['suggestions'] as List).cast<Map<String, dynamic>>();
      } else {
        return [];
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [GET_SUGGESTIONS] Failed to get suggestions');
        print('❌ [GET_SUGGESTIONS] Error: ${e.response?.data}');
      }
      throw Exception(handleError(e));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [GET_SUGGESTIONS] Unexpected error: $e');
      }
      throw Exception('Arama önerileri alınırken bir hata oluştu: $e');
    }
  }

  Future<List<String>> getPopularSearches() async {
    if (kDebugMode) {
      print('🔍 [GET_POPULAR_SEARCHES] Getting popular searches...');
    }
    
    try {
      final response = await _dio.get('/search/popular');

      if (kDebugMode) {
        print('✅ [GET_POPULAR_SEARCHES] Popular searches retrieved successfully!');
      }

      if (response.data['popular_searches'] != null && response.data['popular_searches'] is List) {
        return (response.data['popular_searches'] as List).cast<String>();
      } else {
        return [];
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [GET_POPULAR_SEARCHES] Failed to get popular searches');
        print('❌ [GET_POPULAR_SEARCHES] Error: ${e.response?.data}');
      }
      throw Exception(handleError(e));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [GET_POPULAR_SEARCHES] Unexpected error: $e');
      }
      throw Exception('Popüler aramalar alınırken bir hata oluştu: $e');
    }
  }

  Future<Map<String, dynamic>> getSearchFilters() async {
    if (kDebugMode) {
      print('🔍 [GET_SEARCH_FILTERS] Getting search filters...');
    }
    
    try {
      final response = await _dio.get('/search/filters');

      if (kDebugMode) {
        print('✅ [GET_SEARCH_FILTERS] Search filters retrieved successfully!');
      }

      if (response.data['filters'] != null) {
        return response.data['filters'];
      } else {
        return {'categories': [], 'languages': []};
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [GET_SEARCH_FILTERS] Failed to get search filters');
        print('❌ [GET_SEARCH_FILTERS] Error: ${e.response?.data}');
      }
      throw Exception(handleError(e));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [GET_SEARCH_FILTERS] Unexpected error: $e');
      }
      throw Exception('Arama filtreleri alınırken bir hata oluştu: $e');
    }
  }

  Future<List<Reservation>> getStudentReservations() async {
    try {
      final response = await _dio.get('/student/reservations');
      
      // Backend paginated response döndürüyor, data kısmını al
      if (response.data is Map<String, dynamic>) {
        final data = response.data['data'] as List;
        return data.map((json) => Reservation.fromJson(json)).toList();
      } else {
        // Fallback: direkt array ise
        return (response.data as List)
            .map((json) => Reservation.fromJson(json))
            .toList();
      }
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<List<Reservation>> getTeacherReservations() async {
    try {
      final response = await _dio.get('/teacher/reservations');
      
      List<Reservation> reservations = [];
      
      if (kDebugMode) {
        print('🔍 [API_SERVICE] Raw response data: ${response.data}');
      }
      
      // Backend reservations field'ından veriyi al
      if (response.data is Map<String, dynamic>) {
        final data = response.data['reservations'] as List?;
        if (data != null) {
          reservations = data.map((json) => Reservation.fromJson(json)).toList();
        }
      } else {
        // Fallback: direkt array ise
        reservations = (response.data as List)
            .map((json) => Reservation.fromJson(json))
            .toList();
      }
      
      if (kDebugMode) {
        print('🔍 [API_SERVICE] Parsed ${reservations.length} reservations from backend');
        for (int i = 0; i < reservations.length; i++) {
          print('🔍 [API_SERVICE] Reservation $i: ID=${reservations[i].id}, Subject=${reservations[i].subject}, Status=${reservations[i].status}');
        }
      }
      
      // Ultra strong duplicate removal by ID
      final seenIds = <int>{};
      final uniqueReservations = <Reservation>[];
      
      if (kDebugMode) {
        print('🔍 [API_SERVICE] Starting duplicate removal process');
        print('🔍 [API_SERVICE] Input reservations: ${reservations.length}');
      }
      
      // Single pass: collect unique reservations
      for (final reservation in reservations) {
        if (!seenIds.contains(reservation.id)) {
          seenIds.add(reservation.id);
          uniqueReservations.add(reservation);
          if (kDebugMode) {
            print('🔍 [API_SERVICE] Added unique reservation: ID=${reservation.id}, Subject=${reservation.subject}');
          }
        } else {
          if (kDebugMode) {
            print('🔍 [API_SERVICE] DUPLICATE FOUND: ID=${reservation.id}, Subject=${reservation.subject}');
          }
        }
      }
      
      if (kDebugMode) {
        print('🔍 [API_SERVICE] Unique IDs found: ${seenIds.length}');
        print('🔍 [API_SERVICE] Duplicates removed: ${reservations.length - uniqueReservations.length}');
        print('🔍 [API_SERVICE] Returning ${uniqueReservations.length} unique reservations');
      }
      
      return uniqueReservations;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }


  Future<Reservation> updateReservation(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/reservations/$id', data: data);
      return Reservation.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<void> deleteReservation(int id) async {
    try {
      await _dio.delete('/reservations/$id');
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Reservation> updateReservationStatus(int id, String status) async {
    try {
      final response = await _dio.put('/reservations/$id/status', data: {
        'status': status,
      });
      return Reservation.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // Complete reservation (teacher only)
  Future<Map<String, dynamic>> completeReservation(int id) async {
    try {
      if (kDebugMode) {
        print('✅ [API_SERVICE] completeReservation called for ID: $id');
      }
      
      final response = await _dio.post('/reservations/$id/complete');
      
      if (kDebugMode) {
        print('✅ [API_SERVICE] Complete Response: ${response.data}');
      }
      
      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [API_SERVICE] Complete Reservation Error: ${e.message}');
        print('❌ [API_SERVICE] Response: ${e.response?.data}');
      }
      throw Exception(handleError(e));
    }
  }

  // Request reschedule (student only)
  Future<Map<String, dynamic>> requestReschedule({
    required int reservationId,
    required DateTime newDatetime,
    required String reason,
  }) async {
    try {
      if (kDebugMode) {
        print('🔄 [API_SERVICE] requestReschedule called for ID: $reservationId');
        print('🔄 [API_SERVICE] New datetime: $newDatetime, Reason: $reason');
      }
      
      final response = await _dio.post(
        '/reservations/$reservationId/reschedule-request',
        data: {
          'new_datetime': newDatetime.toIso8601String(),
          'reason': reason,
        },
      );
      
      if (kDebugMode) {
        print('🔄 [API_SERVICE] Reschedule Request Response: ${response.data}');
      }
      
      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [API_SERVICE] Reschedule Request Error: ${e.message}');
        print('❌ [API_SERVICE] Response: ${e.response?.data}');
      }
      throw Exception(handleError(e));
    }
  }

  // Handle reschedule request (teacher only)
  Future<Map<String, dynamic>> handleRescheduleRequest({
    required int reservationId,
    required String action, // 'approve' or 'reject'
    String? rejectionReason,
  }) async {
    try {
      if (kDebugMode) {
        print('🔄 [API_SERVICE] handleRescheduleRequest called for ID: $reservationId');
        print('🔄 [API_SERVICE] Action: $action');
      }
      
      final data = <String, dynamic>{
        'action': action,
      };
      
      if (rejectionReason != null) {
        data['rejection_reason'] = rejectionReason;
      }
      
      final response = await _dio.post(
        '/reservations/$reservationId/reschedule-handle',
        data: data,
      );
      
      if (kDebugMode) {
        print('🔄 [API_SERVICE] Handle Reschedule Response: ${response.data}');
      }
      
      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [API_SERVICE] Handle Reschedule Error: ${e.message}');
        print('❌ [API_SERVICE] Response: ${e.response?.data}');
      }
      throw Exception(handleError(e));
    }
  }

  // Submit rating (student only)
  Future<Map<String, dynamic>> submitRating({
    required int reservationId,
    required int rating,
    String? review,
  }) async {
    try {
      if (kDebugMode) {
        print('⭐ [API_SERVICE] submitRating called for ID: $reservationId');
        print('⭐ [API_SERVICE] Rating: $rating, Review: $review');
      }
      
      final data = <String, dynamic>{
        'rating': rating,
      };
      
      if (review != null && review.isNotEmpty) {
        data['review'] = review;
      }
      
      final response = await _dio.post(
        '/reservations/$reservationId/rating',
        data: data,
      );
      
      if (kDebugMode) {
        print('⭐ [API_SERVICE] Submit Rating Response: ${response.data}');
      }
      
      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [API_SERVICE] Submit Rating Error: ${e.message}');
        print('❌ [API_SERVICE] Response: ${e.response?.data}');
      }
      throw Exception(handleError(e));
    }
  }

  // Notification endpoints
  Future<Map<String, dynamic>> getNotifications({
    String? type,
    bool? isRead,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };
      
      if (type != null) queryParams['type'] = type;
      if (isRead != null) queryParams['is_read'] = isRead;

      final response = await _dio.get('/notifications', queryParameters: queryParams);
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<void> markNotificationAsRead(int notificationId) async {
    try {
      await _dio.put('/notifications/$notificationId/read');
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    try {
      await _dio.put('/notifications/read-all');
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<void> deleteNotification(int notificationId) async {
    try {
      await _dio.delete('/notifications/$notificationId');
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> getNotificationStatistics() async {
    try {
      final response = await _dio.get('/notifications/statistics');
      return response.data['statistics'];
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // Favorites endpoints
  Future<List<Teacher>> getFavorites() async {
    try {
      final response = await _dio.get('/favorites');
      return (response.data as List)
          .map((json) => Teacher.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<void> addToFavorites(int teacherId) async {
    try {
      await _dio.post('/favorites/$teacherId');
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<void> removeFromFavorites(int teacherId) async {
    try {
      await _dio.delete('/favorites/$teacherId');
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // File upload endpoints
  Future<Map<String, dynamic>> uploadProfilePhoto(String imagePath) async {
    try {
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(imagePath),
      });

      final response = await _dio.post(
        '/upload/profile-photo',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      return response.data;
    } catch (e) {
      throw Exception('Profil fotoğrafı yüklenirken hata oluştu: $e');
    }
  }

  Future<void> deleteProfilePhoto() async {
    try {
      await _dio.delete('/upload/profile-photo');
    } catch (e) {
      throw Exception('Profil fotoğrafı silinirken hata oluştu: $e');
    }
  }

  // Rating endpoints
  Future<Rating> createRating({
    required int reservationId,
    required int rating,
    String? review,
  }) async {
    try {
      final response = await _dio.post('/ratings', data: {
        'reservation_id': reservationId,
        'rating': rating,
        'review': review,
      });
      return Rating.fromJson(response.data['rating']);
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<List<Rating>> getStudentRatings() async {
    try {
      final response = await _dio.get('/student/ratings');
      return (response.data['data'] as List)
          .map((json) => Rating.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<List<Rating>> getTeacherRatings(int teacherId) async {
    try {
      final response = await _dio.get('/teachers/$teacherId/ratings');
      
      if (kDebugMode) {
        print('📡 Teacher Ratings API Response: ${response.statusCode}');
        print('📡 Teacher ID: $teacherId');
        print('📡 Response Data: ${response.data}');
      }
      
      // Handle different response structures
      List<dynamic> ratingsData = [];
      if (response.data != null) {
        if (response.data['ratings'] != null) {
          ratingsData = response.data['ratings'] as List;
        } else if (response.data['data'] != null) {
          ratingsData = response.data['data'] as List;
        } else if (response.data is List) {
          ratingsData = response.data as List;
        }
      }
      
      if (kDebugMode) {
        print('📡 Ratings Data Length: ${ratingsData.length}');
        if (ratingsData.isNotEmpty) {
          print('📡 First Rating Sample: ${ratingsData.first}');
        }
      }
      
      if (kDebugMode) {
        print('📡 About to parse ${ratingsData.length} ratings...');
      }
      
      try {
        final ratings = ratingsData
            .map((json) {
              if (kDebugMode) {
                print('📡 Parsing rating: $json');
              }
              return Rating.fromJson(json);
            })
            .toList();
        
        if (kDebugMode) {
          print('📡 Successfully parsed ${ratings.length} ratings');
        }
        
        return ratings;
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error parsing ratings: $e');
        }
        throw Exception('Rating parsing error: $e');
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ Teacher Ratings API Error: ${e.message}');
        print('❌ Response: ${e.response?.data}');
      }
      throw Exception(handleError(e));
    }
  }

  Future<Rating> updateRating({
    required int ratingId,
    required int rating,
    String? review,
  }) async {
    try {
      final response = await _dio.put('/ratings/$ratingId', data: {
        'rating': rating,
        'review': review,
      });
      return Rating.fromJson(response.data['rating']);
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<void> deleteRating(int ratingId) async {
    try {
      await _dio.delete('/ratings/$ratingId');
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // Email verification endpoints
  Future<void> verifyEmail(String email, String code) async {
    try {
      await _dio.post('/auth/verify-email-code', data: {
        'email': email,
        'verification_code': code,
      });
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<void> resendVerification(String email) async {
    try {
      await _dio.post('/auth/resend-verification', data: {
        'email': email,
      });
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // Password reset endpoints
  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post('/auth/forgot-password', data: {
        'email': email,
      });
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<void> resetPassword({
    required String token,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      await _dio.post('/auth/reset-password', data: {
        'token': token,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      });
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // Admin endpoints
  Future<Map<String, dynamic>> getAdminDashboard() async {
    try {
      final response = await _dio.get('/admin/dashboard');
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }


  Future<void> updateUserStatus(int userId, String status) async {
    try {
      await _dio.put('/admin/users/$userId/status', data: {
        'status': status,
      });
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<List<dynamic>> getAdminReservations({String? status}) async {
    try {
      final response = await _dio.get('/admin/reservations', queryParameters: {
        if (status != null) 'status': status,
      });
      return response.data['data'];
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // Teacher approval methods
  Future<List<User>> getPendingTeachers() async {
    try {
      final response = await _dio.get('/admin/teachers/pending');
      return (response.data['data'] as List)
          .map((json) => User.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<void> approveTeacher(int userId, {String? adminNotes}) async {
    try {
      await _dio.post('/admin/teachers/$userId/approve', data: {
        if (adminNotes != null) 'admin_notes': adminNotes,
      });
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<void> rejectTeacher(int userId, String rejectionReason, {String? adminNotes}) async {
    try {
      await _dio.post('/admin/teachers/$userId/reject', data: {
        'rejection_reason': rejectionReason,
        if (adminNotes != null) 'admin_notes': adminNotes,
      });
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<List<User>> getAllUsers({String? role, String? status, int page = 1}) async {
    try {
      final response = await _dio.get('/admin/users', queryParameters: {
        if (role != null) 'role': role,
        if (status != null) 'status': status,
        'page': page,
      });
      return (response.data['data'] as List)
          .map((json) => User.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // Advanced message features
  Future<void> pinMessage(int messageId) async {
    try {
      await _dio.post('/chat/messages/$messageId/pin');
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<void> unpinMessage(int messageId) async {
    try {
      await _dio.post('/chat/messages/$messageId/unpin');
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Message> editMessage(int messageId, String newContent) async {
    try {
      final response = await _dio.put('/chat/messages/$messageId/edit', data: {
        'content': newContent,
      });
      return Message.fromJson(response.data['message_data']);
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Message> forwardMessage(int messageId, int targetChatId) async {
    try {
      final response = await _dio.post('/chat/messages/$messageId/forward', data: {
        'chat_id': targetChatId,
      });
      return Message.fromJson(response.data['forwarded_message']);
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Message> replyToMessage(int messageId, String content) async {
    try {
      final response = await _dio.post('/chat/messages/$messageId/reply', data: {
        'content': content,
      });
      return Message.fromJson(response.data['reply_message']);
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<MessageThread> createThread(int messageId, {String? title}) async {
    try {
      final response = await _dio.post('/chat/messages/$messageId/thread', data: {
        if (title != null) 'title': title,
      });
      return MessageThread.fromJson(response.data['thread']);
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<MessageThread> getThread(int threadId) async {
    try {
      final response = await _dio.get('/chat/threads/$threadId');
      return MessageThread.fromJson(response.data['thread']);
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<MessageTranslation> translateMessage(int messageId, String targetLanguage) async {
    try {
      final response = await _dio.post('/chat/messages/$messageId/translate', data: {
        'target_language': targetLanguage,
      });
      return MessageTranslation.fromJson(response.data['translation']);
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<List<Message>> getPinnedMessages(int chatId) async {
    try {
      final response = await _dio.get('/chat/pinned-messages', queryParameters: {
        'chat_id': chatId,
      });
      return (response.data['pinned_messages'] as List)
          .map((json) => Message.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }


  // Profile photo endpoints
  Future<String> updateProfilePhoto(XFile image) async {
    try {
      print('📸 [API] Starting photo upload...');
      print('📸 [API] Image path: ${image.path}');
      print('📸 [API] Image name: ${image.name}');
      
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(
          image.path,
          filename: image.name,
        ),
      });
      
      print('📸 [API] Sending POST to: $baseUrl/upload/profile-photo');
      final response = await _dio.post('/upload/profile-photo', data: formData);
      
      print('📸 [API] Response received: ${response.data}');
      
      // Clear user cache to force reload
      _currentUser = null;
      
      // Return the new profile photo URL
      final photoUrl = response.data['profile_photo_url'] ?? '';
      print('📸 [API] New photo URL: $photoUrl');
      
      return photoUrl;
    } on DioException catch (e) {
      print('❌ [API] Photo upload error: ${e.response?.data}');
      print('❌ [API] Status code: ${e.response?.statusCode}');
      throw Exception(handleError(e));
    }
  }

  // Push notification endpoints
  Future<void> registerPushToken(String token) async {
    try {
      await _dio.post('/notifications/register-token', data: {
        'token': token,
      });
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<void> unregisterPushToken(String token) async {
    try {
      await _dio.post('/notifications/unregister-token', data: {
        'token': token,
      });
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // Payment endpoints
  Future<Map<String, dynamic>> createPayment(Map<String, dynamic> paymentData) async {
    try {
      final response = await _dio.post('/payments/create', data: paymentData);
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> confirmPayment(Map<String, dynamic> confirmationData) async {
    try {
      final response = await _dio.post('/payments/confirm', data: confirmationData);
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> getPaymentHistory({int page = 1, int perPage = 20}) async {
    try {
      final response = await _dio.get('/payments/history', queryParameters: {
        'page': page,
        'per_page': perPage,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // File sharing endpoints
  Future<Map<String, dynamic>> getSharedFiles(int otherUserId, int? reservationId) async {
    try {
      final response = await _dio.get('/files/shared', queryParameters: {
        'other_user_id': otherUserId,
        'reservation_id': reservationId,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> uploadSharedFile({
    required String filePath,
    required String fileName,
    required int receiverId,
    required String description,
    required String category,
    int? reservationId,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
        'shared_with': [receiverId], // Backend expects array
        'description': description,
        'category': category,
        if (reservationId != null) 'reservation_id': reservationId,
      });

      final response = await _dio.post('/files/upload-shared', data: formData);
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> downloadSharedFile(int fileId) async {
    try {
      final response = await _dio.get('/files/download/$fileId');
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  /// Download file from URL and return as bytes
  Future<Uint8List?> downloadFileFromUrl(String fileUrl) async {
    try {
      final response = await _dio.get(
        fileUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );
      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [DOWNLOAD_FILE] Failed to download: ${e.message}');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>> deleteSharedFile(int fileId) async {
    try {
      final response = await _dio.delete('/files/$fileId');
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // Reservations endpoints
  Future<List<Reservation>> getReservations({
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    if (kDebugMode) {
      print('🚀 [API_SERVICE] getReservations called');
      print('🚀 [API_SERVICE] Query params: status=$status, fromDate=$fromDate, toDate=$toDate');
    }
    
    try {
      final queryParams = <String, dynamic>{};
      
      if (status != null) queryParams['status'] = status;
      if (fromDate != null) queryParams['from_date'] = fromDate.toIso8601String();
      if (toDate != null) queryParams['to_date'] = toDate.toIso8601String();

      final response = await _dio.get('/reservations', queryParameters: queryParams);
      
      if (kDebugMode) {
        print('📡 [API_SERVICE] Reservations Response: ${response.statusCode}');
        print('📡 [API_SERVICE] Response Data: ${response.data}');
      }
      
      final reservationsData = response.data['data'] as List? ?? response.data['reservations'] as List? ?? [];
      
      if (kDebugMode) {
        print('📡 [API_SERVICE] Parsing ${reservationsData.length} reservations');
      }
      
      return reservationsData.map((json) {
        try {
          return Reservation.fromJson(json);
        } catch (e) {
          if (kDebugMode) {
            print('❌ [API_SERVICE] Error parsing reservation: $e');
            print('❌ [API_SERVICE] JSON: $json');
          }
          rethrow;
        }
      }).toList();
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> getReservationStatistics() async {
    try {
      if (kDebugMode) {
        print('📊 [API_SERVICE] getReservationStatistics called');
      }
      
      final response = await _dio.get('/reservations/statistics');
      
      if (kDebugMode) {
        print('📊 [API_SERVICE] Statistics Response: ${response.statusCode}');
        print('📊 [API_SERVICE] Response Data: ${response.data}');
      }
      
      final statistics = response.data['statistics'];
      
      if (kDebugMode) {
        print('📊 [API_SERVICE] Parsed statistics: $statistics');
      }
      
      return statistics;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [API_SERVICE] Statistics API Error: ${e.message}');
        print('❌ [API_SERVICE] Response: ${e.response?.data}');
      }
      throw Exception(handleError(e));
    }
  }

  // Assignment endpoints
  Future<List<Assignment>> getAssignments() async {
    try {
      final response = await _dio.get('/assignments');
      final assignmentsData = response.data['assignments'] as List;
      return assignmentsData.map((json) => Assignment.fromJson(json)).toList();
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> createAssignment({
    required int studentId,
    required String title,
    required String description,
    required DateTime dueDate,
    required String difficulty,
    int? reservationId,
  }) async {
    try {
      final response = await _dio.post('/assignments', data: {
        'student_id': studentId,
        'title': title,
        'description': description,
        'due_date': dueDate.toIso8601String(),
        'difficulty': difficulty,
        if (reservationId != null) 'reservation_id': reservationId,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> submitAssignment({
    required int assignmentId,
    String? submissionNotes,
    String? filePath,
  }) async {
    try {
      FormData formData = FormData.fromMap({
        'submission_notes': submissionNotes,
        if (filePath != null)
          'file': await MultipartFile.fromFile(filePath),
      });

      final response = await _dio.post('/assignments/$assignmentId/submit', data: formData);
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }


  // Lesson endpoints
  Future<List<Lesson>> getUserLessons({
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
    int? page,
  }) async {
      if (kDebugMode) {
        print('🚀 [API_SERVICE] getUserLessons called');
        print('🚀 [API_SERVICE] Query params: status=$status, fromDate=$fromDate, toDate=$toDate, page=$page');
      }
      
      try {
        final queryParams = <String, dynamic>{};
        
        if (status != null) queryParams['status'] = status;
        if (fromDate != null) queryParams['from_date'] = fromDate.toIso8601String();
        if (toDate != null) queryParams['to_date'] = toDate.toIso8601String();
        if (page != null) queryParams['page'] = page;

      final response = await _dio.get('/lessons', queryParameters: queryParams);
      
      if (kDebugMode) {
        print('📡 [API_SERVICE] Lessons Response: ${response.statusCode}');
        print('📡 [API_SERVICE] Response Data: ${response.data}');
      }
      
      final lessonsData = response.data['data'] as List? ?? response.data['lessons'] as List? ?? [];
      
      if (kDebugMode) {
        print('📡 [API_SERVICE] Parsing ${lessonsData.length} lessons');
      }
      
      return lessonsData.map((json) {
        try {
          return Lesson.fromJson(json);
        } catch (e) {
          if (kDebugMode) {
            print('❌ [API_SERVICE] Error parsing lesson: $e');
            print('❌ [API_SERVICE] JSON: $json');
          }
          rethrow;
        }
      }).toList();
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> getLessonStatistics() async {
    try {
      final response = await _dio.get('/lessons/statistics');
      return response.data['statistics'];
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<List<dynamic>> getUpcomingLessons() async {
    try {
      final response = await _dio.get('/lessons/upcoming');
      return response.data['upcoming_lessons'] as List;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> getStudentAssignments() async {
    try {
      final response = await _dio.get('/assignments/student');
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> getTeacherAssignments() async {
    try {
      final response = await _dio.get('/assignments/teacher');
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<User> getUserById(int userId) async {
    try {
      final response = await _dio.get('/users/$userId');
      return User.fromJson(response.data['user']);
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<List<User>> searchUsers(String query, {String? role}) async {
    try {
      final response = await _dio.get('/search/users', queryParameters: {
        'q': query,
        'role': role,
      });
      return (response.data['users'] as List)
          .map((json) => User.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }





  Future<Map<String, dynamic>> gradeAssignment(
    int assignmentId,
    String grade,
    String feedback,
  ) async {
    try {
      final response = await _dio.post('/assignments/$assignmentId/grade', data: {
        'grade': grade,
        'feedback': feedback,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  /// Update assignment (teacher only)
  Future<Map<String, dynamic>> updateAssignment(
    int assignmentId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.put('/assignments/$assignmentId', data: data);
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  /// Delete assignment (teacher only)
  Future<Map<String, dynamic>> deleteAssignment(int assignmentId) async {
    try {
      final response = await _dio.delete('/assignments/$assignmentId');
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  /// Download assignment submission file
  Future<void> downloadAssignmentSubmission(
    int assignmentId,
    String fileName,
  ) async {
    try {
      final response = await _dio.get(
        '/assignments/$assignmentId/download',
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
        ),
      );
      
      // File download handled by platform (web/mobile)
      // Return bytes for further processing
      if (kDebugMode) {
        print('✅ File downloaded: $fileName (${response.data.length} bytes)');
      }
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  /// Request resubmission (teacher only)
  Future<Map<String, dynamic>> requestResubmission({
    required int assignmentId,
    required String feedback,
    DateTime? newDueDate,
  }) async {
    try {
      final response = await _dio.post(
        '/assignments/$assignmentId/request-resubmission',
        data: {
          'feedback': feedback,
          if (newDueDate != null) 'new_due_date': newDueDate.toIso8601String(),
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  /// Extend deadline (teacher only)
  Future<Map<String, dynamic>> extendAssignmentDeadline({
    required int assignmentId,
    required DateTime newDueDate,
    String? reason,
  }) async {
    try {
      final response = await _dio.post(
        '/assignments/$assignmentId/extend-deadline',
        data: {
          'new_due_date': newDueDate.toIso8601String(),
          if (reason != null) 'reason': reason,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  /// Get valid grade list
  List<String> getValidGrades() {
    return [
      'A+', 'A', 'A-',
      'B+', 'B', 'B-',
      'C+', 'C', 'C-',
      'D+', 'D', 'D-',
      'F'
    ];
  }

  // Lesson management endpoints
  Future<Map<String, dynamic>> getLessonStatus(int reservationId) async {
    try {
      final response = await _dio.get('/lessons/status/$reservationId');
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> startLesson(int reservationId) async {
    try {
      final response = await _dio.post('/lessons/start', data: {
        'reservation_id': reservationId,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> endLesson(
    int reservationId,
    String notes,
    int rating,
    String feedback,
  ) async {
    try {
      final response = await _dio.post('/lessons/end', data: {
        'reservation_id': reservationId,
        'notes': notes,
        'rating': rating,
        'feedback': feedback,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }


  Future<List<Map<String, dynamic>>> getSearchHistory() async {
    try {
      final response = await _dio.get('/search/history');
      return List<Map<String, dynamic>>.from(response.data['searches'] ?? []);
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<void> saveSearchQuery(String query) async {
    try {
      await _dio.post('/search/history', data: {'query': query});
    } on DioException catch (e) {
      // Don't throw error for search history saving
      if (kDebugMode) {
        print('Failed to save search query: ${e.message}');
      }
    }
  }

  Future<void> clearSearchHistory() async {
    try {
      await _dio.delete('/search/history');
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> getAnalytics({String period = '30'}) async {
    try {
      final response = await _dio.get('/analytics', queryParameters: {'period': period});
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<int> getUnreadMessageCount() async {
    try {
      final response = await _dio.get('/chats/unread-count');
      return response.data['count'] ?? 0;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<int> getUnreadNotificationCount() async {
    try {
      final response = await _dio.get('/notifications/unread-count');
      return response.data['count'];
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<List<dynamic>> getAdminCategories() async {
    try {
      final response = await _dio.get('/admin/categories');
      return response.data['data'];
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> createCategory({
    required String name,
    required String slug,
    String? description,
    int? parentId,
    String? icon,
    int? sortOrder,
  }) async {
    try {
      final response = await _dio.post('/admin/categories', data: {
        'name': name,
        'slug': slug,
        'description': description,
        'parent_id': parentId,
        'icon': icon,
        'sort_order': sortOrder,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<List<dynamic>> getAuditLogs({String? action}) async {
    try {
      final response = await _dio.get('/admin/audit-logs', queryParameters: {
        if (action != null) 'action': action,
      });
      return response.data['data'];
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // Content page endpoints
  Future<List<Map<String, dynamic>>> getContentPages() async {
    try {
      final response = await _dio.get('/content-pages');
      return (response.data['pages'] as List).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> getContentPage(String slug) async {
    try {
      final response = await _dio.get('/content-pages/$slug');
      return response.data['page'];
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // Error handling
  String handleError(DioException error) {
    if (kDebugMode) {
      print('🔍 [ERROR_HANDLER] Processing error: ${error.type}');
      print('🔍 [ERROR_HANDLER] Status: ${error.response?.statusCode}');
      print('🔍 [ERROR_HANDLER] Data: ${error.response?.data}');
    }
    
    // Handle specific HTTP status codes with better messages
    if (error.response != null) {
      switch (error.response!.statusCode) {
        case 401:
          return 'Oturum süresi doldu. Lütfen tekrar giriş yapın.';
        case 403:
          return 'Bu işlem için yetkiniz bulunmuyor.';
        case 404:
          return 'İstenen kaynak bulunamadı.';
        case 422:
          final data = error.response!.data;
          if (data is Map<String, dynamic> && data.containsKey('message')) {
            return data['message'].toString();
          }
          return 'Geçersiz veri gönderildi.';
        case 500:
          return 'Sunucu hatası. Lütfen daha sonra tekrar deneyin.';
        default:
          final data = error.response!.data;
          if (data is Map<String, dynamic>) {
            // Format 1: {error: {message: "..."}}
            if (data.containsKey('error') && data['error'] is Map<String, dynamic>) {
              final errorData = data['error'] as Map<String, dynamic>;
              if (errorData.containsKey('message')) {
                final message = errorData['message'];
                if (message is Map<String, dynamic>) {
                  // Validation error - format the message
                  final errors = <String>[];
                  message.forEach((key, value) {
                    if (value is List) {
                      errors.addAll(value.map((e) => e.toString()));
                    } else {
                      errors.add(value.toString());
                    }
                  });
                  return errors.join(', ');
                } else if (message is String) {
                  return message;
                }
              }
            }
            // Format 2: {error: true, message: "..."} - Backend'den gelen format
            else if (data.containsKey('error') && data.containsKey('message')) {
              final message = data['message'];
              if (message is String) {
                return message;
              }
            }
          }
          return 'Bir hata oluştu. Lütfen tekrar deneyin.';
      }
    }
    
    // Handle network errors
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Bağlantı zaman aşımına uğradı. İnternet bağlantınızı kontrol edin.';
    } else if (error.type == DioExceptionType.connectionError) {
      return 'İnternet bağlantınızı kontrol edin.';
    }
    
    return 'Bir hata oluştu. Lütfen tekrar deneyin.';
  }

  // Teacher Availability Methods
  Future<List<Map<String, dynamic>>> getTeacherAvailabilities(int teacherId) async {
    try {
      final response = await _dio.get('/teachers/$teacherId/availabilities');
      return List<Map<String, dynamic>>.from(response.data['data']);
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> getAvailableSlots(int teacherId, String date, {int? durationMinutes}) async {
    try {
      final queryParams = {
        'date': date,
        if (durationMinutes != null) 'duration': durationMinutes.toString(),
      };
      
      final response = await _dio.get('/teachers/$teacherId/available-slots', queryParameters: queryParams);
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> addTeacherAvailability(String dayOfWeek, String startTime, String endTime) async {
    try {
      final response = await _dio.post('/teacher/availabilities', data: {
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> updateTeacherAvailability(int id, String dayOfWeek, String startTime, String endTime) async {
    try {
      final response = await _dio.put('/teacher/availabilities/$id', data: {
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> deleteTeacherAvailability(int id) async {
    try {
      final response = await _dio.delete('/teacher/availabilities/$id');
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // Teacher Exceptions API Methods
  
  /// Get teacher exceptions (izin, tatil, özel günler)
  Future<List<Map<String, dynamic>>> getTeacherExceptions({String? type, String? filter}) async {
    try {
      final queryParams = <String, String>{};
      if (type != null) queryParams['type'] = type;
      if (filter != null) queryParams['filter'] = filter;
      
      final response = await _dio.get('/teacher/exceptions', queryParameters: queryParams);
      return List<Map<String, dynamic>>.from(response.data['data'] ?? []);
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  /// Add teacher exception
  Future<Map<String, dynamic>> addTeacherException({
    required String exceptionDate,
    required String type,
    String? startTime,
    String? endTime,
    String? reason,
    String? notes,
  }) async {
    try {
      final data = {
        'exception_date': exceptionDate,
        'type': type,
        if (startTime != null) 'start_time': startTime,
        if (endTime != null) 'end_time': endTime,
        if (reason != null) 'reason': reason,
        if (notes != null) 'notes': notes,
      };
      
      final response = await _dio.post('/teacher/exceptions', data: data);
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  /// Update teacher exception
  Future<Map<String, dynamic>> updateTeacherException(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/teacher/exceptions/$id', data: data);
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  /// Delete teacher exception
  Future<Map<String, dynamic>> deleteTeacherException(int id) async {
    try {
      final response = await _dio.delete('/teacher/exceptions/$id');
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  /// Add bulk unavailable days (tatil dönemi)
  Future<Map<String, dynamic>> addBulkUnavailableDays({
    required String startDate,
    required String endDate,
    required String reason,
    String? notes,
  }) async {
    try {
      final response = await _dio.post('/teacher/exceptions/bulk-unavailable', data: {
        'start_date': startDate,
        'end_date': endDate,
        'reason': reason,
        if (notes != null) 'notes': notes,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }


  Future<List<Teacher>> getTrendingTeachers() async {
    try {
      final response = await _dio.get('/search/trending');
      return (response.data['data'] as List)
          .map((json) => Teacher.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }




  Future<Map<String, dynamic>> updateLessonNotes({
    required int lessonId,
    required String notes,
  }) async {
    try {
      final response = await _dio.put('/lessons/notes', data: {
        'lesson_id': lessonId,
        'notes': notes,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> rateLesson({
    required int lessonId,
    required int rating,
    String? feedback,
  }) async {
    try {
      final response = await _dio.post('/lessons/rate', data: {
        'lesson_id': lessonId,
        'rating': rating,
        if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // User profile endpoints
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final response = await _dio.get('/user');
      return response.data['user'];
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> updateUserProfile(Map<String, dynamic> profileData) async {
    try {
      final response = await _dio.put('/user', data: profileData);
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    try {
      final response = await _dio.post('/user/change-password', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPasswordConfirmation,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> getUserStatistics() async {
    try {
      final response = await _dio.get('/user/statistics');
      return response.data['data'];
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<List<dynamic>> getUserActivityHistory({
    String? action,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };

      if (action != null && action.isNotEmpty) queryParams['action'] = action;
      if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;

      final response = await _dio.get('/user/activity-history', queryParameters: queryParams);
      return response.data['data'];
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> deleteUserAccount({
    required String password,
    required String confirmation,
  }) async {
    try {
      final response = await _dio.delete('/user/account', data: {
        'password': password,
        'confirmation': confirmation,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> exportUserData() async {
    try {
      final response = await _dio.get('/user/export-data');
      return response.data['data'];
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> getNotificationPreferences() async {
    try {
      final response = await _dio.get('/user/notification-preferences');
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> updateNotificationPreferences(Map<String, dynamic> preferences) async {
    try {
      final response = await _dio.put('/user/notification-preferences', data: preferences);
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> generatePresignedUrl(String filename, String contentType) async {
    try {
      final response = await _dio.post('/upload/presigned-url', data: {
        'filename': filename,
        'content_type': contentType,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> confirmUpload(String path, String filename, String fileType) async {
    try {
      final response = await _dio.post('/upload/confirm', data: {
        'path': path,
        'filename': filename,
        'file_type': fileType,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> uploadDocument(XFile file, String type) async {
    try {
      final formData = FormData.fromMap({
        'document': await MultipartFile.fromFile(
          file.path,
          filename: file.name,
        ),
        'type': type,
      });

      final response = await _dio.post('/upload/document', data: formData);
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }



  // Generic HTTP methods
  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await _dio.get(endpoint);
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(endpoint, data: data);
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(endpoint, data: data);
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final response = await _dio.delete(endpoint);
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // File upload method
  Future<Map<String, dynamic>> uploadFile(String endpoint, XFile file, Map<String, dynamic> data) async {
    try {
      final formData = FormData.fromMap({
        ...data,
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.name,
        ),
      });

      final response = await _dio.post(endpoint, data: formData);
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // ===== CHAT ADVANCED METHODS =====

  /// Send typing indicator
  Future<void> sendTypingIndicator(int receiverId, bool isTyping) async {
    if (kDebugMode) {
      print('⌨️ [TYPING_INDICATOR] Sending typing indicator to user: $receiverId');
    }
    
    try {
      await post('/chat/typing', {
        'receiver_id': receiverId,
        'is_typing': isTyping,
      });
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [TYPING_INDICATOR] Error: ${e.message}');
      }
      // Don't throw error for typing indicators
    }
  }

  /// Get message reactions
  Future<List<Map<String, dynamic>>> getMessageReactions(int messageId) async {
    if (kDebugMode) {
      print('⭐ [GET_REACTIONS] Getting reactions for message: $messageId');
    }
    
    try {
      final response = await _dio.get('/chat/messages/$messageId/reactions');
      return List<Map<String, dynamic>>.from(response.data['reactions'] ?? []);
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [GET_REACTIONS] Error: ${e.response?.data}');
      }
      throw Exception(handleError(e));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [GET_REACTIONS] Unexpected error: $e');
      }
      throw Exception('Reactions yüklenirken beklenmeyen bir hata oluştu');
    }
  }

  /// Upload and send file message
  Future<Message> uploadMessageFile(int chatId, XFile file, String type) async {
    if (kDebugMode) {
      print('📁 [UPLOAD_FILE] Uploading file to chat: $chatId');
    }
    
    try {
      final formData = FormData.fromMap({
        'chat_id': chatId,
        'type': type,
        'file': await MultipartFile.fromFile(file.path, filename: file.name),
      });
      
      final response = await _dio.post('/chat/upload-file', data: formData);
      return Message.fromJson(response.data['message']);
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [UPLOAD_FILE] Error: ${e.response?.data}');
      }
      throw Exception(handleError(e));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [UPLOAD_FILE] Unexpected error: $e');
      }
      throw Exception('Dosya yüklenirken beklenmeyen bir hata oluştu');
    }
  }

  /// Send voice message
  Future<Message> sendVoiceMessage(int chatId, XFile audioFile, int duration) async {
    if (kDebugMode) {
      print('🎤 [VOICE_MESSAGE] Sending voice message to chat: $chatId');
    }
    
    try {
      final formData = FormData.fromMap({
        'chat_id': chatId,
        'duration': duration,
        'audio_file': await MultipartFile.fromFile(
          audioFile.path,
          filename: audioFile.name,
        ),
      });
      
      final response = await _dio.post('/chat/voice-message', data: formData);
      return Message.fromJson(response.data['message']);
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  /// Send video call invitation
  Future<void> sendVideoCallInvitation(int chatId, String callType) async {
    if (kDebugMode) {
      print('📹 [VIDEO_CALL] Sending video call invitation to chat: $chatId');
    }
    
    try {
      await post('/chat/video-call', {
        'chat_id': chatId,
        'call_type': callType,
      });
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  /// Respond to video call
  Future<void> respondToVideoCall(int chatId, String response) async {
    if (kDebugMode) {
      print('📹 [VIDEO_CALL_RESPONSE] Responding to video call in chat: $chatId');
    }
    
    try {
      await post('/chat/video-call-response', {
        'chat_id': chatId,
        'response': response,
      });
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  /// Search messages in chat
  Future<List<Map<String, dynamic>>> searchMessages(int chatId, String query, {String? type, DateTime? dateFrom, DateTime? dateTo}) async {
    if (kDebugMode) {
      print('🔍 [SEARCH_MESSAGES] Searching messages in chat: $chatId');
    }
    
    try {
      final queryParams = <String, dynamic>{
        'chat_id': chatId,
        'query': query,
      };
      
      if (type != null) queryParams['type'] = type;
      if (dateFrom != null) queryParams['date_from'] = dateFrom.toIso8601String();
      if (dateTo != null) queryParams['date_to'] = dateTo.toIso8601String();
      
      final response = await _dio.get('/chat/search-messages', queryParameters: queryParams);
      return List<Map<String, dynamic>>.from(response.data['messages'] ?? []);
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [SEARCH_MESSAGES] Error: ${e.response?.data}');
      }
      throw Exception(handleError(e));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SEARCH_MESSAGES] Unexpected error: $e');
      }
      throw Exception('Mesaj arama sırasında beklenmeyen bir hata oluştu');
    }
  }

  /// Get chat statistics
  Future<Map<String, dynamic>> getChatStatistics(int chatId, {String period = '30d'}) async {
    if (kDebugMode) {
      print('📊 [CHAT_STATISTICS] Getting statistics for chat: $chatId');
    }
    
    try {
      final response = await _dio.get('/chat/statistics', queryParameters: {
        'chat_id': chatId,
        'period': period,
      });
      
      return response.data['statistics'] ?? {};
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // Set current user
  void setCurrentUser(User user) {
    _currentUser = user;
  }

  // Admin Notifications
  Future<Map<String, dynamic>> sendAdminNotification({
    required String title,
    required String message,
    required List<String> targetUsers,
    required String type,
  }) async {
    try {
      final response = await _dio.post('/admin/notifications/send', data: {
        'title': title,
        'message': message,
        'target_users': targetUsers,
        'type': type,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

}  
