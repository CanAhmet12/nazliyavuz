import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_service.dart';

/// Enhanced Video Call Service with WebRTC-like functionality
class EnhancedVideoCallService {
  static final EnhancedVideoCallService _instance = EnhancedVideoCallService._internal();
  factory EnhancedVideoCallService() => _instance;
  EnhancedVideoCallService._internal();

  PusherChannelsFlutter? _pusher;
  final Map<String, StreamController<Map<String, dynamic>>> _streamControllers = {};
  bool _isConnected = false;
  bool _isInCall = false;
  String? _currentCallId;
  String? _currentCallType;

  // Configuration
  static const String _pusherKey = 'your_pusher_key';
  static const String _pusherCluster = 'eu';

  /// Initialize enhanced video call service
  Future<void> initialize() async {
    try {
      _pusher = PusherChannelsFlutter.getInstance();
      
      await _pusher!.init(
        apiKey: _pusherKey,
        cluster: _pusherCluster,
        onError: (String message, int? code, dynamic e) {
          debugPrint('Video Call Service Error: $message');
        },
        onConnectionStateChange: (String currentState, String previousState) {
          debugPrint('Video Call Service Connection State: $currentState');
          _isConnected = currentState == 'connected';
        },
      );

      await _pusher!.connect();
    } catch (e) {
      debugPrint('Video Call Service initialization error: $e');
    }
  }

  /// Request camera and microphone permissions
  Future<bool> requestPermissions() async {
    try {
      final cameraStatus = await Permission.camera.request();
      final microphoneStatus = await Permission.microphone.request();
      
      return cameraStatus.isGranted && microphoneStatus.isGranted;
    } catch (e) {
      debugPrint('Permission request error: $e');
      return false;
    }
  }

  /// Start a video call
  Future<Map<String, dynamic>> startVideoCall({
    required int receiverId,
    required String callType, // 'video' or 'audio'
    String? subject,
    int? reservationId,
  }) async {
    if (!_isConnected) {
      throw Exception('Video call service not connected');
    }

    // Request permissions
    final hasPermissions = await requestPermissions();
    if (!hasPermissions) {
      throw Exception('Camera and microphone permissions required');
    }

    try {
      _currentCallId = 'call_${DateTime.now().millisecondsSinceEpoch}';
      _currentCallType = callType;
      _isInCall = true;

      final response = await ApiService().post('/video-call/start', {
        'receiver_id': receiverId,
        'call_type': callType,
        'call_id': _currentCallId,
        'subject': subject,
        'reservation_id': reservationId,
      });

      if (response['success']) {
        // Subscribe to call channel
        await _subscribeToCallChannel(_currentCallId!);
        
        return {
          'success': true,
          'call_id': _currentCallId,
          'call_type': callType,
          'message': 'Video call started successfully',
        };
      } else {
        throw Exception(response['message'] ?? 'Failed to start video call');
      }
    } catch (e) {
      _isInCall = false;
      _currentCallId = null;
      _currentCallType = null;
      rethrow;
    }
  }

  /// Answer an incoming call
  Future<Map<String, dynamic>> answerCall({
    required String callId,
    required String callType,
  }) async {
    if (!_isConnected) {
      throw Exception('Video call service not connected');
    }

    // Request permissions
    final hasPermissions = await requestPermissions();
    if (!hasPermissions) {
      throw Exception('Camera and microphone permissions required');
    }

    try {
      _currentCallId = callId;
      _currentCallType = callType;
      _isInCall = true;

      final response = await ApiService().post('/video-call/answer', {
        'call_id': callId,
        'call_type': callType,
      });

      if (response['success']) {
        // Subscribe to call channel
        await _subscribeToCallChannel(callId);
        
        return {
          'success': true,
          'call_id': callId,
          'call_type': callType,
          'message': 'Call answered successfully',
        };
      } else {
        throw Exception(response['message'] ?? 'Failed to answer call');
      }
    } catch (e) {
      _isInCall = false;
      _currentCallId = null;
      _currentCallType = null;
      rethrow;
    }
  }

  /// Reject an incoming call
  Future<Map<String, dynamic>> rejectCall({
    required String callId,
    String? reason,
  }) async {
    try {
      await ApiService().post('/video-call/reject', {
        'call_id': callId,
        'reason': reason ?? 'User rejected the call',
      });

      return {
        'success': true,
        'message': 'Call rejected successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to reject call: $e',
      };
    }
  }

