import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'real_time_chat_service.dart';
import 'api_service.dart';

/// WebRTC service for video/audio calls
class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  final _localStreamController = StreamController<MediaStream?>.broadcast();
  final _remoteStreamController = StreamController<MediaStream?>.broadcast();
  final _connectionStateController = StreamController<RTCPeerConnectionState>.broadcast();
  
  final _realTimeService = RealTimeChatService();
  final _apiService = ApiService();
  
  bool _isInitialized = false;
  String? _currentCallId;
  int? _otherUserId;
  bool _isCaller = false;

  // ICE servers configuration
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ]
      },
    ]
  };

  // Media constraints
  final Map<String, dynamic> _mediaConstraints = {
    'audio': true,
    'video': {
      'facingMode': 'user',
      'width': {'ideal': 1280},
      'height': {'ideal': 720},
    }
  };

  /// Initialize WebRTC
  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      await _realTimeService.initialize();
      _isInitialized = true;

      if (kDebugMode) {
        print('✅ [WEBRTC] Service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [WEBRTC] Initialization error: $e');
      }
      rethrow;
    }
  }

  /// Start a call (as caller)
  Future<bool> startCall({
    required int receiverId,
    required String callType,
    String? callId,
    int? reservationId,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      _currentCallId = callId ?? 'call_${DateTime.now().millisecondsSinceEpoch}';
      _otherUserId = receiverId;
      _isCaller = true;

      if (kDebugMode) {
        print('📞 [WEBRTC] Starting call as caller');
        print('📞 [WEBRTC] Call ID: $_currentCallId');
        print('📞 [WEBRTC] Receiver ID: $receiverId');
        print('📞 [WEBRTC] Call Type: $callType');
      }

      // Get local media stream
      await _getUserMedia(callType == 'video');

      // Create peer connection
      await _createPeerConnection();

      // Create and send offer
      await _createOffer();

      // Notify backend
      final response = await _apiService.post('/video-call/start', {
        'receiver_id': receiverId,
        'call_type': callType,
        'call_id': _currentCallId,
        'reservation_id': reservationId,
      });

      if (response['success'] == true) {
        // Subscribe to signaling channel
        await _subscribeToSignaling();
        
        if (kDebugMode) {
          print('✅ [WEBRTC] Call started successfully');
        }
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [WEBRTC] Start call error: $e');
      }
      await cleanUp();
      return false;
    }
  }

  /// Answer a call (as receiver)
  Future<bool> answerCall({
    required String callId,
    required String callType,
    required int callerId,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      _currentCallId = callId;
      _otherUserId = callerId;
      _isCaller = false;

      if (kDebugMode) {
        print('📞 [WEBRTC] Answering call');
        print('📞 [WEBRTC] Call ID: $callId');
        print('📞 [WEBRTC] Caller ID: $callerId');
      }

      // Get local media stream
      await _getUserMedia(callType == 'video');

      // Create peer connection
      await _createPeerConnection();

      // Subscribe to signaling first (to receive offer)
      await _subscribeToSignaling();

      // Notify backend
      await _apiService.post('/video-call/answer', {
        'call_id': callId,
        'call_type': callType,
      });

      if (kDebugMode) {
        print('✅ [WEBRTC] Call answered');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [WEBRTC] Answer call error: $e');
      }
      await cleanUp();
      return false;
    }
  }

  /// Get user media (camera + microphone)
  Future<void> _getUserMedia(bool includeVideo) async {
    try {
      final Map<String, dynamic> constraints = {
        'audio': true,
        'video': includeVideo ? _mediaConstraints['video'] : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      _localStreamController.add(_localStream);

      if (kDebugMode) {
        print('📹 [WEBRTC] Local stream acquired');
        print('📹 [WEBRTC] Video: $includeVideo, Audio: true');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [WEBRTC] Get user media error: $e');
      }
      rethrow;
    }
  }

  /// Create peer connection
  Future<void> _createPeerConnection() async {
    try {
      _peerConnection = await createPeerConnection(_iceServers);

      // Add local stream
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          _peerConnection!.addTrack(track, _localStream!);
        });
      }

      // Listen to connection state
      _peerConnection!.onConnectionState = (state) {
        if (kDebugMode) {
          print('🔌 [WEBRTC] Connection state: $state');
        }
        _connectionStateController.add(state);
      };

      // Listen to ICE candidates
      _peerConnection!.onIceCandidate = (candidate) {
        if (candidate != null) {
          _sendIceCandidate(candidate);
        }
      };

      // Listen to remote stream
      _peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          _remoteStreamController.add(_remoteStream);
          
          if (kDebugMode) {
            print('📹 [WEBRTC] Remote stream received');
          }
        }
      };

      if (kDebugMode) {
        print('✅ [WEBRTC] Peer connection created');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [WEBRTC] Create peer connection error: $e');
      }
      rethrow;
    }
  }

  /// Create and send offer (caller)
  Future<void> _createOffer() async {
    try {
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      _sendSignalingMessage({
        'type': 'offer',
        'sdp': offer.sdp,
      });

      if (kDebugMode) {
        print('📤 [WEBRTC] Offer created and sent');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [WEBRTC] Create offer error: $e');
      }
      rethrow;
    }
  }

  /// Handle incoming offer (receiver)
  Future<void> _handleOffer(Map<String, dynamic> data) async {
    try {
      final offer = RTCSessionDescription(data['sdp'], 'offer');
      await _peerConnection!.setRemoteDescription(offer);

      // Create answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      _sendSignalingMessage({
        'type': 'answer',
        'sdp': answer.sdp,
      });

      if (kDebugMode) {
        print('📤 [WEBRTC] Answer created and sent');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [WEBRTC] Handle offer error: $e');
      }
    }
  }

  /// Handle incoming answer (caller)
  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    try {
      final answer = RTCSessionDescription(data['sdp'], 'answer');
      await _peerConnection!.setRemoteDescription(answer);

      if (kDebugMode) {
        print('✅ [WEBRTC] Answer received and set');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [WEBRTC] Handle answer error: $e');
      }
    }
  }

  /// Handle ICE candidate
  Future<void> _handleIceCandidate(Map<String, dynamic> data) async {
    try {
      final candidate = RTCIceCandidate(
        data['candidate'],
        data['sdpMid'],
        data['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);

      if (kDebugMode) {
        print('✅ [WEBRTC] ICE candidate added');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [WEBRTC] Handle ICE candidate error: $e');
      }
    }
  }

  /// Send signaling message via Pusher
  Future<void> _sendSignalingMessage(Map<String, dynamic> message) async {
    try {
      await _apiService.post('/chat/signaling', {
        'call_id': _currentCallId,
        'receiver_id': _otherUserId,
        'type': message['type'],
        'data': {
          ...message,
          'sender_id': _apiService.currentUserId,
        },
      });

      if (kDebugMode) {
        print('📤 [WEBRTC] Signaling message sent: ${message['type']}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [WEBRTC] Send signaling error: $e');
      }
    }
  }

  /// Send ICE candidate
  Future<void> _sendIceCandidate(RTCIceCandidate candidate) async {
    _sendSignalingMessage({
      'type': 'ice-candidate',
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    });
  }

  /// Subscribe to signaling channel
  Future<void> _subscribeToSignaling() async {
    // TODO: Implement Pusher subscription for signaling
    // This will receive offer/answer/ice-candidate messages
    // For now, using API polling or websocket alternative
    
    if (kDebugMode) {
      print('📡 [WEBRTC] Subscribed to signaling channel');
    }
  }

  /// Toggle microphone
  Future<void> toggleMicrophone() async {
    if (_localStream == null) return;

    final audioTrack = _localStream!.getAudioTracks().first;
    audioTrack.enabled = !audioTrack.enabled;

    // Notify backend
    await _apiService.post('/video-call/toggle-mute', {
      'call_id': _currentCallId,
      'muted': !audioTrack.enabled,
    });

    if (kDebugMode) {
      print('🎤 [WEBRTC] Microphone ${audioTrack.enabled ? "enabled" : "disabled"}');
    }
  }

  /// Toggle camera
  Future<void> toggleCamera() async {
    if (_localStream == null) return;

    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isEmpty) return;

    final videoTrack = videoTracks.first;
    videoTrack.enabled = !videoTrack.enabled;

    // Notify backend
    await _apiService.post('/video-call/toggle-video', {
      'call_id': _currentCallId,
      'video_enabled': videoTrack.enabled,
    });

    if (kDebugMode) {
      print('📹 [WEBRTC] Camera ${videoTrack.enabled ? "enabled" : "disabled"}');
    }
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    if (_localStream == null) return;

    final videoTrack = _localStream!.getVideoTracks().first;
    await Helper.switchCamera(videoTrack);

    if (kDebugMode) {
      print('🔄 [WEBRTC] Camera switched');
    }
  }

  /// End call
  Future<void> endCall() async {
    try {
      // Notify backend
      if (_currentCallId != null) {
        await _apiService.post('/video-call/end', {
          'call_id': _currentCallId,
        });
      }

      await cleanUp();

      if (kDebugMode) {
        print('✅ [WEBRTC] Call ended');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [WEBRTC] End call error: $e');
      }
    }
  }

  /// Clean up resources
  Future<void> cleanUp() async {
    try {
      // Close local stream
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          track.stop();
        });
        await _localStream!.dispose();
        _localStream = null;
        _localStreamController.add(null);
      }

      // Close remote stream
      if (_remoteStream != null) {
        _remoteStream!.getTracks().forEach((track) {
          track.stop();
        });
        await _remoteStream!.dispose();
        _remoteStream = null;
        _remoteStreamController.add(null);
      }

      // Close peer connection
      if (_peerConnection != null) {
        await _peerConnection!.close();
        _peerConnection = null;
      }

      _currentCallId = null;
      _otherUserId = null;
      _isCaller = false;

      if (kDebugMode) {
        print('🧹 [WEBRTC] Cleanup complete');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [WEBRTC] Cleanup error: $e');
      }
    }
  }

  /// Get streams
  Stream<MediaStream?> get localStreamController => _localStreamController.stream;
  Stream<MediaStream?> get remoteStreamController => _remoteStreamController.stream;
  Stream<RTCPeerConnectionState> get connectionStateController => _connectionStateController.stream;

  /// Get current streams
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  /// Get call info
  String? get currentCallId => _currentCallId;
  bool get isInCall => _peerConnection != null;

  /// Dispose service
  void dispose() {
    cleanUp();
    _localStreamController.close();
    _remoteStreamController.close();
    _connectionStateController.close();
  }
}

