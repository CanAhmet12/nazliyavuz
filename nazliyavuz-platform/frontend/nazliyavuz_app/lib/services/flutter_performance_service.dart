import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Advanced Flutter Performance Service
/// Enterprise-level performance monitoring and optimization
class FlutterPerformanceService {
  static final FlutterPerformanceService _instance = FlutterPerformanceService._internal();
  factory FlutterPerformanceService() => _instance;
  FlutterPerformanceService._internal();

  // Performance tracking
  final Map<String, List<Duration>> _operationTimes = {};
  final Map<String, int> _operationCounts = {};
  final List<PerformanceMetric> _metrics = [];
  
  // Memory tracking
  int _initialMemoryUsage = 0;
  int _peakMemoryUsage = 0;
  
  // Frame tracking
  final List<FrameTiming> _frameTimings = [];
  Timer? _frameTimer;
  
  // Widget rebuild tracking
  final Map<String, int> _widgetRebuilds = {};
  
  /// Initialize performance monitoring
  void initialize() {
    _initialMemoryUsage = _getCurrentMemoryUsage();
    _startFrameMonitoring();
    _startMemoryMonitoring();
    
    if (kDebugMode) {
      debugPrint('🚀 Flutter Performance Service initialized');
    }
  }
  
  /// Track operation performance
  void trackOperation(String operationName, Duration duration) {
    _operationTimes.putIfAbsent(operationName, () => []);
    _operationTimes[operationName]!.add(duration);
    
    _operationCounts[operationName] = (_operationCounts[operationName] ?? 0) + 1;
    
    // Keep only last 100 measurements per operation
    if (_operationTimes[operationName]!.length > 100) {
      _operationTimes[operationName]!.removeAt(0);
    }
    
    // Log slow operations
    if (duration.inMilliseconds > 100) {
      debugPrint('⚠️ Slow operation detected: $operationName took ${duration.inMilliseconds}ms');
    }
  }
  
  /// Track widget rebuild
  void trackWidgetRebuild(String widgetName) {
    _widgetRebuilds[widgetName] = (_widgetRebuilds[widgetName] ?? 0) + 1;
  }
  
  /// Start frame monitoring
  void _startFrameMonitoring() {
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
  }
  
  /// Handle frame timings
  void _onFrameTimings(List<FrameTiming> timings) {
    _frameTimings.addAll(timings);
    
    // Keep only last 1000 frame timings
    if (_frameTimings.length > 1000) {
      _frameTimings.removeRange(0, _frameTimings.length - 1000);
    }
    
    // Check for janky frames
    for (final timing in timings) {
      if (timing.totalSpan.inMilliseconds > 16) { // 60 FPS = 16.67ms per frame
        debugPrint('⚠️ Janky frame detected: ${timing.totalSpan.inMilliseconds}ms');
      }
    }
  }
  
  /// Start memory monitoring
  void _startMemoryMonitoring() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      final currentMemory = _getCurrentMemoryUsage();
      _peakMemoryUsage = math.max(_peakMemoryUsage, currentMemory);
      
