import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

class RealTimeChatService {
  static final RealTimeChatService _instance = RealTimeChatService._internal();
  factory RealTimeChatService() => _instance;
  RealTimeChatService._internal();

  PusherChannelsFlutter? _pusher;
  final Map<String, StreamController<Map<String, dynamic>>> _streamControllers = {};
  final Map<String, Timer> _typingTimers = {};
  bool _isConnected = false;

  // Configuration - Production ready
  // Replace with your actual Pusher credentials from .env
  static const String _pusherKey = 'd7dfe548ecee05cf142e';
  static const String _pusherCluster = 'eu';

  /// Initialize Pusher connection
  Future<void> initialize() async {
    try {
      _pusher = PusherChannelsFlutter.getInstance();
      
      await _pusher!.init(
        apiKey: _pusherKey,
        cluster: _pusherCluster,
        onError: (String message, int? code, dynamic e) {
          debugPrint('Pusher Error: $message');
          _isConnected = false;
        },
        onConnectionStateChange: (String currentState, String previousState) {
          debugPrint('Pusher Connection State: $currentState');
          _isConnected = currentState == 'connected';
        },
      );

      await _pusher!.connect();
      debugPrint('✅ Pusher initialized and connected');
    } catch (e) {
      debugPrint('❌ Pusher initialization error: $e');
      _isConnected = false;
    }
  }

  /// Subscribe to conversation channel
  Future<void> subscribeToConversation(int user1Id, int user2Id) async {
    if (_pusher == null || !_isConnected) {
      debugPrint('❌ Pusher not available for subscription');
      return;
    }

    final channelName = _getConversationChannel(user1Id, user2Id);
    
    try {
      await _pusher!.subscribe(
        channelName: channelName,
        onEvent: (event) {
          _handleConversationEvent(event);
        },
      );
      debugPrint('✅ Subscribed to channel: $channelName');
    } catch (e) {
      debugPrint('❌ Subscription error: $e');
    }
  }

  /// Unsubscribe from conversation channel
  Future<void> unsubscribeFromConversation(int user1Id, int user2Id) async {
    if (_pusher == null) return;

    final channelName = _getConversationChannel(user1Id, user2Id);
    
    try {
      await _pusher!.unsubscribe(channelName: channelName);
    } catch (e) {
      debugPrint('Unsubscription error: $e');
    }
  }

  /// Subscribe to user channel for conversation updates
  Future<void> subscribeToUserChannel(int userId) async {
    if (_pusher == null) return;

    final channelName = 'user-$userId';
    
    try {
      await _pusher!.subscribe(
        channelName: channelName,
        onEvent: (event) {
          _handleUserEvent(event);
        },
      );
    } catch (e) {
      debugPrint('User subscription error: $e');
    }
  }

  /// Send typing indicator
  Future<void> sendTypingIndicator(int receiverId, bool isTyping) async {
    if (!_isConnected) return;

    try {
      final response = await ApiService().post('/chat/typing', {
        'receiver_id': receiverId,
        'is_typing': isTyping,
      });

      if (!response['success']) {
        debugPrint('Typing indicator error: ${response['message']}');
      }
    } catch (e) {
      debugPrint('Typing indicator error: $e');
    }
  }

  /// Send message reaction
  Future<void> sendMessageReaction(int messageId, String reaction) async {
    if (!_isConnected) return;

    try {
      final response = await ApiService().post('/chat/messages/$messageId/reaction', {
        'reaction': reaction,
      });

      if (!response['success']) {
        debugPrint('Message reaction error: ${response['message']}');
      }
    } catch (e) {
      debugPrint('Message reaction error: $e');
    }
  }

  /// Send voice message
  Future<void> sendVoiceMessage(int receiverId, XFile audioFile, int duration) async {
    if (!_isConnected) return;

    try {
      final response = await ApiService().uploadFile('/chat/voice-message', audioFile, {
        'receiver_id': receiverId,
        'duration': duration,
      });

      if (!response['success']) {
        debugPrint('Voice message error: ${response['message']}');
      }
    } catch (e) {
      debugPrint('Voice message error: $e');
    }
  }

