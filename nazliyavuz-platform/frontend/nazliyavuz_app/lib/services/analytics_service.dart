import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final ApiService _apiService = ApiService();
  SharedPreferences? _prefs;

  /// Initialize analytics service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Track user action/event
  Future<void> trackEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
    String? userId,
  }) async {
    try {
      final eventData = {
        'event_name': eventName,
        'parameters': parameters ?? {},
        'user_id': userId,
        'timestamp': DateTime.now().toIso8601String(),
        'platform': defaultTargetPlatform.name,
        'session_id': await _getSessionId(),
      };

      // Store locally for offline analytics
      await _storeEventLocally(eventData);

      // Send to backend (if online)
      if (await _isOnline()) {
        await _sendEventToBackend(eventData);
      }
    } catch (e) {
      debugPrint('Analytics tracking error: $e');
    }
  }

  /// Track screen view
  Future<void> trackScreenView({
    required String screenName,
    String? screenClass,
    Map<String, dynamic>? parameters,
    String? userId,
  }) async {
    await trackEvent(
      eventName: 'screen_view',
      parameters: {
        'screen_name': screenName,
        'screen_class': screenClass ?? screenName,
        ...?parameters,
      },
      userId: userId,
    );
  }

  /// Track user engagement
  Future<void> trackEngagement({
    required String action,
    String? target,
    Map<String, dynamic>? parameters,
    String? userId,
  }) async {
    await trackEvent(
      eventName: 'engagement',
      parameters: {
        'action': action,
        'target': target,
        ...?parameters,
      },
      userId: userId,
    );
  }

  /// Track performance metrics
  Future<void> trackPerformance({
    required String metricName,
    required double value,
    String? unit,
    Map<String, dynamic>? parameters,
    String? userId,
  }) async {
    await trackEvent(
      eventName: 'performance',
      parameters: {
        'metric_name': metricName,
        'value': value,
        'unit': unit,
        ...?parameters,
      },
      userId: userId,
    );
  }

  /// Track error
  Future<void> trackError({
    required String errorMessage,
    String? errorCode,
    String? stackTrace,
    Map<String, dynamic>? parameters,
    String? userId,
  }) async {
    await trackEvent(
      eventName: 'error',
      parameters: {
        'error_message': errorMessage,
        'error_code': errorCode,
        'stack_trace': stackTrace,
        ...?parameters,
      },
      userId: userId,
    );
  }

  /// Track business events
  Future<void> trackBusinessEvent({
    required String eventType,
    required String eventCategory,
    Map<String, dynamic>? parameters,
    String? userId,
  }) async {
    await trackEvent(
      eventName: 'business_event',
      parameters: {
        'event_type': eventType,
        'event_category': eventCategory,
        ...?parameters,
      },
      userId: userId,
    );
  }

  /// Get analytics data
  Future<Map<String, dynamic>?> getAnalyticsData({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _apiService.get('/analytics/data');
      
      return response['data'];
    } catch (e) {
      debugPrint('Analytics data fetch error: $e');
      return null;
    }
  }

  /// Get user analytics summary
  Future<Map<String, dynamic>?> getUserAnalyticsSummary(String userId) async {
    try {
      final response = await _apiService.get('/analytics/user/$userId/summary');
      return response['data'];
    } catch (e) {
      debugPrint('User analytics summary error: $e');
      return null;
    }
  }

  /// Store event locally for offline tracking
  Future<void> _storeEventLocally(Map<String, dynamic> eventData) async {
    if (_prefs == null) return;

    try {
      final events = _prefs!.getStringList('analytics_events') ?? [];
      events.add(eventData.toString());
      
      // Keep only last 100 events to prevent storage bloat
      if (events.length > 100) {
        events.removeRange(0, events.length - 100);
      }
      
      await _prefs!.setStringList('analytics_events', events);
    } catch (e) {
      debugPrint('Local analytics storage error: $e');
    }
  }

  /// Send event to backend
  Future<void> _sendEventToBackend(Map<String, dynamic> eventData) async {
    try {
      await _apiService.post('/analytics/track', eventData);
    } catch (e) {
      debugPrint('Backend analytics error: $e');
    }
  }

  /// Get or create session ID
  Future<String> _getSessionId() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }

    String? sessionId = _prefs!.getString('analytics_session_id');
    if (sessionId == null) {
      sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      await _prefs!.setString('analytics_session_id', sessionId);
    }

    return sessionId;
  }

  /// Check if device is online
  Future<bool> _isOnline() async {
    try {
      final response = await _apiService.get('/health');
      return response['status'] == 'ok';
    } catch (e) {
      return false;
    }
  }

  /// Sync offline events to backend
  Future<void> syncOfflineEvents() async {
    if (_prefs == null) return;

    try {
      final events = _prefs!.getStringList('analytics_events') ?? [];
      if (events.isEmpty) return;

      // Send all offline events
      for (final eventString in events) {
        try {
          // Parse and send each event
          final eventData = Map<String, dynamic>.from(eventString as Map);
          await _sendEventToBackend(eventData);
        } catch (e) {
          debugPrint('Offline event sync error: $e');
        }
      }

      // Clear offline events after successful sync
      await _prefs!.remove('analytics_events');
    } catch (e) {
      debugPrint('Offline sync error: $e');
    }
  }

  /// Clear all analytics data
  Future<void> clearAnalyticsData() async {
    if (_prefs == null) return;

    try {
      await _prefs!.remove('analytics_events');
      await _prefs!.remove('analytics_session_id');
    } catch (e) {
      debugPrint('Clear analytics error: $e');
    }
  }

  /// Get analytics summary from local storage
  Future<Map<String, dynamic>> getLocalAnalyticsSummary() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }

    final events = _prefs!.getStringList('analytics_events') ?? [];
    
    return {
      'total_events': events.length,
      'offline_events': events.length,
      'last_sync': _prefs!.getString('last_analytics_sync'),
      'session_id': _prefs!.getString('analytics_session_id'),
    };
  }
}
