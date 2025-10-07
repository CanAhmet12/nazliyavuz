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
import '../models/assignment.dart';
import '../models/lesson.dart';

class ApiService {
  static const String baseUrl = 'http://34.122.224.35:8000/api/v1';  // VM Backend External IP
  late Dio _dio;
  String? _token;
  
  // Callback for unauthorized access
  Function()? onUnauthorized;
  final Map<String, dynamic> _cache = {};
  
  // Performance optimization
  Timer? _cacheCleanupTimer;

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
        handler.next(response);
      },
      onError: (error, handler) async {
        if (kDebugMode) {
          print('❌ [API_ERROR] ${error.requestOptions.path} - ${error.response?.statusCode}: ${error.message}');
        }
        
        if (error.response?.statusCode == 401) {
          if (kDebugMode) {
            print('🔓 [API_ERROR] Unauthorized - clearing token');
          }
          await _clearToken();
          // Notify AuthBloc about unauthorized access
          _currentUser = null;
          if (onUnauthorized != null) {
            onUnauthorized!();
          }
        }
        handler.next(error);
      },
    ));

    _initializeAuth();
    _startCacheCleanup();
  }

  Future<void> _initializeAuth() async {
    await _loadToken();
    if (kDebugMode) {
      print('🔑 [API_SERVICE] Auth initialization complete. Token: ${_token != null ? "EXISTS" : "NULL"}');
    }
  }

  void _startCacheCleanup() {
    _cacheCleanupTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _cleanupCache();
    });
  }

  void _cleanupCache() {
    if (kDebugMode) {
      print('🧹 [CACHE_CLEANUP] Cleaning up expired cache entries...');
    }
    
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    _cache.forEach((key, value) {
      if (value is Map<String, dynamic> && value.containsKey('expires_at')) {
        final expiresAt = DateTime.parse(value['expires_at']);
        if (now.isAfter(expiresAt)) {
          keysToRemove.add(key);
        }
      }
    });
    
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
    
    if (kDebugMode && keysToRemove.isNotEmpty) {
      print('🧹 [CACHE_CLEANUP] Removed ${keysToRemove.length} expired cache entries');
    }
  }

  void dispose() {
    _cacheCleanupTimer?.cancel();
    _cache.clear();
  }

  Future<void> _loadToken() async {
    if (kDebugMode) {
      print('🔑 [API_SERVICE] Loading token from SharedPreferences...');
    }
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    if (kDebugMode) {
      print('🔑 [API_SERVICE] Token loaded: ${_token != null ? "EXISTS" : "NULL"}');
    }
  }

  bool get isAuthenticated => _token != null;
  
  User? _currentUser;
  User? get currentUser => _currentUser;
  
  int get currentUserId => _currentUser?.id ?? 0;

  Future<void> _saveToken(String token) async {
    if (kDebugMode) {
      print('💾 [API_SERVICE] Saving token to SharedPreferences...');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    _token = token;
    if (kDebugMode) {
      print('💾 [API_SERVICE] Token saved successfully');
    }
  }

  Future<void> _clearToken() async {
    if (kDebugMode) {
      print('🗑️ [API_SERVICE] Clearing token from SharedPreferences...');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _token = null;
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
    }
    
    try {
      final requestData = {
        'access_token': accessToken,
        if (idToken != null) 'id_token': idToken,
      };
      
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
      await _saveToken(token);
      
      // Token süresini kaydet (opsiyonel - gelecekte kullanılabilir)
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
    try {
      final response = await _dio.post('/auth/refresh');
      final token = response.data['token']['access_token'];
      await _saveToken(token);
      return response.data;
    } on DioException catch (e) {
      throw Exception(handleError(e));
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
      throw Exception('Öğretmen profili oluşturulurken bir hata oluştu: $e');
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
      if (level != null) queryParams['level'] = level;
      if (priceMin != null && priceMin > 0) queryParams['price_min'] = priceMin;
      if (priceMax != null && priceMax < 1000) queryParams['price_max'] = priceMax;
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
      throw Exception('Öğretmen arama sırasında bir hata oluştu: $e');
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


  // Profile photo endpoints
  Future<void> updateProfilePhoto(XFile image) async {
    try {
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(
          image.path,
          filename: image.name,
        ),
      });
      
      await _dio.post('/profile/photo', data: formData);
    } on DioException catch (e) {
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
        'receiver_id': receiverId,
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
    
    if (error.response != null) {
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
        return 'Bir hata oluştu';
      }
      
      // Handle specific HTTP status codes with better messages
      switch (error.response!.statusCode) {
        case 400:
          return 'Geçersiz istek. Lütfen bilgilerinizi kontrol edin';
        case 401:
          return 'E-posta adresi veya şifre hatalı';
        case 403:
          return 'Erişim reddedildi';
        case 404:
          return 'Bu e-posta adresi sistemde kayıtlı değil';
        case 409:
          return 'Bu e-posta adresi zaten kayıtlı';
        case 422:
          return 'Doğrulama hatası. Lütfen bilgilerinizi kontrol edin';
        case 429:
          return 'Çok fazla istek gönderildi. Lütfen birkaç dakika bekleyin';
        case 500:
          return 'Sunucu hatası. Lütfen daha sonra tekrar deneyin';
        case 502:
          return 'Geçici sunucu hatası';
        case 503:
          return 'Servis kullanılamıyor';
        default:
          return 'Sunucu hatası: ${error.response!.statusCode}';
      }
    } else if (error.type == DioExceptionType.connectionTimeout) {
      return 'Bağlantı zaman aşımına uğradı. İnternet bağlantınızı kontrol edin';
    } else if (error.type == DioExceptionType.receiveTimeout) {
      return 'Sunucudan yanıt alınamadı. İnternet bağlantınızı kontrol edin';
    } else if (error.type == DioExceptionType.sendTimeout) {
      return 'Veri gönderilemedi. İnternet bağlantınızı kontrol edin';
    } else if (error.type == DioExceptionType.connectionError) {
      return 'İnternet bağlantınızı kontrol edin';
    } else if (error.type == DioExceptionType.badResponse) {
      return 'Sunucudan geçersiz yanıt alındı';
    } else if (error.type == DioExceptionType.cancel) {
      return 'İstek iptal edildi';
    } else if (error.message?.contains('SocketException') == true || 
               error.message?.contains('Network is unreachable') == true ||
               error.message?.contains('No Internet') == true) {
      return 'İnternet bağlantınızı kontrol edin';
    } else {
      return 'Ağ hatası. İnternet bağlantınızı kontrol edin';
    }
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

  Future<List<Map<String, dynamic>>> getAvailableSlots(int teacherId, String date) async {
    try {
      final response = await _dio.get('/teachers/$teacherId/available-slots', queryParameters: {
        'date': date,
      });
      return List<Map<String, dynamic>>.from(response.data['data']);
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
      return response.data['data'];
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
