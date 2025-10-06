import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

/// Advanced Network Optimization Service
/// Enterprise-level network performance optimization
class NetworkOptimizationService {
  static final NetworkOptimizationService _instance = NetworkOptimizationService._internal();
  factory NetworkOptimizationService() => _instance;
  NetworkOptimizationService._internal();

  // Request deduplication
  final Map<String, Completer<http.Response>> _pendingRequests = {};
  
  // Response caching
  final Map<String, CacheEntry> _responseCache = {};
  
  // Connection monitoring
  List<ConnectivityResult> _currentConnectivity = [ConnectivityResult.none];
  Timer? _connectivityTimer;
  
  // Performance tracking
  final Map<String, List<Duration>> _requestTimes = {};
  
  // Compression settings
  static const Map<String, String> _compressionHeaders = {
    'Accept-Encoding': 'gzip, deflate, br',
    'Content-Type': 'application/json; charset=utf-8',
  };
  
  /// Initialize network optimization
  Future<void> initialize() async {
    // Start connectivity monitoring
    _startConnectivityMonitoring();
    
    // Clear old cache entries periodically
    Timer.periodic(const Duration(minutes: 5), (_) => _cleanupCache());
    
    if (kDebugMode) {
      debugPrint('🌐 Network Optimization Service initialized');
    }
  }
  
  /// Start connectivity monitoring
  void _startConnectivityMonitoring() {
    _connectivityTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity != _currentConnectivity) {
        _currentConnectivity = connectivity;
        _onConnectivityChanged(connectivity);
      }
    });
  }
  
  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> connectivity) {
    if (kDebugMode) {
      debugPrint('📡 Connectivity changed: $connectivity');
    }
    
    // Clear cache on connectivity change to ensure fresh data
    if (connectivity.contains(ConnectivityResult.none)) {
      _responseCache.clear();
    }
  }
  
  /// Optimized HTTP GET request
  Future<http.Response> get(
    String url, {
    Map<String, String>? headers,
    Duration? cacheDuration,
    bool enableDeduplication = true,
  }) async {
    final startTime = DateTime.now();
    
    // Check cache first
    if (cacheDuration != null) {
      final cachedResponse = _getCachedResponse(url);
      if (cachedResponse != null) {
        debugPrint('📦 Cache hit for: $url');
        return cachedResponse;
      }
    }
    
    // Check for duplicate request
    if (enableDeduplication && _pendingRequests.containsKey(url)) {
      debugPrint('🔄 Deduplicating request: $url');
      return await _pendingRequests[url]!.future;
    }
    
    // Create completer for deduplication
    final completer = Completer<http.Response>();
    if (enableDeduplication) {
      _pendingRequests[url] = completer;
    }
    
    try {
      // Prepare headers
      final requestHeaders = <String, String>{
        ..._compressionHeaders,
        ...?headers,
      };
      
      // Make request
      final response = await http.get(
        Uri.parse(url),
        headers: requestHeaders,
      );
      
      final duration = DateTime.now().difference(startTime);
      _trackRequestTime(url, duration);
      
      // Cache response if successful
      if (cacheDuration != null && response.statusCode == 200) {
        _cacheResponse(url, response, cacheDuration);
      }
      
      completer.complete(response);
      return response;
      
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _pendingRequests.remove(url);
    }
  }
  
  /// Optimized HTTP POST request
  Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    Object? body,
    bool enableCompression = true,
  }) async {
    final startTime = DateTime.now();
    
    try {
      // Prepare headers
      final requestHeaders = <String, String>{
        if (enableCompression) ..._compressionHeaders,
        ...?headers,
      };
      
      // Compress body if needed
      String? requestBody;
      if (body != null) {
        if (body is Map || body is List) {
          requestBody = jsonEncode(body);
        } else {
          requestBody = body.toString();
        }
      }
      
      // Make request
      final response = await http.post(
        Uri.parse(url),
        headers: requestHeaders,
        body: requestBody,
      );
      
      final duration = DateTime.now().difference(startTime);
      _trackRequestTime(url, duration);
      
      return response;
      
    } catch (e) {
      debugPrint('❌ POST request failed: $url - $e');
      rethrow;
    }
  }
  
  /// Batch multiple requests
  Future<List<http.Response>> batchGet(List<String> urls, {
    Map<String, String>? headers,
    Duration? cacheDuration,
  }) async {
    final futures = urls.map((url) => get(
      url,
      headers: headers,
      cacheDuration: cacheDuration,
    ));
    
    return await Future.wait(futures);
  }
  
  /// Get cached response
  http.Response? _getCachedResponse(String url) {
    final entry = _responseCache[url];
    if (entry != null && !entry.isExpired) {
      return entry.response;
    }
    return null;
  }
  
  /// Cache response
  void _cacheResponse(String url, http.Response response, Duration duration) {
    _responseCache[url] = CacheEntry(
      response: response,
      expiresAt: DateTime.now().add(duration),
    );
  }
  
  /// Track request time
  void _trackRequestTime(String url, Duration duration) {
    _requestTimes.putIfAbsent(url, () => []);
    _requestTimes[url]!.add(duration);
    
    // Keep only last 50 measurements per URL
    if (_requestTimes[url]!.length > 50) {
      _requestTimes[url]!.removeAt(0);
    }
    
    // Log slow requests
    if (duration.inMilliseconds > 2000) {
      debugPrint('⚠️ Slow request detected: $url took ${duration.inMilliseconds}ms');
    }
  }
  
  /// Cleanup expired cache entries
  void _cleanupCache() {
    _responseCache.removeWhere((key, entry) => entry.isExpired);
    
    if (kDebugMode) {
      debugPrint('🧹 Cache cleanup completed. Entries: ${_responseCache.length}');
    }
  }
  
  /// Get network performance statistics
  Map<String, dynamic> getPerformanceStats() {
    final stats = <String, dynamic>{};
    
    for (final url in _requestTimes.keys) {
      final times = _requestTimes[url]!;
      if (times.isNotEmpty) {
        final totalMs = times.map((d) => d.inMilliseconds).reduce((a, b) => a + b);
        final avgMs = totalMs / times.length;
        final maxMs = times.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);
        
        stats[url] = {
          'requests': times.length,
          'avg_ms': avgMs,
          'max_ms': maxMs,
          'total_ms': totalMs,
        };
      }
    }
    
    return {
      'connectivity': _currentConnectivity.toString(),
      'cache_entries': _responseCache.length,
      'pending_requests': _pendingRequests.length,
      'request_stats': stats,
    };
  }
  
  /// Clear all caches
  void clearCache() {
    _responseCache.clear();
    _requestTimes.clear();
    debugPrint('🗑️ Network cache cleared');
  }
  
  /// Dispose resources
  void dispose() {
    _connectivityTimer?.cancel();
    _pendingRequests.clear();
    _responseCache.clear();
    _requestTimes.clear();
  }
}

