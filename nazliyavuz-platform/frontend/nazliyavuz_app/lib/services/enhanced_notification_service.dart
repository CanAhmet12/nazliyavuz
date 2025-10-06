import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'api_service.dart';

/// Enhanced Notification Service with advanced features (Simplified Version)
class EnhancedNotificationService {
  static final EnhancedNotificationService _instance = EnhancedNotificationService._internal();
  factory EnhancedNotificationService() => _instance;
  EnhancedNotificationService._internal();

  final Map<String, StreamController<Map<String, dynamic>>> _streamControllers = {};
  bool _isInitialized = false;
  bool _permissionsGranted = false;
  late FlutterLocalNotificationsPlugin _localNotifications;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone
      tz.initializeTimeZones();
      
      // Initialize local notifications
      _localNotifications = FlutterLocalNotificationsPlugin();
      
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await _localNotifications.initialize(initSettings);
      
      // Request permissions
      await _requestPermissions();
      
      _isInitialized = true;
      debugPrint('✅ [NOTIFICATION_SERVICE] Initialized successfully');
    } catch (e) {
      debugPrint('❌ [NOTIFICATION_SERVICE] Initialization failed: $e');
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      // Android 13+ notification permission
      if (await Permission.notification.request().isGranted) {
        _permissionsGranted = true;
      }

      // iOS permissions are handled in initialization
      _permissionsGranted = true;
    } catch (e) {
      debugPrint('Permission request error: $e');
      _permissionsGranted = false;
    }
  }

  /// Show chat message notification (simplified)
  Future<void> showChatNotification({
    required String title,
    required String body,
    required String senderName,
    required int senderId,
    int? chatId,
    String? imageUrl,
    Map<String, dynamic>? data,
  }) async {
    if (!_permissionsGranted) return;

    try {
      // TODO: Show actual notification when flutter_local_notifications package is added
      debugPrint('Chat notification: $title - $body');
      
      // Send to stream
      _streamControllers['chat-notifications']?.add({
        'type': 'chat',
        'title': title,
        'body': body,
        'sender_id': senderId,
        'sender_name': senderName,
        'chat_id': chatId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Show chat notification error: $e');
    }
  }

  /// Show video call notification (simplified)
  Future<void> showVideoCallNotification({
    required String callerName,
    required int callerId,
    required String callType,
    String? callId,
  }) async {
    if (!_permissionsGranted) return;

    try {
      // TODO: Show actual notification when flutter_local_notifications package is added
      debugPrint('Video call notification: $callerName is calling');
      
      // Send to stream
      _streamControllers['call-notifications']?.add({
        'type': 'call',
        'caller_name': callerName,
        'caller_id': callerId,
        'call_type': callType,
        'call_id': callId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Show video call notification error: $e');
    }
  }

  /// Show reservation notification (simplified)
  Future<void> showReservationNotification({
    required String title,
    required String body,
    required String type,
    required int reservationId,
    Map<String, dynamic>? data,
  }) async {
    if (!_permissionsGranted) return;

    try {
      // TODO: Show actual notification when flutter_local_notifications package is added
      debugPrint('Reservation notification: $title - $body');
      
      // Send to stream
      _streamControllers['reservation-notifications']?.add({
        'type': 'reservation',
        'title': title,
        'body': body,
        'reservation_type': type,
        'reservation_id': reservationId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Show reservation notification error: $e');
    }
  }

  /// Show assignment notification (simplified)
  Future<void> showAssignmentNotification({
    required String title,
    required String body,
    required String type,
    required int assignmentId,
    Map<String, dynamic>? data,
  }) async {
    if (!_permissionsGranted) return;

    try {
      // Show actual notification
      await _localNotifications.show(
        assignmentId,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'assignment_channel',
            'Assignment Notifications',
            channelDescription: 'Notifications for assignment activities',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode({
          'type': 'assignment',
          'assignment_id': assignmentId,
          'assignment_type': type,
          ...?data,
        }),
      );
      
      // Send to stream
      _streamControllers['assignment-notifications']?.add({
        'type': 'assignment',
        'title': title,
        'body': body,
        'assignment_type': type,
        'assignment_id': assignmentId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Show assignment notification error: $e');
    }
  }

  /// Show system notification (simplified)
  Future<void> showSystemNotification({
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    if (!_permissionsGranted) return;

    try {
      // Show actual notification
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'system_channel',
            'System Notifications',
            channelDescription: 'System and general notifications',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode({
          'type': 'system',
          'system_type': type,
          ...?data,
        }),
      );
      
      // Send to stream
      _streamControllers['system-notifications']?.add({
        'type': 'system',
        'title': title,
        'body': body,
        'system_type': type,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Show system notification error: $e');
    }
  }

  /// Schedule notification (simplified)
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? channelId,
    Map<String, dynamic>? data,
  }) async {
    if (!_permissionsGranted) return;

    try {
      // Implement scheduled notifications
      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'scheduled_channel',
            'Scheduled Notifications',
            channelDescription: 'Scheduled notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode({
          'type': 'scheduled',
          'scheduled_date': scheduledDate.toIso8601String(),
          ...?data,
        }),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Schedule notification error: $e');
    }
  }

  /// Cancel notification (simplified)
  Future<void> cancelNotification(int id) async {
    try {
      // Cancel actual notification
      await _localNotifications.cancel(id);
    } catch (e) {
      debugPrint('Cancel notification error: $e');
    }
  }

  /// Cancel all notifications (simplified)
  Future<void> cancelAllNotifications() async {
    try {
      // Cancel all actual notifications
      await _localNotifications.cancelAll();
    } catch (e) {
      debugPrint('Cancel all notifications error: $e');
    }
  }

  /// Get pending notifications (simplified)
  Future<List<Map<String, dynamic>>> getPendingNotifications() async {
    try {
      // Get actual pending notifications
      final pendingNotifications = await _localNotifications.pendingNotificationRequests();
      return pendingNotifications.map((notification) => {
        'id': notification.id,
        'title': notification.title,
        'body': notification.body,
        'payload': notification.payload,
      }).toList();
    } catch (e) {
      debugPrint('Get pending notifications error: $e');
      return [];
    }
  }

  /// Set notification badge count (simplified)
  Future<void> setBadgeCount(int count) async {
    try {
      // Set actual badge count (Android only)
      // Note: setNotificationCount method may not be available in all versions
      debugPrint('Set badge count: $count (Android badge count not implemented)');
    } catch (e) {
      debugPrint('Set badge count error: $e');
    }
  }

  /// Get notification streams
  Stream<Map<String, dynamic>> getChatNotificationsStream() {
    if (!_streamControllers.containsKey('chat-notifications')) {
      _streamControllers['chat-notifications'] = StreamController<Map<String, dynamic>>.broadcast();
    }
    return _streamControllers['chat-notifications']!.stream;
  }

  Stream<Map<String, dynamic>> getCallNotificationsStream() {
    if (!_streamControllers.containsKey('call-notifications')) {
      _streamControllers['call-notifications'] = StreamController<Map<String, dynamic>>.broadcast();
    }
    return _streamControllers['call-notifications']!.stream;
  }

  Stream<Map<String, dynamic>> getReservationNotificationsStream() {
    if (!_streamControllers.containsKey('reservation-notifications')) {
      _streamControllers['reservation-notifications'] = StreamController<Map<String, dynamic>>.broadcast();
    }
    return _streamControllers['reservation-notifications']!.stream;
  }

  Stream<Map<String, dynamic>> getAssignmentNotificationsStream() {
    if (!_streamControllers.containsKey('assignment-notifications')) {
      _streamControllers['assignment-notifications'] = StreamController<Map<String, dynamic>>.broadcast();
    }
    return _streamControllers['assignment-notifications']!.stream;
  }

  Stream<Map<String, dynamic>> getSystemNotificationsStream() {
    if (!_streamControllers.containsKey('system-notifications')) {
      _streamControllers['system-notifications'] = StreamController<Map<String, dynamic>>.broadcast();
    }
    return _streamControllers['system-notifications']!.stream;
  }

  Stream<Map<String, dynamic>> getNotificationTapsStream() {
    if (!_streamControllers.containsKey('notification-taps')) {
      _streamControllers['notification-taps'] = StreamController<Map<String, dynamic>>.broadcast();
    }
    return _streamControllers['notification-taps']!.stream;
  }

  /// Get notification settings
  Future<Map<String, dynamic>> getNotificationSettings() async {
    try {
      final response = await ApiService().get('/notifications/settings');

      if (response['success']) {
        return response['settings'] ?? {};
      }
      return {};
    } catch (e) {
      debugPrint('Get notification settings error: $e');
      return {};
    }
  }

  /// Update notification settings
  Future<bool> updateNotificationSettings(Map<String, dynamic> settings) async {
    try {
      final response = await ApiService().post('/notifications/settings', settings);

      return response['success'] ?? false;
    } catch (e) {
      debugPrint('Update notification settings error: $e');
      return false;
    }
  }

  /// Get notification history
  Future<List<Map<String, dynamic>>> getNotificationHistory({
    int page = 1,
    int limit = 20,
    String? type,
  }) async {
    try {
      final response = await ApiService().get('/notifications/history?page=$page&limit=$limit&type=${type ?? ''}');

      if (response['success']) {
        return List<Map<String, dynamic>>.from(response['notifications'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Get notification history error: $e');
      return [];
    }
  }

  /// Mark notification as read
  Future<bool> markNotificationAsRead(int notificationId) async {
    try {
      final response = await ApiService().post('/notifications/mark-read', {
        'notification_id': notificationId,
      });

      return response['success'] ?? false;
    } catch (e) {
      debugPrint('Mark notification as read error: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllNotificationsAsRead() async {
    try {
      final response = await ApiService().post('/notifications/mark-all-read', {});

      return response['success'] ?? false;
    } catch (e) {
      debugPrint('Mark all notifications as read error: $e');
      return false;
    }
  }

  /// Get unread notification count
  Future<int> getUnreadNotificationCount() async {
    try {
      final response = await ApiService().get('/notifications/unread-count');

      if (response['success']) {
        return response['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('Get unread notification count error: $e');
      return 0;
    }
  }

  /// Check if permissions are granted
  bool get arePermissionsGranted => _permissionsGranted;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose resources
  void dispose() {
    _streamControllers.values.forEach((controller) => controller.close());
    _streamControllers.clear();
  }
}