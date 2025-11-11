import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'services/api_service.dart';
import 'services/offline_service.dart';
import 'services/push_notification_service.dart';
import 'models/user.dart';
import 'theme/app_theme.dart';
import 'services/enhanced_features_service.dart';
import 'services/flutter_performance_service.dart';
import 'services/network_optimization_service.dart';
import 'services/asset_optimization_service.dart';
import 'services/state_optimization_service.dart';
import 'services/user_activity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Initialize Firebase Messaging background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    if (kDebugMode) {
      print('✅ Firebase initialized successfully');
    }
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ Firebase initialization failed: $e');
      print('⚠️ Push notifications will be disabled');
    }
  }
  
  // Initialize services
  await ThemeService.init();
  await AccessibilityService.init();
  await OfflineSyncService.init();
  
  // Initialize performance optimization services (optimized for better startup)
  try {
    FlutterPerformanceService().initialize();
    NetworkOptimizationService().initialize();
    AssetOptimizationService().initialize();
    StateOptimizationService().initialize();
    await OfflineService.init();
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ Performance services initialization failed: $e');
    }
  }
  
  // Initialize push notifications (only if Firebase is available)
  try {
    await PushNotificationService.initialize();
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ Push notification service failed to initialize: $e');
    }
  }
  
  // Initialize user activity service
  try {
    await UserActivityService().initialize();
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ User activity service failed to initialize: $e');
    }
  }
  
  // Initialize offline support
  // await OfflineSupportService.initialize(); // Service not available
  
  // Clear cache for category update
  await OfflineService.clearCacheForCategoryUpdate();
  
  runApp(const NazliyavuzApp());
}


/// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('🔔 [PUSH_NOTIFICATION] Background handler: ${message.messageId}');
  }
}

class NazliyavuzApp extends StatelessWidget {
  const NazliyavuzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc(ApiService()),
      child: MaterialApp(
        title: 'TERENCE EĞİTİM',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeService.themeMode,
        locale: const Locale('tr', ''),
        supportedLocales: const [
          Locale('tr', ''),
          Locale('en', ''),
          Locale('de', ''),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const AppNavigator(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(AccessibilityService.fontScale),
            ),
            child: child!,
          );
        },
      ),
    );
  }
}