  /// Send video call invitation
  Future<void> sendVideoCallInvitation(int receiverId, String callType) async {
    if (!_isConnected) return;

    try {
      final response = await ApiService().post('/chat/video-call', {
        'receiver_id': receiverId,
        'call_type': callType,
      });

      if (!response['success']) {
        debugPrint('Video call invitation error: ${response['message']}');
      }
    } catch (e) {
      debugPrint('Video call invitation error: $e');
    }
  }

  /// Send signaling message for WebRTC
  Future<void> sendSignalingMessage(int receiverId, String type, Map<String, dynamic> data, String? callId) async {
    if (!_isConnected) return;

    try {
      final response = await ApiService().post('/chat/signaling', {
        'receiver_id': receiverId,
        'type': type,
        'data': data,
        'call_id': callId,
      });

      if (!response['success']) {
        debugPrint('Signaling message error: ${response['message']}');
      }
    } catch (e) {
      debugPrint('Signaling message error: $e');
    }
  }

  /// Respond to video call
  Future<void> respondToVideoCall(int callerId, String callId, String response) async {
    if (!_isConnected) return;

    try {
      final apiResponse = await ApiService().post('/chat/video-call-response', {
        'caller_id': callerId,
        'call_id': callId,
        'response': response,
      });

      if (!apiResponse['success']) {
        debugPrint('Video call response error: ${apiResponse['message']}');
      }
    } catch (e) {
      debugPrint('Video call response error: $e');
    }
  }

  /// Get message reactions stream
  Stream<Map<String, dynamic>> getMessageReactionsStream(int messageId) {
    final streamKey = 'reactions-$messageId';
    
    if (!_streamControllers.containsKey(streamKey)) {
      _streamControllers[streamKey] = StreamController<Map<String, dynamic>>.broadcast();
    }
    
    return _streamControllers[streamKey]!.stream;
  }

  /// Get typing indicator stream
  Stream<Map<String, dynamic>> getTypingIndicatorStream(int otherUserId) {
    final streamKey = 'typing-$otherUserId';
    
    if (!_streamControllers.containsKey(streamKey)) {
      _streamControllers[streamKey] = StreamController<Map<String, dynamic>>.broadcast();
    }
    
    return _streamControllers[streamKey]!.stream;
  }

  /// Get new message stream
  Stream<Map<String, dynamic>> getNewMessageStream() {
    const streamKey = 'new-message';
    
    if (!_streamControllers.containsKey(streamKey)) {
      _streamControllers[streamKey] = StreamController<Map<String, dynamic>>.broadcast();
    }
    
    return _streamControllers[streamKey]!.stream;
  }

  /// Get conversation update stream
  Stream<Map<String, dynamic>> getConversationUpdateStream() {
    const streamKey = 'conversation-update';
    
    if (!_streamControllers.containsKey(streamKey)) {
      _streamControllers[streamKey] = StreamController<Map<String, dynamic>>.broadcast();
    }
    
    return _streamControllers[streamKey]!.stream;
  }

  /// Get stream for typing indicators
  Stream<Map<String, dynamic>> getTypingStream(int otherUserId) {
    final streamKey = 'typing-$otherUserId';
    if (!_streamControllers.containsKey(streamKey)) {
      _streamControllers[streamKey] = StreamController<Map<String, dynamic>>.broadcast();
    }
    
    return _streamControllers[streamKey]!.stream;
  }

  /// Get stream for message read status
  Stream<Map<String, dynamic>> getMessageReadStream() {
    final streamKey = 'message-read';
    if (!_streamControllers.containsKey(streamKey)) {
      _streamControllers[streamKey] = StreamController<Map<String, dynamic>>.broadcast();
    }
    
    return _streamControllers[streamKey]!.stream;
  }

  /// Get video call stream
  Stream<Map<String, dynamic>> getVideoCallStream() {
    const streamKey = 'video-call';
    
    if (!_streamControllers.containsKey(streamKey)) {
      _streamControllers[streamKey] = StreamController<Map<String, dynamic>>.broadcast();
    }
    
    return _streamControllers[streamKey]!.stream;
  }

