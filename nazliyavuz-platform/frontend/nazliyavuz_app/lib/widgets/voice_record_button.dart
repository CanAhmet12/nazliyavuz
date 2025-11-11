import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import '../services/voice_recorder_service.dart';
import 'package:flutter_sound/flutter_sound.dart';

class VoiceRecordButton extends StatefulWidget {
  final Function(String audioPath, int duration)? onVoiceRecorded;
  final Function()? onRecordingStarted;
  final Function()? onRecordingStopped;

  const VoiceRecordButton({
    super.key,
    this.onVoiceRecorded,
    this.onRecordingStarted,
    this.onRecordingStopped,
  });

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton>
    with TickerProviderStateMixin {
  final VoiceRecorderService _recorderService = VoiceRecorderService();
  
  bool _isRecording = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  
  Duration _recordingDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      // Use VoiceRecorderService to start recording
      final success = await _recorderService.startRecording();
      
      if (!success) {
        _showPermissionDialog();
        return;
      }

      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      _animationController.repeat(reverse: true);
      widget.onRecordingStarted?.call();

      // Listen to recording progress
      _recorderService.onProgress?.listen((disposition) {
        if (mounted) {
          setState(() {
            _recordingDuration = disposition.duration;
          });
          
          // Auto-stop at max duration
          if (_recorderService.isMaxDurationReached()) {
            _stopRecording();
          }
        }
      });
    } catch (e) {
      _showErrorDialog('Kayıt başlatılamadı: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      setState(() {
        _isRecording = false;
      });

      _animationController.stop();
      _animationController.reset();
      widget.onRecordingStopped?.call();

      // Stop recording and get file path
      final audioPath = await _recorderService.stopRecording();
      final duration = _recordingDuration.inSeconds;
      
      if (audioPath != null && duration > 0) {
        widget.onVoiceRecorded?.call(audioPath, duration);
      } else {
        _showErrorDialog('Kayıt dosyası bulunamadı');
      }
    } catch (e) {
      _showErrorDialog('Kayıt durdurulamadı: $e');
    }
  }
  
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hata'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mikrofon İzni Gerekli'),
        content: const Text(
          'Sesli mesaj gönderebilmek için mikrofon iznine ihtiyacımız var. '
          'Lütfen ayarlardan mikrofon iznini etkinleştirin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Ayarlara Git'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _startRecording(),
      onTapUp: (_) => _stopRecording(),
      onTapCancel: () => _stopRecording(),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _isRecording ? _scaleAnimation.value : 1.0,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red : AppTheme.primaryBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? Colors.red : AppTheme.primaryBlue)
                        .withOpacity(0.3),
                    blurRadius: _isRecording ? 20 : 8,
                    spreadRadius: _isRecording ? 5 : 2,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Pulse animation
                  if (_isRecording)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.red.withOpacity(
                              1.0 - _pulseAnimation.value,
                            ),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  
                  // Icon
                  Center(
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  
                  // Recording duration
                  if (_isRecording)
                    Positioned(
                      bottom: -25,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _formatDuration(_recordingDuration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}