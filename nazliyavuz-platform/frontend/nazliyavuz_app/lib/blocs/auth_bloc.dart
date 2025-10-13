import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

// Events
abstract class AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  
  AuthLoginRequested({required this.email, required this.password});
}

class AuthLogoutRequested extends AuthEvent {}

class AuthCheckRequested extends AuthEvent {}

class AuthRegisterRequested extends AuthEvent {
  final String name;
  final String email;
  final String password;
  final String passwordConfirmation;
  final String role;
  
  AuthRegisterRequested({
    required this.name,
    required this.email,
    required this.password,
    required this.passwordConfirmation,
    required this.role,
  });
}

class AuthRefreshRequested extends AuthEvent {
  AuthRefreshRequested();
}

// States
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final String token;
  final Map<String, dynamic> user;
  
  AuthAuthenticated({required this.token, required this.user});
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  
  AuthError({required this.message});
}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiService _apiService;
  
  AuthBloc(this._apiService) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthRegisterRequested>(_onAuthRegisterRequested);
    on<AuthRefreshRequested>(_onAuthRefreshRequested);
    
    // Check auth status on initialization
    add(AuthCheckRequested());
  }
  
  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(AuthLoading());
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token != null && token.isNotEmpty) {
        // Verify token with backend
        try {
          final user = await _apiService.getCurrentUser();
          if (kDebugMode) {
            print('🔍 [AUTH_BLOC] User data: $user');
            print('🖼️ [AUTH_BLOC] Profile photo URL: ${user['profile_photo_url']}');
          }
          emit(AuthAuthenticated(token: token, user: user));
        } catch (e) {
          // Token is invalid, clear it
          await prefs.remove('auth_token');
          emit(AuthUnauthenticated());
        }
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(message: 'Kimlik doğrulama kontrolü başarısız: $e'));
    }
  }
  
  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(AuthLoading());
      
      final response = await _apiService.login(
        email: event.email,
        password: event.password,
      );
      
      final token = response['token']['access_token'];
      final user = response['user'];
      
      // Save token
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      
      emit(AuthAuthenticated(token: token, user: user));
    } catch (e) {
      emit(AuthError(message: 'Giriş başarısız: $e'));
    }
  }
  
  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      // Clear token
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(message: 'Çıkış yapılırken hata oluştu: $e'));
    }
  }
  
  Future<void> _onAuthRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(AuthLoading());
      
      if (kDebugMode) {
        print('📝 [AUTH_BLOC] Starting registration...');
      }
      
      final response = await _apiService.register(
        name: event.name,
        email: event.email,
        password: event.password,
        passwordConfirmation: event.passwordConfirmation,
        role: event.role,
      );
      
      final token = response['token']['access_token'];
      final user = response['user'];
      
      // Save token
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      
      if (kDebugMode) {
        print('✅ [AUTH_BLOC] Registration successful!');
      }
      
      emit(AuthAuthenticated(token: token, user: user));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [AUTH_BLOC] Registration failed: $e');
      }
      
      // Parse error message to make it user-friendly
      String errorMessage = e.toString();
      
      // Remove "Exception: " prefix if present
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11);
      }
      
      // Check for common validation errors
      if (errorMessage.contains('password') && errorMessage.contains('at least')) {
        errorMessage = 'Şifre en az 8 karakter olmalıdır';
      } else if (errorMessage.contains('email') && errorMessage.contains('already')) {
        errorMessage = 'Bu e-posta adresi zaten kayıtlı';
      } else if (errorMessage.contains('password') && errorMessage.contains('confirmation')) {
        errorMessage = 'Şifreler eşleşmiyor';
      } else if (errorMessage.contains('validation') || errorMessage.contains('422')) {
        errorMessage = 'Lütfen tüm alanları doğru şekilde doldurun';
      }
      
      emit(AuthError(message: errorMessage));
    }
  }
  
  Future<void> _onAuthRefreshRequested(
    AuthRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      // Don't emit loading to prevent UI flickering
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token != null && token.isNotEmpty) {
        // Fetch fresh user data from backend
        final user = await _apiService.getCurrentUser();
        if (kDebugMode) {
          print('🔄 [AUTH_REFRESH] User data refreshed');
          print('🖼️ [AUTH_REFRESH] Profile photo URL: ${user['profile_photo_url']}');
        }
        emit(AuthAuthenticated(token: token, user: user));
      }
    } catch (e) {
      // Keep current state if refresh fails
      print('Auth refresh failed: $e');
    }
  }
}