  /// End the current call
  Future<Map<String, dynamic>> endCall({
    String? reason,
    int? duration,
  }) async {
    if (_currentCallId == null) {
      return {
        'success': false,
        'message': 'No active call to end',
      };
    }

    try {
      await ApiService().post('/video-call/end', {
        'call_id': _currentCallId,
        'reason': reason ?? 'Call ended by user',
        'duration': duration,
      });

      // Unsubscribe from call channel
      await _unsubscribeFromCallChannel(_currentCallId!);

      // Reset call state
      _isInCall = false;
      _currentCallId = null;
      _currentCallType = null;

      return {
        'success': true,
        'message': 'Call ended successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to end call: $e',
      };
    }
  }

  /// Toggle microphone mute
  Future<void> toggleMute() async {
    if (_currentCallId == null) return;

    try {
      await ApiService().post('/video-call/toggle-mute', {
        'call_id': _currentCallId,
      });
    } catch (e) {
      debugPrint('Toggle mute error: $e');
    }
  }

  /// Toggle video on/off
  Future<void> toggleVideo() async {
    if (_currentCallId == null || _currentCallType != 'video') return;

    try {
      await ApiService().post('/video-call/toggle-video', {
        'call_id': _currentCallId,
      });
    } catch (e) {
      debugPrint('Toggle video error: $e');
    }
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    if (_currentCallId == null || _currentCallType != 'video') return;

    try {
      await ApiService().post('/video-call/switch-camera', {
        'call_id': _currentCallId,
      });
    } catch (e) {
      debugPrint('Switch camera error: $e');
    }
  }

  /// Send screen share request
  Future<void> startScreenShare() async {
    if (_currentCallId == null) return;

    try {
      await ApiService().post('/video-call/start-screen-share', {
        'call_id': _currentCallId,
      });
    } catch (e) {
      debugPrint('Start screen share error: $e');
    }
  }

  /// Stop screen share
  Future<void> stopScreenShare() async {
    if (_currentCallId == null) return;

    try {
      await ApiService().post('/video-call/stop-screen-share', {
        'call_id': _currentCallId,
      });
    } catch (e) {
      debugPrint('Stop screen share error: $e');
    }
  }

  /// Send call recording request
  Future<void> startRecording() async {
    if (_currentCallId == null) return;

    try {
      await ApiService().post('/video-call/start-recording', {
        'call_id': _currentCallId,
      });
    } catch (e) {
      debugPrint('Start recording error: $e');
    }
  }

  /// Stop call recording
  Future<void> stopRecording() async {
    if (_currentCallId == null) return;

    try {
      await ApiService().post('/video-call/stop-recording', {
        'call_id': _currentCallId,
      });
    } catch (e) {
      debugPrint('Stop recording error: $e');
    }
  }

  /// Subscribe to call channel
  Future<void> _subscribeToCallChannel(String callId) async {
    if (_pusher == null) return;

    final channelName = 'video-call-$callId';
    
    try {
      await _pusher!.subscribe(
        channelName: channelName,
        onEvent: (event) {
          _handleCallEvent(event);
        },
      );
    } catch (e) {
      debugPrint('Call channel subscription error: $e');
    }
  }

  /// Unsubscribe from call channel
  Future<void> _unsubscribeFromCallChannel(String callId) async {
    if (_pusher == null) return;

    final channelName = 'video-call-$callId';
    
    try {
      await _pusher!.unsubscribe(channelName: channelName);
    } catch (e) {
      debugPrint('Call channel unsubscription error: $e');
    }
  }

