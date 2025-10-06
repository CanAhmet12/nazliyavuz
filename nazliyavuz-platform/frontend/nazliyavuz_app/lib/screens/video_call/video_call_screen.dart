import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/user.dart';
import '../../services/real_time_chat_service.dart';
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
  final _realTimeChatService = RealTimeChatService();
  
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isCallActive = false;
  
  Timer? _callTimer;
  int _callDuration = 0;
  
  String _callId = '';

  @override
  void initState() {
    super.initState();
    _startCall();
  }

  @override
  void dispose() {
    _cleanupCall();
    super.dispose();
  }

  Future<void> _startCall() async {
    _callId = 'call_${DateTime.now().millisecondsSinceEpoch}';
    
    // Send video call invitation
    await _realTimeChatService.sendVideoCallInvitation(
      widget.otherUser.id,
      widget.callType,
    );

    // Simulate call connection
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isConnected = true;
          _isCallActive = true;
        });
        _startCallTimer();
      }
    });
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
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  Future<void> _toggleVideo() async {
    if (widget.callType == 'video') {
      setState(() {
        _isVideoEnabled = !_isVideoEnabled;
      });
    }
  }

  Future<void> _switchCamera() async {
    // Camera switch functionality would be implemented here
    debugPrint('Switching camera...');
  }

  Future<void> _endCall() async {
    _callTimer?.cancel();
    
    // Send end call signal
    await _realTimeChatService.respondToVideoCall(
      widget.otherUser.id,
      _callId,
      'ended',
    );

    await _cleanupCall();
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _cleanupCall() async {
    _callTimer?.cancel();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote video (full screen)
            if (_isConnected)
              Positioned.fill(
                child: Container(
                  color: Colors.grey[800],
                  child: const Center(
                    child: Icon(
                      Icons.videocam,
                      size: 100,
                      color: Colors.white54,
                    ),
                  ),
                ),
              )
            else
              _buildWaitingScreen(),

            // Local video (picture-in-picture)
            if (widget.callType == 'video' && _isVideoEnabled)
              Positioned(
                top: 40,
                right: 20,
                child: Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                    color: Colors.grey[600],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.white,
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
            AppTheme.primaryBlue,
            AppTheme.primaryBlue.withOpacity(0.8),
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