import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service for managing audio playback in voice messages
class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final Map<String, AudioPlayer> _players = {};
  String? _currentlyPlayingUrl;
  
  /// Get or create audio player for a URL
  AudioPlayer _getPlayer(String url) {
    if (!_players.containsKey(url)) {
      _players[url] = AudioPlayer();
    }
    return _players[url]!;
  }

  /// Play voice message
  Future<void> play(String url) async {
    try {
      if (kDebugMode) {
        print('🎵 [AUDIO_PLAYER] Playing: $url');
      }

      // Stop currently playing audio
      if (_currentlyPlayingUrl != null && _currentlyPlayingUrl != url) {
        await pause(_currentlyPlayingUrl!);
      }

      final player = _getPlayer(url);
      await player.play(UrlSource(url));
      _currentlyPlayingUrl = url;

      if (kDebugMode) {
        print('✅ [AUDIO_PLAYER] Started playing');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [AUDIO_PLAYER] Play error: $e');
      }
      rethrow;
    }
  }

  /// Pause voice message
  Future<void> pause(String url) async {
    try {
      if (_players.containsKey(url)) {
        await _players[url]!.pause();
        if (_currentlyPlayingUrl == url) {
          _currentlyPlayingUrl = null;
        }
        
        if (kDebugMode) {
          print('⏸️ [AUDIO_PLAYER] Paused: $url');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [AUDIO_PLAYER] Pause error: $e');
      }
    }
  }

  /// Resume voice message
  Future<void> resume(String url) async {
    try {
      // Stop other audios first
      if (_currentlyPlayingUrl != null && _currentlyPlayingUrl != url) {
        await pause(_currentlyPlayingUrl!);
      }

      final player = _getPlayer(url);
      await player.resume();
      _currentlyPlayingUrl = url;

      if (kDebugMode) {
        print('▶️ [AUDIO_PLAYER] Resumed: $url');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [AUDIO_PLAYER] Resume error: $e');
      }
    }
  }

  /// Stop voice message
  Future<void> stop(String url) async {
    try {
      if (_players.containsKey(url)) {
        await _players[url]!.stop();
        if (_currentlyPlayingUrl == url) {
          _currentlyPlayingUrl = null;
        }
        
        if (kDebugMode) {
          print('⏹️ [AUDIO_PLAYER] Stopped: $url');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [AUDIO_PLAYER] Stop error: $e');
      }
    }
  }

  /// Seek to position
  Future<void> seek(String url, Duration position) async {
    try {
      if (_players.containsKey(url)) {
        await _players[url]!.seek(position);
        
        if (kDebugMode) {
          print('⏩ [AUDIO_PLAYER] Seeked to: ${position.inSeconds}s');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [AUDIO_PLAYER] Seek error: $e');
      }
    }
  }

  /// Set playback speed
  Future<void> setSpeed(String url, double speed) async {
    try {
      if (_players.containsKey(url)) {
        await _players[url]!.setPlaybackRate(speed);
        
        if (kDebugMode) {
          print('⚡ [AUDIO_PLAYER] Speed set to: ${speed}x');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [AUDIO_PLAYER] Set speed error: $e');
      }
    }
  }

  /// Get player state stream
  Stream<PlayerState>? getPlayerStateStream(String url) {
    if (_players.containsKey(url)) {
      return _players[url]!.onPlayerStateChanged;
    }
    return null;
  }

  /// Get duration stream
  Stream<Duration>? getDurationStream(String url) {
    if (_players.containsKey(url)) {
      return _players[url]!.onDurationChanged;
    }
    return null;
  }

  /// Get position stream
  Stream<Duration>? getPositionStream(String url) {
    if (_players.containsKey(url)) {
      return _players[url]!.onPositionChanged;
    }
    return null;
  }

  /// Check if audio is playing
  bool isPlaying(String url) {
    return _currentlyPlayingUrl == url;
  }

  /// Get currently playing URL
  String? get currentlyPlayingUrl => _currentlyPlayingUrl;

  /// Release specific player
  Future<void> releasePlayer(String url) async {
    if (_players.containsKey(url)) {
      await _players[url]!.dispose();
      _players.remove(url);
      
      if (_currentlyPlayingUrl == url) {
        _currentlyPlayingUrl = null;
      }
      
      if (kDebugMode) {
        print('🗑️ [AUDIO_PLAYER] Released player for: $url');
      }
    }
  }

  /// Release all players
  Future<void> releaseAll() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
    _currentlyPlayingUrl = null;
    
    if (kDebugMode) {
      print('🗑️ [AUDIO_PLAYER] Released all players');
    }
  }

  /// Dispose service
  void dispose() {
    releaseAll();
  }
}

