import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final ApiService _apiService = ApiService();
  
  static String? _fcmToken;
  
  /// Initialize push notifications
  static Future<void> initialize() async {
    if (kDebugMode) {
      print('🔔 [PUSH_NOTIFICATION] Initializing push notifications...');
    }
    
    try {
      // Request permission
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      if (kDebugMode) {
        print('🔔 [PUSH_NOTIFICATION] Permission status: ${settings.authorizationStatus}');
      }
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // Get FCM token
        _fcmToken = await _firebaseMessaging.getToken();
        if (kDebugMode) {
          print('🔔 [PUSH_NOTIFICATION] FCM Token: $_fcmToken');
        }
        
        // Register token with backend
        if (_fcmToken != null) {
          await _registerToken(_fcmToken!);
        }
        
        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          if (kDebugMode) {
            print('🔔 [PUSH_NOTIFICATION] Token refreshed: $newToken');
          }
          _fcmToken = newToken;
          _registerToken(newToken);
        });
        
        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        
        // Handle background messages
        FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
        
        // Handle notification tap when app is terminated
        RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
        if (initialMessage != null) {
          _handleBackgroundMessage(initialMessage);
        }
        
        if (kDebugMode) {
          print('✅ [PUSH_NOTIFICATION] Push notifications initialized successfully!');
        }
      } else {
        if (kDebugMode) {
          print('❌ [PUSH_NOTIFICATION] Push notification permission denied');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [PUSH_NOTIFICATION] Error initializing push notifications: $e');
      }
    }
  }
  
  /// Register FCM token with backend
  static Future<void> _registerToken(String token) async {
    try {
      await _apiService.registerPushToken(token);
      if (kDebugMode) {
        print('✅ [PUSH_NOTIFICATION] Token registered with backend');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [PUSH_NOTIFICATION] Error registering token: $e');
      }
    }
  }
  
  /// Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('🔔 [PUSH_NOTIFICATION] Foreground message received: ${message.messageId}');
      print('🔔 [PUSH_NOTIFICATION] Title: ${message.notification?.title}');
      print('🔔 [PUSH_NOTIFICATION] Body: ${message.notification?.body}');
      print('🔔 [PUSH_NOTIFICATION] Data: ${message.data}');
    }
    
    // Show local notification or update UI
    // This will be handled by the UI layer
  }
  
  /// Handle background messages
  static void _handleBackgroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('🔔 [PUSH_NOTIFICATION] Background message received: ${message.messageId}');
      print('🔔 [PUSH_NOTIFICATION] Title: ${message.notification?.title}');
      print('🔔 [PUSH_NOTIFICATION] Body: ${message.notification?.body}');
      print('🔔 [PUSH_NOTIFICATION] Data: ${message.data}');
    }
    
    // Navigate to specific screen based on message data
    // This will be handled by the UI layer
  }
  
  /// Get current FCM token
  static String? get fcmToken => _fcmToken;
  
  /// Unregister token
  static Future<void> unregisterToken() async {
    try {
      if (_fcmToken != null) {
        await _apiService.unregisterPushToken(_fcmToken!);
        if (kDebugMode) {
          print('✅ [PUSH_NOTIFICATION] Token unregistered from backend');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [PUSH_NOTIFICATION] Error unregistering token: $e');
      }
    }
  }
}