/// Cache entry model
class CacheEntry {
  final http.Response response;
  final DateTime expiresAt;
  
  CacheEntry({
    required this.response,
    required this.expiresAt,
  });
  
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Network-aware widget mixin
mixin NetworkAwareMixin<T extends StatefulWidget> on State<T> {
  List<ConnectivityResult> _connectivity = [ConnectivityResult.none];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  void initConnectivity() async {
    _connectivity = await Connectivity().checkConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> result) {
        if (mounted) {
          setState(() {
            _connectivity = result;
          });
          onConnectivityChanged(result);
        }
      },
    );
  }
  
  void onConnectivityChanged(List<ConnectivityResult> connectivity) {
    // Override in subclasses to handle connectivity changes
  }
  
  bool get isOnline => !_connectivity.contains(ConnectivityResult.none);
  bool get isOffline => _connectivity.contains(ConnectivityResult.none);
  
  void disposeConnectivity() {
    _connectivitySubscription?.cancel();
  }
}

/// Offline-first data service
class OfflineFirstDataService {
  static final OfflineFirstDataService _instance = OfflineFirstDataService._internal();
  factory OfflineFirstDataService() => _instance;
  OfflineFirstDataService._internal();
  
  final Map<String, dynamic> _localCache = {};
  
  /// Get data with offline-first strategy
  Future<dynamic> getData(String key, Future<dynamic> Function() fetchFunction) async {
    // Try local cache first
    if (_localCache.containsKey(key)) {
      debugPrint('📱 Local cache hit: $key');
      return _localCache[key];
    }
    
    // Try network if online
    if (await _isOnline()) {
      try {
        final data = await fetchFunction();
        _localCache[key] = data;
        debugPrint('🌐 Network fetch successful: $key');
        return data;
      } catch (e) {
        debugPrint('❌ Network fetch failed: $key - $e');
      }
    }
    
    // Return null if no data available
    return null;
  }
  
  /// Check if device is online
  Future<bool> _isOnline() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Clear local cache
  void clearCache() {
    _localCache.clear();
    debugPrint('🗑️ Local cache cleared');
  }
}
