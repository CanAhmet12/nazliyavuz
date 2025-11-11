import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Service for recording voice messages
class VoiceRecorderService {
  static final VoiceRecorderService _instance = VoiceRecorderService._internal();
  factory VoiceRecorderService() => _instance;
  VoiceRecorderService._internal();

  FlutterSoundRecorder? _recorder;
  bool _isRecorderInitialized = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  /// Maximum recording duration (2 minutes)
  static const Duration maxDuration = Duration(minutes: 2);

  /// Initialize the recorder
  Future<void> initialize() async {
    try {
      _recorder = FlutterSoundRecorder();
      await _recorder!.openRecorder();
      _isRecorderInitialized = true;

      if (kDebugMode) {
        print('✅ [VOICE_RECORDER] Recorder initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [VOICE_RECORDER] Initialization error: $e');
      }
      rethrow;
    }
  }

  /// Check and request microphone permission
  Future<bool> checkPermission() async {
    try {
      final status = await Permission.microphone.status;
      
      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        final result = await Permission.microphone.request();
        return result.isGranted;
      }

      if (status.isPermanentlyDenied) {
        // User has permanently denied permission
        if (kDebugMode) {
          print('⚠️ [VOICE_RECORDER] Microphone permission permanently denied');
        }
        return false;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [VOICE_RECORDER] Permission check error: $e');
      }
      return false;
    }
  }

  /// Start recording
  Future<bool> startRecording() async {
    try {
      if (!_isRecorderInitialized) {
        await initialize();
      }

      // Check permission
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        throw Exception('Mikrofon izni gerekli');
      }

      // Generate file path
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${directory.path}/voice_message_$timestamp.aac';

      // Start recording
      await _recorder!.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.aacADTS, // AAC format (good quality, small size)
        bitRate: 128000, // 128 kbps
        sampleRate: 44100, // 44.1 kHz
      );

      _recordingStartTime = DateTime.now();

      if (kDebugMode) {
        print('🎙️ [VOICE_RECORDER] Recording started');
        print('🎙️ [VOICE_RECORDER] File: $_currentRecordingPath');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [VOICE_RECORDER] Start recording error: $e');
      }
      return false;
    }
  }

  /// Stop recording and return file path
  Future<String?> stopRecording() async {
    try {
      if (_recorder == null || !_recorder!.isRecording) {
        if (kDebugMode) {
          print('⚠️ [VOICE_RECORDER] No active recording');
        }
        return null;
      }

      await _recorder!.stopRecorder();
      final path = _currentRecordingPath;
      
      // Calculate duration
      final duration = DateTime.now().difference(_recordingStartTime!);

      if (kDebugMode) {
        print('⏹️ [VOICE_RECORDER] Recording stopped');
        print('⏹️ [VOICE_RECORDER] Duration: ${duration.inSeconds}s');
        print('⏹️ [VOICE_RECORDER] File: $path');
      }

      // Check file size
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          final fileSize = await file.length();
          if (kDebugMode) {
            print('📦 [VOICE_RECORDER] File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');
          }
        }
      }

      _currentRecordingPath = null;
      _recordingStartTime = null;

      return path;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [VOICE_RECORDER] Stop recording error: $e');
      }
      _currentRecordingPath = null;
      _recordingStartTime = null;
      return null;
    }
  }

  /// Cancel recording and delete file
  Future<void> cancelRecording() async {
    try {
      if (_recorder != null && _recorder!.isRecording) {
        await _recorder!.stopRecorder();
      }

      // Delete the file
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
          
          if (kDebugMode) {
            print('🗑️ [VOICE_RECORDER] Recording file deleted');
          }
        }
      }

      _currentRecordingPath = null;
      _recordingStartTime = null;

      if (kDebugMode) {
        print('❌ [VOICE_RECORDER] Recording cancelled');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [VOICE_RECORDER] Cancel recording error: $e');
      }
    }
  }

  /// Get recording duration
  Duration? getRecordingDuration() {
    if (_recordingStartTime == null) return null;
    return DateTime.now().difference(_recordingStartTime!);
  }

  /// Check if currently recording
  bool get isRecording => _recorder != null && _recorder!.isRecording;

  /// Get recording duration stream
  Stream<RecordingDisposition>? get onProgress {
    return _recorder?.onProgress;
  }

  /// Check if max duration reached
  bool isMaxDurationReached() {
    final duration = getRecordingDuration();
    if (duration == null) return false;
    return duration >= maxDuration;
  }

  /// Dispose service
  Future<void> dispose() async {
    if (_recorder != null) {
      if (_recorder!.isRecording) {
        await _recorder!.stopRecorder();
      }
      await _recorder!.closeRecorder();
      _recorder = null;
    }
    _isRecorderInitialized = false;
    _currentRecordingPath = null;
    _recordingStartTime = null;

    if (kDebugMode) {
      print('🗑️ [VOICE_RECORDER] Service disposed');
    }
  }
}

