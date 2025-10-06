import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  
  bool _isConnected = true;
  ConnectivityResult _currentConnectionType = ConnectivityResult.none;
  Timer? _connectivityTimer;

  /// Stream of connectivity status changes
  Stream<bool> get connectivityStream => _connectivityController.stream;
  
  /// Current connectivity status
  bool get isConnected => _isConnected;
  
  /// Current connection type
  ConnectivityResult get currentConnectionType => _currentConnectionType;
  
  /// Check if connected to WiFi
  bool get isWiFiConnected => _currentConnectionType == ConnectivityResult.wifi;
  
  /// Check if connected to mobile data
  bool get isMobileConnected => _currentConnectionType == ConnectivityResult.mobile;
  
  /// Check if connected to ethernet
  bool get isEthernetConnected => _currentConnectionType == ConnectivityResult.ethernet;

  /// Initialize connectivity service
  Future<void> initialize() async {
    if (kDebugMode) {
      print('🌐 [CONNECTIVITY] Initializing connectivity service...');
    }

    try {
      // Get initial connectivity status
      await _checkConnectivity();
      
      // Listen to connectivity changes
      _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
      
      // Start periodic connectivity check
      _startPeriodicCheck();
      
      if (kDebugMode) {
        print('✅ [CONNECTIVITY] Connectivity service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [CONNECTIVITY] Error initializing: $e');
      }
    }
  }

  /// Check current connectivity status
  Future<void> _checkConnectivity() async {
    try {
      final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
      _currentConnectionType = results.isNotEmpty ? results.first : ConnectivityResult.none;
      _isConnected = _currentConnectionType != ConnectivityResult.none;
      
      if (kDebugMode) {
        print('🌐 [CONNECTIVITY] Status: ${_isConnected ? "Connected" : "Disconnected"} (${_currentConnectionType.name})');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [CONNECTIVITY] Error checking connectivity: $e');
      }
      _isConnected = false;
      _currentConnectionType = ConnectivityResult.none;
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final previousStatus = _isConnected;
    final previousType = _currentConnectionType;
    
    _currentConnectionType = results.isNotEmpty ? results.first : ConnectivityResult.none;
    _isConnected = _currentConnectionType != ConnectivityResult.none;
    
    if (kDebugMode) {
      print('🔄 [CONNECTIVITY] Status changed: ${_isConnected ? "Connected" : "Disconnected"} (${_currentConnectionType.name})');
    }
    
    // Notify listeners if status changed
    if (previousStatus != _isConnected || previousType != _currentConnectionType) {
      _connectivityController.add(_isConnected);
    }
  }

  /// Start periodic connectivity check
  void _startPeriodicCheck() {
    _connectivityTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkConnectivity();
    });
  }

  /// Stop periodic connectivity check
  void _stopPeriodicCheck() {
    _connectivityTimer?.cancel();
    _connectivityTimer = null;
  }

  /// Get detailed connectivity information
  Future<Map<String, dynamic>> getConnectivityInfo() async {
    try {
      final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
      final bool isConnected = results.isNotEmpty && results.first != ConnectivityResult.none;
      
      return {
        'isConnected': isConnected,
        'connectionTypes': results.map((e) => e.name).toList(),
        'primaryConnectionType': results.isNotEmpty ? results.first.name : 'none',
        'isWiFi': results.contains(ConnectivityResult.wifi),
        'isMobile': results.contains(ConnectivityResult.mobile),
        'isEthernet': results.contains(ConnectivityResult.ethernet),
        'isBluetooth': results.contains(ConnectivityResult.bluetooth),
        'isVpn': results.contains(ConnectivityResult.vpn),
        'isOther': results.contains(ConnectivityResult.other),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ [CONNECTIVITY] Error getting connectivity info: $e');
      }
      return {
        'isConnected': false,
        'connectionTypes': <String>[],
        'primaryConnectionType': 'none',
        'isWiFi': false,
        'isMobile': false,
        'isEthernet': false,
        'isBluetooth': false,
        'isVpn': false,
        'isOther': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Wait for connectivity to be available
  Future<bool> waitForConnectivity({Duration timeout = const Duration(seconds: 30)}) async {
    if (_isConnected) {
      return true;
    }

    if (kDebugMode) {
      print('⏳ [CONNECTIVITY] Waiting for connectivity...');
    }

    try {
      await connectivityStream
          .where((connected) => connected)
          .first
          .timeout(timeout);
      
      if (kDebugMode) {
        print('✅ [CONNECTIVITY] Connectivity restored');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('⏰ [CONNECTIVITY] Timeout waiting for connectivity: $e');
      }
      return false;
    }
  }

  /// Check if specific connection type is available
  Future<bool> hasConnectionType(ConnectivityResult type) async {
    try {
      final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
      return results.contains(type);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [CONNECTIVITY] Error checking connection type: $e');
      }
      return false;
    }
  }

  /// Get connection quality indicator
  String getConnectionQuality() {
    if (!_isConnected) {
      return 'No Connection';
    }

    switch (_currentConnectionType) {
      case ConnectivityResult.ethernet:
        return 'Excellent';
      case ConnectivityResult.wifi:
        return 'Good';
      case ConnectivityResult.mobile:
        return 'Fair';
      case ConnectivityResult.bluetooth:
        return 'Poor';
      case ConnectivityResult.vpn:
        return 'Good';
      case ConnectivityResult.other:
        return 'Unknown';
      case ConnectivityResult.none:
        return 'No Connection';
    }
  }

  /// Get connection speed estimate
  String getConnectionSpeed() {
    if (!_isConnected) {
      return '0 Mbps';
    }

    switch (_currentConnectionType) {
      case ConnectivityResult.ethernet:
        return '100+ Mbps';
      case ConnectivityResult.wifi:
        return '10-100 Mbps';
      case ConnectivityResult.mobile:
        return '1-50 Mbps';
      case ConnectivityResult.bluetooth:
        return '1-3 Mbps';
      case ConnectivityResult.vpn:
        return 'Variable';
      case ConnectivityResult.other:
        return 'Unknown';
      case ConnectivityResult.none:
        return '0 Mbps';
    }
  }

  /// Check if connection is suitable for video calls
  bool isSuitableForVideoCalls() {
    return _isConnected && (
      _currentConnectionType == ConnectivityResult.ethernet ||
      _currentConnectionType == ConnectivityResult.wifi ||
      _currentConnectionType == ConnectivityResult.mobile
    );
  }

  /// Check if connection is suitable for file uploads
  bool isSuitableForFileUploads() {
    return _isConnected && (
      _currentConnectionType == ConnectivityResult.ethernet ||
      _currentConnectionType == ConnectivityResult.wifi
    );
  }

  /// Get offline mode recommendation
  String getOfflineModeRecommendation() {
    if (_isConnected) {
      return 'Online mode available';
    }

    switch (_currentConnectionType) {
      case ConnectivityResult.none:
        return 'No internet connection. Some features may be limited.';
      default:
        return 'Connection unstable. Consider using offline mode.';
    }
  }

  /// Dispose resources
  void dispose() {
    _stopPeriodicCheck();
    _connectivityController.close();
    
    if (kDebugMode) {
      print('🗑️ [CONNECTIVITY] Connectivity service disposed');
    }
  }
}
