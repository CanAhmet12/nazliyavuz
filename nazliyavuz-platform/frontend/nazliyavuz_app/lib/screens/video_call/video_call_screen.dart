import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';
import '../../models/user.dart';
import '../../services/webrtc_service.dart';
import '../../theme/app_theme.dart';

class VideoCallScreen extends StatefulWidget {
  final User otherUser;
  final String callType; // 'video' or 'audio'

  const VideoCallScreen({
    super.key,
    required this.otherUser,
    required this.callType,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final _webrtcService = WebRTCService();
  
  // WebRTC renderers
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isCallActive = false;
  
  Timer? _callTimer;
  int _callDuration = 0;
  
  String _callId = '';
  
  StreamSubscription? _localStreamSubscription;
  StreamSubscription? _remoteStreamSubscription;
  StreamSubscription? _connectionStateSubscription;

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
  }

  @override
  void dispose() {
    _cleanupCall();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStreamSubscription?.cancel();
    _remoteStreamSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeRenderers() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      
      await _startCall();
    } catch (e) {
      debugPrint('❌ [VIDEO_CALL] Renderer initialization error: $e');
      if (mounted) {
        _showError('Video başlatılamadı: $e');
        Navigator.pop(context);
      }
    }
  }

  Future<void> _startCall() async {
    try {
      _callId = 'call_${DateTime.now().millisecondsSinceEpoch}';
      
      // Start WebRTC call
      final success = await _webrtcService.startCall(
        receiverId: widget.otherUser.id,
        callType: widget.callType,
        callId: _callId,
      );

      if (!success) {
        _showError('Arama başlatılamadı');
        if (mounted) Navigator.pop(context);
        return;
      }

      // Set local stream immediately if available
      if (_webrtcService.localStream != null) {
        setState(() {
          _localRenderer.srcObject = _webrtcService.localStream;
          if (kDebugMode) {
            print('✅ [VIDEO_CALL] Local stream set immediately');
          }
        });
      }

      // Listen to streams
      _localStreamSubscription = _webrtcService.localStreamController.listen((stream) {
        if (kDebugMode) {
          print('🎥 [VIDEO_CALL] Local stream received: ${stream != null}');
        }
        if (stream != null && mounted) {
          setState(() {
            _localRenderer.srcObject = stream;
            if (kDebugMode) {
              print('✅ [VIDEO_CALL] Local renderer updated');
            }
          });
        }
      });

      _remoteStreamSubscription = _webrtcService.remoteStreamController.listen((stream) {
        if (stream != null && mounted) {
          setState(() {
            _isConnected = true;
            _isCallActive = true;
          });
          _remoteRenderer.srcObject = stream;
          _startCallTimer();
        }
      });

      // Listen to connection state
      _connectionStateSubscription = _webrtcService.connectionStateController.listen((state) {
        if (kDebugMode) {
          print('📞 [VIDEO_CALL] Connection state: $state');
        }
        
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          if (mounted) {
            setState(() {
              _isConnected = true;
              _isCallActive = true;
            });
          }
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
                   state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          if (mounted) {
            _endCall();
          }
        }
      });

    } catch (e) {
      debugPrint('❌ [VIDEO_CALL] Start call error: $e');
      _showError('Arama başlatılamadı: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration++;
        });
      }
    });
  }

  String _formatCallDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleMute() async {
    await _webrtcService.toggleMicrophone();
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  Future<void> _toggleVideo() async {
    if (widget.callType == 'video') {
      await _webrtcService.toggleCamera();
      setState(() {
        _isVideoEnabled = !_isVideoEnabled;
      });
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _webrtcService.switchCamera();
      debugPrint('✅ Camera switched');
    } catch (e) {
      debugPrint('❌ Camera switch error: $e');
    }
  }

  void _cleanupCall() {
    _callTimer?.cancel();
    _localStreamSubscription?.cancel();
    _remoteStreamSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _webrtcService.cleanUp();
  }

  Future<void> _endCall() async {
    _callTimer?.cancel();
    
    // End WebRTC call
    await _webrtcService.endCall();
    
    if (mounted) {
      Navigator.pop(context);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Background - Always show local video in full screen first
            if (widget.callType == 'video' && _isVideoEnabled)
              Positioned.fill(
                child: RTCVideoView(
                  _localRenderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else
              Container(color: Colors.black),
            
            // Overlay waiting screen when not connected
            if (!_isConnected)
              _buildWaitingScreen(),
            
            // Remote video (full screen) when connected
            if (_isConnected && _webrtcService.remoteStream != null)
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),

            // Local video (picture-in-picture) - Show when connected
            if (_isConnected && widget.callType == 'video' && _isVideoEnabled)
              Positioned(
                top: 60,
                right: 20,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 140,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),

            // Top bar with user info and call duration
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingScreen() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.black.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.white.withOpacity(0.2),
            backgroundImage: widget.otherUser.profilePhotoUrl != null
                ? NetworkImage(widget.otherUser.profilePhotoUrl!)
                : null,
            child: widget.otherUser.profilePhotoUrl == null
                ? Text(
                    widget.otherUser.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 24),
          Text(
            widget.otherUser.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isCallActive ? 'Bağlandı' : 'Aranıyor...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          if (_isCallActive) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatCallDuration(_callDuration),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _endCall,
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUser.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (_isCallActive)
                  Text(
                    _formatCallDuration(_callDuration),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.callType == 'video')
            IconButton(
              onPressed: _switchCamera,
              icon: const Icon(
                Icons.flip_camera_ios,
                color: Colors.white,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute button
          _buildControlButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            backgroundColor: _isMuted ? Colors.red : Colors.white.withOpacity(0.2),
            iconColor: _isMuted ? Colors.white : Colors.white,
            onPressed: _toggleMute,
          ),
          
          // Video toggle button (only for video calls)
          if (widget.callType == 'video')
            _buildControlButton(
              icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
              backgroundColor: _isVideoEnabled ? Colors.white.withOpacity(0.2) : Colors.red,
              iconColor: Colors.white,
              onPressed: _toggleVideo,
            ),
          
          // End call button
          _buildControlButton(
            icon: Icons.call_end,
            backgroundColor: Colors.red,
            iconColor: Colors.white,
            onPressed: _endCall,
            size: 60,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    required VoidCallback onPressed,
    double size = 50,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: size * 0.4,
        ),
      ),
    );
  }
}