  /// Handle call events
  void _handleCallEvent(PusherEvent event) {
    try {
      final data = jsonDecode(event.data);
      
      switch (event.eventName) {
        case 'call-answered':
          _streamControllers['call-events']?.add({
            'type': 'call_answered',
            'data': data,
          });
          break;
        case 'call-rejected':
          _streamControllers['call-events']?.add({
            'type': 'call_rejected',
            'data': data,
          });
          break;
        case 'call-ended':
          _streamControllers['call-events']?.add({
            'type': 'call_ended',
            'data': data,
          });
          break;
        case 'participant-joined':
          _streamControllers['call-events']?.add({
            'type': 'participant_joined',
            'data': data,
          });
          break;
        case 'participant-left':
          _streamControllers['call-events']?.add({
            'type': 'participant_left',
            'data': data,
          });
          break;
        case 'mute-toggled':
          _streamControllers['call-events']?.add({
            'type': 'mute_toggled',
            'data': data,
          });
          break;
        case 'video-toggled':
          _streamControllers['call-events']?.add({
            'type': 'video_toggled',
            'data': data,
          });
          break;
        case 'screen-share-started':
          _streamControllers['call-events']?.add({
            'type': 'screen_share_started',
            'data': data,
          });
          break;
        case 'screen-share-stopped':
          _streamControllers['call-events']?.add({
            'type': 'screen_share_stopped',
            'data': data,
          });
          break;
        case 'recording-started':
          _streamControllers['call-events']?.add({
            'type': 'recording_started',
            'data': data,
          });
          break;
        case 'recording-stopped':
          _streamControllers['call-events']?.add({
            'type': 'recording_stopped',
            'data': data,
          });
          break;
        case 'call-quality-update':
          _streamControllers['call-events']?.add({
            'type': 'quality_update',
            'data': data,
          });
          break;
      }
    } catch (e) {
      debugPrint('Call event handling error: $e');
    }
  }

  /// Get call events stream
  Stream<Map<String, dynamic>> getCallEventsStream() {
    if (!_streamControllers.containsKey('call-events')) {
      _streamControllers['call-events'] = StreamController<Map<String, dynamic>>.broadcast();
    }
    
    return _streamControllers['call-events']!.stream;
  }

  /// Get incoming calls stream
  Stream<Map<String, dynamic>> getIncomingCallsStream() {
    if (!_streamControllers.containsKey('incoming-calls')) {
      _streamControllers['incoming-calls'] = StreamController<Map<String, dynamic>>.broadcast();
    }
    
    return _streamControllers['incoming-calls']!.stream;
  }

  /// Get call quality metrics
  Future<Map<String, dynamic>> getCallQualityMetrics() async {
    if (_currentCallId == null) {
      return {
        'success': false,
        'message': 'No active call',
      };
    }

    try {
      final response = await ApiService().get('/video-call/quality-metrics?call_id=$_currentCallId');

      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get quality metrics: $e',
      };
    }
  }

  /// Get call history
  Future<List<Map<String, dynamic>>> getCallHistory({
    int page = 1,
    int limit = 20,
    String? callType,
    String? status,
  }) async {
    try {
      final response = await ApiService().get('/video-call/history?page=$page&limit=$limit&call_type=${callType ?? ''}&status=${status ?? ''}');

      if (response['success']) {
        return List<Map<String, dynamic>>.from(response['calls'] ?? []);
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Get call history error: $e');
      return [];
    }
  }

  /// Get call statistics
  Future<Map<String, dynamic>> getCallStatistics() async {
    try {
      final response = await ApiService().get('/video-call/statistics');

      if (response['success']) {
        return response['statistics'] ?? {};
      } else {
        return {};
      }
    } catch (e) {
      debugPrint('Get call statistics error: $e');
      return {};
    }
  }

  /// Check if user is available for calls
  Future<bool> isUserAvailable(int userId) async {
    try {
      final response = await ApiService().get('/video-call/availability/$userId');

      if (response['success']) {
        return response['available'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('Check user availability error: $e');
      return false;
    }
  }

  /// Set user availability status
  Future<void> setAvailabilityStatus(bool available) async {
    try {
      await ApiService().post('/video-call/set-availability', {
        'available': available,
      });
    } catch (e) {
      debugPrint('Set availability status error: $e');
    }
  }

  /// Get current call info
  Map<String, dynamic>? getCurrentCallInfo() {
    if (_currentCallId == null) return null;

    return {
      'call_id': _currentCallId,
      'call_type': _currentCallType,
      'is_in_call': _isInCall,
      'is_connected': _isConnected,
    };
  }

  /// Check if currently in a call
  bool get isInCall => _isInCall;

  /// Check if service is connected
  bool get isConnected => _isConnected;

  /// Dispose resources
  void dispose() {
    _pusher?.disconnect();
    _streamControllers.values.forEach((controller) => controller.close());
    _streamControllers.clear();
    _isInCall = false;
    _currentCallId = null;
    _currentCallType = null;
  }
}
