import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

/**
 * User Activity Service
 * Handles real-time user activity tracking and online status management
 */
class UserActivityService {
  static final UserActivityService _instance = UserActivityService._internal();
  factory UserActivityService() => _instance;
  UserActivityService._internal();

  final ApiService _apiService = ApiService();
  Timer? _activityTimer;
  Timer? _heartbeatTimer;
  bool _isOnline = false;
  bool _isInitialized = false;

  /// Initialize user activity tracking
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Set user as online
      await setUserOnline();
      
      // Start activity tracking
      _startActivityTracking();
      
      // Start heartbeat
      _startHeartbeat();
      
      _isInitialized = true;
      
      debugPrint('✅ UserActivityService initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize UserActivityService: $e');
    }
  }

  /// Set user as online
  Future<void> setUserOnline() async {
    try {
      await _apiService.updateUserOnlineStatus(true);
      _isOnline = true;
      
      debugPrint('✅ User set as online');
    } catch (e) {
      debugPrint('❌ Failed to set user online: $e');
    }
  }

  /// Set user as offline
  Future<void> setUserOffline() async {
    try {
      await _apiService.updateUserOnlineStatus(false);
      _isOnline = false;
      
      debugPrint('✅ User set as offline');
    } catch (e) {
      debugPrint('❌ Failed to set user offline: $e');
    }
  }

  /// Update user activity
  Future<void> updateActivity() async {
    try {
      await _apiService.updateUserActivity();
      
      if (!_isOnline) {
        await setUserOnline();
      }
      
      debugPrint('✅ User activity updated');
    } catch (e) {
      debugPrint('❌ Failed to update user activity: $e');
    }
  }

  /// Start activity tracking
  void _startActivityTracking() {
    _activityTimer?.cancel();
    _activityTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      updateActivity();
    });
  }

  /// Start heartbeat
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      updateActivity();
    });
  }

  /// Stop activity tracking
  void stop() {
    _activityTimer?.cancel();
    _heartbeatTimer?.cancel();
    _isInitialized = false;
  }

  /// Dispose resources
  void dispose() {
    stop();
    setUserOffline();
  }

  /// Get current online status
  bool get isOnline => _isOnline;

  /// Get initialization status
  bool get isInitialized => _isInitialized;
}