  /// Handle conversation events
  void _handleConversationEvent(PusherEvent event) {
    try {
      final data = jsonDecode(event.data);
      
      switch (event.eventName) {
        case 'new-message':
          _streamControllers['new-message']?.add(data);
          break;
        case 'typing':
          final otherUserId = data['sender_id'];
          _streamControllers['typing-$otherUserId']?.add(data);
          break;
        case 'message-read':
          _streamControllers['message-read']?.add(data);
          break;
        case 'message-reaction':
          final messageId = data['message_id'];
          _streamControllers['reactions-$messageId']?.add(data);
          break;
        case 'voice-message':
          _streamControllers['new-message']?.add(data);
          break;
        case 'video-call':
          _streamControllers['video-call']?.add(data);
          break;
        case 'video-call-response':
          _streamControllers['video-call']?.add(data);
          break;
        case 'signaling':
          _streamControllers['signaling']?.add(data);
          break;
        case 'message-deleted':
          _streamControllers['message-deleted']?.add(data);
          break;
        case 'conversation-updated':
          _streamControllers['conversation-update']?.add(data);
          break;
      }
    } catch (e) {
      debugPrint('Event handling error: $e');
    }
  }

  /// Handle user events
  void _handleUserEvent(PusherEvent event) {
    try {
      final data = jsonDecode(event.data);
      
      switch (event.eventName) {
        case 'conversation-updated':
          _streamControllers['conversation-update']?.add(data);
          break;
        case 'system-notification':
          _streamControllers['system-notification']?.add(data);
          break;
      }
    } catch (e) {
      debugPrint('User event handling error: $e');
    }
  }

  /// Start typing indicator with debounce
  void startTypingIndicator(int receiverId) {
    _typingTimers[receiverId.toString()]?.cancel();
    
    sendTypingIndicator(receiverId, true);
    
    _typingTimers[receiverId.toString()] = Timer(const Duration(seconds: 3), () {
      sendTypingIndicator(receiverId, false);
    });
  }

  /// Stop typing indicator
  void stopTypingIndicator(int receiverId) {
    _typingTimers[receiverId.toString()]?.cancel();
    sendTypingIndicator(receiverId, false);
  }

  /// Send typing indicator to backend
  Future<void> sendTypingIndicatorToBackend(int receiverId, bool isTyping) async {
    if (_pusher == null || !_isConnected) return;
    
    try {
      final channelName = _getConversationChannel(0, receiverId); // Current user ID will be 0 for now
      
      await _pusher!.trigger(
        PusherEvent(
          channelName: channelName,
          eventName: 'typing',
          data: jsonEncode({
            'sender_id': 0, // Current user ID
            'receiver_id': receiverId,
            'is_typing': isTyping,
            'timestamp': DateTime.now().toIso8601String(),
          }),
        ),
      );
      
      debugPrint('✅ Typing indicator sent: $isTyping to user $receiverId');
    } catch (e) {
      debugPrint('❌ Error sending typing indicator: $e');
    }
  }

  /// Get conversation channel name
  String _getConversationChannel(int user1Id, int user2Id) {
    final minId = user1Id < user2Id ? user1Id : user2Id;
    final maxId = user1Id > user2Id ? user1Id : user2Id;
    return 'conversation-$minId-$maxId';
  }

  /// Get signaling stream for WebRTC
  Stream<Map<String, dynamic>> getSignalingStream() {
    if (!_streamControllers.containsKey('signaling')) {
      _streamControllers['signaling'] = StreamController<Map<String, dynamic>>.broadcast();
    }
    
    return _streamControllers['signaling']!.stream;
  }

  /// Check if connected
  bool get isConnected => _isConnected;

  /// Disconnect from Pusher
  void disconnect() {
    _pusher?.disconnect();
    _isConnected = false;
  }

  /// Dispose resources
  void dispose() {
    _pusher?.disconnect();
    _streamControllers.values.forEach((controller) => controller.close());
    _streamControllers.clear();
    _typingTimers.values.forEach((timer) => timer.cancel());
    _typingTimers.clear();
  }
}