class AppNavigator extends StatefulWidget {
  const AppNavigator({super.key});

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    UserActivityService().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        UserActivityService().setUserOnline();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        UserActivityService().setUserOffline();
        break;
      case AppLifecycleState.inactive:
        // Don't change status for inactive state
        break;
      case AppLifecycleState.hidden:
        UserActivityService().setUserOffline();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthInitial) {
          return const SplashScreen();
        } else if (state is AuthLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else if (state is AuthAuthenticated) {
          // Role-based routing
          if (state.user.role == 'admin') {
            return const AdminHomeScreen();
          } else {
            return const HomeScreen();
          }
        } else if (state is AuthEmailVerificationRequired) {
          return EmailVerificationScreen(
            email: state.email,
            verificationToken: state.verificationCode,
          );
        } else if (state is AuthUnauthenticated) {
          return const LoginScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

// Auth Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthUserChanged extends AuthEvent {
  final User user;
  
  const AuthUserChanged(this.user);
  
  @override
  List<Object?> get props => [user];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  
  const AuthLoginRequested({
    required this.email,
    required this.password,
  });
  
  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  final String name;
  final String email;
  final String password;
  final String passwordConfirmation;
  final String role;
  
  const AuthRegisterRequested({
    required this.name,
    required this.email,
    required this.password,
    required this.passwordConfirmation,
    required this.role,
  });
  
  @override
  List<Object?> get props => [name, email, password, passwordConfirmation, role];
}

class AuthLogout extends AuthEvent {
  const AuthLogout();
}

class AuthRefreshRequested extends AuthEvent {
  const AuthRefreshRequested();
}

class AuthUnauthorized extends AuthEvent {
  const AuthUnauthorized();
}

class AuthEmailVerified extends AuthEvent {
  const AuthEmailVerified();
}

// Auth Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiService _apiService;
  Map<String, dynamic>? _emailVerificationInfo;

  AuthBloc(this._apiService) : super(AuthInitial()) {
    on<AuthUserChanged>(_onUserChanged);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogout>(_onLogout);
    on<AuthRefreshRequested>(_onRefreshRequested);
    on<AuthUnauthorized>(_onUnauthorized);
    on<AuthEmailVerified>(_onEmailVerified);
    
    // Set up unauthorized callback
    _apiService.onUnauthorized = () {
      add(const AuthUnauthorized());
    };
    
    _checkAuthStatus();
  }

  void _onUserChanged(AuthUserChanged event, Emitter<AuthState> emit) {
    emit(AuthAuthenticated(event.user));
  }

  void _onLogoutRequested(AuthLogoutRequested event, Emitter<AuthState> emit) {
    emit(AuthUnauthenticated());
  }

  Future<void> _onLoginRequested(AuthLoginRequested event, Emitter<AuthState> emit) async {
    if (kDebugMode) {
      print('🔐 [AUTH_BLOC] Starting login process...');
      print('🔐 [AUTH_BLOC] Email: ${event.email}');
      print('🔐 [AUTH_BLOC] Password length: ${event.password.length}');
    }
    emit(AuthLoading());
    
    try {
      final response = await _apiService.login(
        email: event.email,
        password: event.password,
      );
      
      final user = User.fromJson(response['user']);
      if (kDebugMode) {
        print('✅ [AUTH_BLOC] Login successful: ${user.name}');
      }
      emit(AuthAuthenticated(user));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [AUTH_BLOC] Login failed: $e');
      }
      
      // Gelişmiş hata mesajları
      String errorMessage = 'Giriş sırasında bir hata oluştu';
      String? errorAction;
      
      if (e is DioException) {
        // API Service'teki handleError metodunu kullan
        errorMessage = _apiService.handleError(e);
        errorAction = 'Kayıt olmak için buraya tıklayın';
      } else if (e is Exception) {
        // API Service'ten gelen Exception mesajını kullan
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        errorAction = 'Kayıt olmak için buraya tıklayın';
      } else if (e.toString().contains('SocketException') || e.toString().contains('Network')) {
        errorMessage = 'İnternet bağlantınızı kontrol edin';
        errorAction = 'Tekrar dene';
      } else if (e.toString().contains('Timeout')) {
        errorMessage = 'Bağlantı zaman aşımına uğradı';
        errorAction = 'Tekrar dene';
      }
      
      if (kDebugMode) {
        print('🔐 [AUTH_BLOC] Emitting AuthError: $errorMessage');
        print('🔐 [AUTH_BLOC] Error action: $errorAction');
      }
      emit(AuthError(errorMessage, action: errorAction));
      
      if (kDebugMode) {
        print('🔐 [AUTH_BLOC] AuthError emitted successfully');
      }
    }
  }

  Future<void> _onRegisterRequested(AuthRegisterRequested event, Emitter<AuthState> emit) async {
    if (kDebugMode) {
      print('📝 [AUTH_BLOC] Starting registration process...');
      print('📝 [AUTH_BLOC] Name: ${event.name}');
      print('📝 [AUTH_BLOC] Email: ${event.email}');
      print('📝 [AUTH_BLOC] Role: ${event.role}');
    }
    emit(AuthLoading());
    
    try {
      final response = await _apiService.register(
        name: event.name,
        email: event.email,
        password: event.password,
        passwordConfirmation: event.passwordConfirmation,
        role: event.role,
      );
      
      if (kDebugMode) {
        print('✅ [AUTH_BLOC] Registration successful');
        print('✅ [AUTH_BLOC] Email verification info: ${response['email_verification']}');
      }
      
      // Store email verification info for UI
      _emailVerificationInfo = response['email_verification'];
      
      // Return response for handling in UI
      // Don't emit authenticated state here, let UI handle email verification
      emit(AuthUnauthenticated());
    } catch (e) {
      if (kDebugMode) {
        print('❌ [AUTH_BLOC] Registration failed: $e');
      }
      
      // Gelişmiş kayıt hata mesajları
      String errorMessage = 'Kayıt sırasında bir hata oluştu';
      String? errorAction;
      Map<String, String>? fieldErrors;
      
      if (e is DioException) {
        // API Service'teki handleError metodunu kullan
        errorMessage = _apiService.handleError(e);
        errorAction = 'Giriş yapmak için buraya tıklayın';
      } else if (e is Exception) {
        // API Service'ten gelen Exception mesajını kullan
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        errorAction = 'Giriş yapmak için buraya tıklayın';
      } else if (e.toString().contains('SocketException') || e.toString().contains('Network')) {
        errorMessage = 'İnternet bağlantınızı kontrol edin';
        errorAction = 'Tekrar dene';
      } else if (e.toString().contains('Timeout')) {
        errorMessage = 'Bağlantı zaman aşımına uğradı';
        errorAction = 'Tekrar dene';
      }
      
      emit(AuthRegistrationError(errorMessage, action: errorAction, fieldErrors: fieldErrors));
    }
  }

  Future<void> _onLogout(AuthLogout event, Emitter<AuthState> emit) async {
    if (kDebugMode) {
      print('🚪 [AUTH_BLOC] Logging out...');
    }
    
    try {
      await _apiService.logout();
      emit(AuthUnauthenticated());
    } catch (e) {
      if (kDebugMode) {
        print('❌ [AUTH_BLOC] Logout error: $e');
      }
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _checkAuthStatus() async {
    if (kDebugMode) {
      print('🔍 [AUTH_BLOC] Checking authentication status...');
    }
    
    try {
      // Load token from storage first
      await _apiService.loadTokenFromStorage();
      
      if (_apiService.isAuthenticated) {
        if (kDebugMode) {
          print('✅ [AUTH_BLOC] User is authenticated, fetching profile...');
        }
        try {
          final user = await _apiService.getProfile();
          if (kDebugMode) {
            print('✅ [AUTH_BLOC] Profile fetched successfully: ${user.name}');
          }
          add(AuthUserChanged(user));
        } catch (e) {
          if (kDebugMode) {
            print('❌ [AUTH_BLOC] Error fetching profile: $e');
            print('❌ [AUTH_BLOC] Clearing token and logging out...');
          }
          // If profile fetch fails (401, etc.), clear token and logout
          await _apiService.logout();
          add(const AuthLogoutRequested());
        }
      } else {
        if (kDebugMode) {
          print('❌ [AUTH_BLOC] User is not authenticated');
        }
        add(const AuthLogoutRequested());
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [AUTH_BLOC] Error checking auth status: $e');
      }
      add(const AuthLogoutRequested());
    }
  }

  // Getter for email verification info
  Map<String, dynamic>? get emailVerificationInfo => _emailVerificationInfo;

  Future<void> _onRefreshRequested(AuthRefreshRequested event, Emitter<AuthState> emit) async {
    await _checkAuthStatus();
  }

  Future<void> _onUnauthorized(AuthUnauthorized event, Emitter<AuthState> emit) async {
    if (kDebugMode) {
      print('🔓 [AUTH_BLOC] Unauthorized access detected - logging out');
    }
    
    // Eğer şu anda login işlemi devam ediyorsa (AuthLoading veya AuthError state'inde isek), 
    // logout işlemini yapmayalım çünkü login error'ı handle edilecek
    final currentState = state;
    if (kDebugMode) {
      print('🔓 [AUTH_BLOC] Current state in unauthorized: ${currentState.runtimeType}');
    }
    
    if (currentState is AuthLoading || currentState is AuthError) {
      if (kDebugMode) {
        print('🔓 [AUTH_BLOC] Login in progress or error state, skipping logout to preserve error handling');
      }
      return;
    }
    
    // Clear all auth data
    await _apiService.logout();
    
    // Show user-friendly message
    if (kDebugMode) {
      print('🔓 [AUTH_BLOC] Redirecting to login screen');
    }
    
    emit(AuthUnauthenticated());
  }

  Future<void> _onEmailVerified(AuthEmailVerified event, Emitter<AuthState> emit) async {
    if (kDebugMode) {
      print('✅ [AUTH_BLOC] Email verified - refreshing user data');
    }
    await _checkAuthStatus();
  }

}

// Auth States
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;

  const AuthAuthenticated(this.user);

  @override
  List<Object> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  final String? action;

  const AuthError(this.message, {this.action});

  @override
  List<Object?> get props => [message, action];
}

class AuthRegistrationError extends AuthState {
  final String message;
  final String? action;
  final Map<String, String>? fieldErrors;

  const AuthRegistrationError(this.message, {this.action, this.fieldErrors});

  @override
  List<Object?> get props => [message, action, fieldErrors];
}

class AuthEmailVerificationRequired extends AuthState {
  final String email;
  final String verificationCode;

  const AuthEmailVerificationRequired({
    required this.email,
    required this.verificationCode,
  });

  @override
  List<Object> get props => [email, verificationCode];
}
