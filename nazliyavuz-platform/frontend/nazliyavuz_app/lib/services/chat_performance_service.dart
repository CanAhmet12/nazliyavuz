import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';
import '../models/chat.dart';

class ChatPerformanceService {
  static final ChatPerformanceService _instance = ChatPerformanceService._internal();
  factory ChatPerformanceService() => _instance;
  ChatPerformanceService._internal();

  // Cache management
  final Map<String, dynamic> _messageCache = {};
  final Map<String, List<Chat>> _chatCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  
  // Performance settings
  static const int _maxCacheSize = 1000;
  static const Duration _cacheExpiry = Duration(hours: 1);
  
  // Background processing
  Timer? _cacheCleanupTimer;
  Timer? _performanceMonitorTimer;
  
  // Performance metrics
  int _totalMessagesLoaded = 0;
  int _cacheHits = 0;
  int _cacheMisses = 0;
  DateTime? _lastPerformanceCheck;

  /// Initialize performance service
  Future<void> initialize() async {
    if (kDebugMode) {
      print('🚀 [CHAT_PERFORMANCE] Initializing ChatPerformanceService...');
    }
    
    // Start cache cleanup timer
    _cacheCleanupTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _cleanupExpiredCache(),
    );
    
    // Start performance monitoring
    _performanceMonitorTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _monitorPerformance(),
    );
    
    // Load cached data
    await _loadCachedData();
  }

  /// Dispose resources
  void dispose() {
    _cacheCleanupTimer?.cancel();
    _performanceMonitorTimer?.cancel();
  }

  /// Cache messages for a chat
  Future<void> cacheMessages(int chatId, List<Message> messages) async {
    final cacheKey = 'messages_$chatId';
    
    // Limit cache size
    if (_messageCache.length >= _maxCacheSize) {
      _evictOldestCache();
    }
    
    _messageCache[cacheKey] = messages.map((m) => m.toJson()).toList();
    _cacheTimestamps[cacheKey] = DateTime.now();
    
    // Save to persistent storage
    await _saveCachedData();
    
    if (kDebugMode) {
      print('💾 [CHAT_PERFORMANCE] Cached ${messages.length} messages for chat $chatId');
    }
  }

  /// Get cached messages for a chat
  List<Message>? getCachedMessages(int chatId) {
    final cacheKey = 'messages_$chatId';
    final cached = _messageCache[cacheKey];
    final timestamp = _cacheTimestamps[cacheKey];
    
    if (cached == null || timestamp == null) {
      _cacheMisses++;
      return null;
    }
    
    // Check if cache is expired
    if (DateTime.now().difference(timestamp) > _cacheExpiry) {
      _messageCache.remove(cacheKey);
      _cacheTimestamps.remove(cacheKey);
      _cacheMisses++;
      return null;
    }
    
    _cacheHits++;
    
    try {
      final messages = (cached as List)
          .map((json) => Message.fromJson(json))
          .toList();
      
      if (kDebugMode) {
        print('🎯 [CHAT_PERFORMANCE] Cache hit for chat $chatId (${messages.length} messages)');
      }
      
      return messages;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [CHAT_PERFORMANCE] Error parsing cached messages: $e');
      }
      _messageCache.remove(cacheKey);
      _cacheTimestamps.remove(cacheKey);
      _cacheMisses++;
      return null;
    }
  }

  /// Cache chat list
  Future<void> cacheChatList(List<Chat> chats) async {
    const cacheKey = 'chat_list';
    
    _chatCache[cacheKey] = chats;
    _cacheTimestamps[cacheKey] = DateTime.now();
    
    await _saveCachedData();
    
    if (kDebugMode) {
      print('💾 [CHAT_PERFORMANCE] Cached ${chats.length} chats');
    }
  }

  /// Get cached chat list
  List<Chat>? getCachedChatList() {
    const cacheKey = 'chat_list';
    final cached = _chatCache[cacheKey];
    final timestamp = _cacheTimestamps[cacheKey];
    
    if (cached == null || timestamp == null) {
      return null;
    }
    
    // Check if cache is expired
    if (DateTime.now().difference(timestamp) > _cacheExpiry) {
      _chatCache.remove(cacheKey);
      _cacheTimestamps.remove(cacheKey);
      return null;
    }
    
    if (kDebugMode) {
      print('🎯 [CHAT_PERFORMANCE] Cache hit for chat list (${cached.length} chats)');
    }
    
    return cached;
  }

  /// Optimize message list for display
  List<Message> optimizeMessageList(List<Message> messages, {
    int? limit,
    bool reverse = false,
  }) {
    var optimized = List<Message>.from(messages);
    
    // Remove deleted messages
    optimized = optimized.where((m) => !m.isDeleted).toList();
    
    // Sort by creation date
    optimized.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    // Reverse if needed
    if (reverse) {
      optimized = optimized.reversed.toList();
    }
    
    // Apply limit
    if (limit != null && optimized.length > limit) {
      optimized = optimized.take(limit).toList();
    }
    
    _totalMessagesLoaded += optimized.length;
    
    if (kDebugMode) {
      print('⚡ [CHAT_PERFORMANCE] Optimized ${messages.length} messages to ${optimized.length}');
    }
    
    return optimized;
  }

  /// Preload messages for better performance
  Future<void> preloadMessages(int chatId, List<Message> messages) async {
    // Preload in background
    unawaited(_preloadInBackground(chatId, messages));
  }

  Future<void> _preloadInBackground(int chatId, List<Message> messages) async {
    try {
      // Cache messages
      await cacheMessages(chatId, messages);
      
      // Preload related data (user info, etc.)
      await _preloadRelatedData(messages);
      
      if (kDebugMode) {
        print('🔄 [CHAT_PERFORMANCE] Preloaded data for chat $chatId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [CHAT_PERFORMANCE] Error preloading data: $e');
      }
    }
  }

  Future<void> _preloadRelatedData(List<Message> messages) async {
    // This would preload user data, file metadata, etc.
    // Implementation depends on your data structure
  }

  /// Clean up expired cache
  void _cleanupExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > _cacheExpiry) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      _messageCache.remove(key);
      _chatCache.remove(key);
      _cacheTimestamps.remove(key);
    }
    
    if (kDebugMode && expiredKeys.isNotEmpty) {
      print('🧹 [CHAT_PERFORMANCE] Cleaned up ${expiredKeys.length} expired cache entries');
    }
  }

  /// Evict oldest cache entries
  void _evictOldestCache() {
    if (_cacheTimestamps.isEmpty) return;
    
    // Find oldest entry
    String? oldestKey;
    DateTime? oldestTime;
    
    for (final entry in _cacheTimestamps.entries) {
      if (oldestTime == null || entry.value.isBefore(oldestTime)) {
        oldestTime = entry.value;
        oldestKey = entry.key;
      }
    }
    
    if (oldestKey != null) {
      _messageCache.remove(oldestKey);
      _chatCache.remove(oldestKey);
      _cacheTimestamps.remove(oldestKey);
      
      if (kDebugMode) {
        print('🗑️ [CHAT_PERFORMANCE] Evicted oldest cache entry: $oldestKey');
      }
    }
  }

  /// Monitor performance metrics
  void _monitorPerformance() {
    final now = DateTime.now();
    
    if (_lastPerformanceCheck != null) {
      final timeDiff = now.difference(_lastPerformanceCheck!);
      
      if (kDebugMode) {
        print('📊 [CHAT_PERFORMANCE] Performance metrics:');
        print('   - Total messages loaded: $_totalMessagesLoaded');
        print('   - Cache hits: $_cacheHits');
        print('   - Cache misses: $_cacheMisses');
        print('   - Cache hit rate: ${_getCacheHitRate()}%');
        print('   - Time since last check: ${timeDiff.inSeconds}s');
      }
    }
    
    _lastPerformanceCheck = now;
  }

  double _getCacheHitRate() {
    final total = _cacheHits + _cacheMisses;
    if (total == 0) return 0.0;
    return (_cacheHits / total) * 100;
  }

  /// Save cached data to persistent storage
  Future<void> _saveCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save message cache
      final messageCacheJson = jsonEncode(_messageCache);
      await prefs.setString('chat_message_cache', messageCacheJson);
      
      // Save cache timestamps
      final timestampCache = <String, String>{};
      for (final entry in _cacheTimestamps.entries) {
        timestampCache[entry.key] = entry.value.toIso8601String();
      }
      await prefs.setString('chat_cache_timestamps', jsonEncode(timestampCache));
      
      if (kDebugMode) {
        print('💾 [CHAT_PERFORMANCE] Saved cached data to persistent storage');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [CHAT_PERFORMANCE] Error saving cached data: $e');
      }
    }
  }

  /// Load cached data from persistent storage
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load message cache
      final messageCacheJson = prefs.getString('chat_message_cache');
      if (messageCacheJson != null) {
        final messageCache = jsonDecode(messageCacheJson) as Map<String, dynamic>;
        _messageCache.addAll(messageCache);
      }
      
      // Load cache timestamps
      final timestampCacheJson = prefs.getString('chat_cache_timestamps');
      if (timestampCacheJson != null) {
        final timestampCache = jsonDecode(timestampCacheJson) as Map<String, dynamic>;
        for (final entry in timestampCache.entries) {
          _cacheTimestamps[entry.key] = DateTime.parse(entry.value);
        }
      }
      
      if (kDebugMode) {
        print('📥 [CHAT_PERFORMANCE] Loaded cached data from persistent storage');
        print('   - Message cache entries: ${_messageCache.length}');
        print('   - Timestamp entries: ${_cacheTimestamps.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [CHAT_PERFORMANCE] Error loading cached data: $e');
      }
    }
  }

  /// Clear all cache
  Future<void> clearCache() async {
    _messageCache.clear();
    _chatCache.clear();
    _cacheTimestamps.clear();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_message_cache');
    await prefs.remove('chat_cache_timestamps');
    
    if (kDebugMode) {
      print('🧹 [CHAT_PERFORMANCE] Cleared all cache');
    }
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    return {
      'total_messages_loaded': _totalMessagesLoaded,
      'cache_hits': _cacheHits,
      'cache_misses': _cacheMisses,
      'cache_hit_rate': _getCacheHitRate(),
      'cache_size': _messageCache.length,
      'last_performance_check': _lastPerformanceCheck?.toIso8601String(),
    };
  }
}