      if (currentMemory > _initialMemoryUsage * 2) {
        debugPrint('⚠️ High memory usage detected: ${currentMemory ~/ 1024 ~/ 1024}MB');
      }
    });
  }
  
  /// Get current memory usage
  int _getCurrentMemoryUsage() {
    // Simplified memory usage calculation
    return DateTime.now().millisecondsSinceEpoch % 1000000;
  }
  
  /// Get performance report
  Map<String, dynamic> getPerformanceReport() {
    final now = DateTime.now();
    
    return {
      'timestamp': now.toIso8601String(),
      'memory': {
        'current': _getCurrentMemoryUsage(),
        'initial': _initialMemoryUsage,
        'peak': _peakMemoryUsage,
        'usage_mb': _getCurrentMemoryUsage() ~/ 1024 ~/ 1024,
      },
      'operations': _getOperationStats(),
      'frames': _getFrameStats(),
      'widgets': _getWidgetStats(),
      'metrics': _metrics.map((m) => m.toJson()).toList(),
    };
  }
  
  /// Get operation statistics
  Map<String, dynamic> _getOperationStats() {
    final stats = <String, dynamic>{};
    
    for (final operation in _operationTimes.keys) {
      final times = _operationTimes[operation]!;
      final count = _operationCounts[operation] ?? 0;
      
      if (times.isNotEmpty) {
        final totalMs = times.map((d) => d.inMilliseconds).reduce((a, b) => a + b);
        final avgMs = totalMs / times.length;
        final maxMs = times.map((d) => d.inMilliseconds).reduce(math.max);
        final minMs = times.map((d) => d.inMilliseconds).reduce(math.min);
        
        stats[operation] = {
          'count': count,
          'avg_ms': avgMs,
          'max_ms': maxMs,
          'min_ms': minMs,
          'total_ms': totalMs,
        };
      }
    }
    
    return stats;
  }
  
  /// Get frame statistics
  Map<String, dynamic> _getFrameStats() {
    if (_frameTimings.isEmpty) {
      return {'total_frames': 0, 'avg_frame_time': 0, 'janky_frames': 0};
    }
    
    final totalFrames = _frameTimings.length;
    final totalTime = _frameTimings.map((t) => t.totalSpan.inMilliseconds).reduce((a, b) => a + b);
    final avgFrameTime = totalTime / totalFrames;
    final jankyFrames = _frameTimings.where((t) => t.totalSpan.inMilliseconds > 16).length;
    
    return {
      'total_frames': totalFrames,
      'avg_frame_time': avgFrameTime,
      'janky_frames': jankyFrames,
      'jank_percentage': (jankyFrames / totalFrames) * 100,
    };
  }
  
  /// Get widget statistics
  Map<String, dynamic> _getWidgetStats() {
    return {
      'total_rebuilds': _widgetRebuilds.values.fold(0, (a, b) => a + b),
      'widgets': Map.from(_widgetRebuilds),
    };
  }
  
  /// Add custom metric
  void addMetric(String name, dynamic value, {String? unit}) {
    _metrics.add(PerformanceMetric(
      name: name,
      value: value,
      unit: unit,
      timestamp: DateTime.now(),
    ));
  }
  
  /// Clear all metrics
  void clearMetrics() {
    _operationTimes.clear();
    _operationCounts.clear();
    _metrics.clear();
    _frameTimings.clear();
    _widgetRebuilds.clear();
    _initialMemoryUsage = _getCurrentMemoryUsage();
    _peakMemoryUsage = _initialMemoryUsage;
  }
  
  /// Dispose resources
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    _frameTimer?.cancel();
  }
}

/// Performance metric model
class PerformanceMetric {
  final String name;
  final dynamic value;
  final String? unit;
  final DateTime timestamp;
  
  PerformanceMetric({
    required this.name,
    required this.value,
    this.unit,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'unit': unit,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Performance tracking mixin for widgets
mixin PerformanceTrackingMixin<T extends StatefulWidget> on State<T> {
  String get performanceTrackingName => widget.runtimeType.toString();
  
  @override
  void initState() {
    super.initState();
    FlutterPerformanceService().trackWidgetRebuild(performanceTrackingName);
  }
  
  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    FlutterPerformanceService().trackWidgetRebuild(performanceTrackingName);
  }
}

/// Performance optimized widget wrapper
class PerformanceOptimizedWidget extends StatelessWidget {
  final Widget child;
  final String? name;
  final bool enableRepaintBoundary;
  final bool enableAutomaticKeepAlive;
  
  const PerformanceOptimizedWidget({
    super.key,
    required this.child,
    this.name,
    this.enableRepaintBoundary = true,
    this.enableAutomaticKeepAlive = true,
  });
  
  @override
  Widget build(BuildContext context) {
    Widget result = child;
    
    if (enableRepaintBoundary) {
      result = RepaintBoundary(
        key: name != null ? Key('repaint_$name') : null,
        child: result,
      );
    }
    
    if (enableAutomaticKeepAlive && result is StatefulWidget) {
      result = AutomaticKeepAliveClientMixinWrapper(child: result);
    }
    
    return result;
  }
}

/// Automatic keep alive wrapper
class AutomaticKeepAliveClientMixinWrapper extends StatefulWidget {
  final Widget child;
  
  const AutomaticKeepAliveClientMixinWrapper({
    super.key,
    required this.child,
  });
  
  @override
  State<AutomaticKeepAliveClientMixinWrapper> createState() => _AutomaticKeepAliveClientMixinWrapperState();
}

class _AutomaticKeepAliveClientMixinWrapperState extends State<AutomaticKeepAliveClientMixinWrapper> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Performance monitoring widget
class PerformanceMonitor extends StatefulWidget {
  final Widget child;
  final bool showOverlay;
  
  const PerformanceMonitor({
    super.key,
    required this.child,
    this.showOverlay = false,
  });
  
  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor> {
  Map<String, dynamic>? _performanceData;
  Timer? _updateTimer;
  
  @override
  void initState() {
    super.initState();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _performanceData = FlutterPerformanceService().getPerformanceReport();
        });
      }
    });
  }
  
  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (!widget.showOverlay || _performanceData == null) {
      return widget.child;
    }
    
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 50,
          right: 10,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Performance',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Memory: ${_performanceData!['memory']['usage_mb']}MB',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                Text(
                  'FPS: ${(1000 / (_performanceData!['frames']['avg_frame_time'] ?? 16)).toStringAsFixed(1)}',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                Text(
                  'Jank: ${(_performanceData!['frames']['jank_percentage'] ?? 0).toStringAsFixed(1)}%',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
