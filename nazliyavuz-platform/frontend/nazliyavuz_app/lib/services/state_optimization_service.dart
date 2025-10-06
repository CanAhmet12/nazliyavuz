import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Advanced State Management Optimization Service
/// Enterprise-level state management with performance optimization
class StateOptimizationService {
  static final StateOptimizationService _instance = StateOptimizationService._internal();
  factory StateOptimizationService() => _instance;
  StateOptimizationService._internal();

  // State tracking
  final Map<String, dynamic> _stateCache = {};
  final Map<String, DateTime> _stateTimestamps = {};
  final Map<String, List<String>> _stateDependencies = {};
  
  // Performance tracking
  final Map<String, int> _stateUpdates = {};
  final Map<String, List<Duration>> _stateUpdateTimes = {};
  
  // State persistence
  final Map<String, dynamic> _persistentState = {};
  
  /// Initialize state optimization
  void initialize() {
    // Start state cleanup timer
    Timer.periodic(const Duration(minutes: 5), (_) => _cleanupState());
    
    if (kDebugMode) {
      debugPrint('🔄 State Optimization Service initialized');
    }
  }
  
  /// Set state with optimization
  void setState(String key, dynamic value, {List<String>? dependencies}) {
    final startTime = DateTime.now();
    
    // Check if state actually changed
    if (_stateCache[key] == value) {
      return; // No change, skip update
    }
    
    // Update state
    _stateCache[key] = value;
    _stateTimestamps[key] = DateTime.now();
    
    // Track dependencies
    if (dependencies != null) {
      _stateDependencies[key] = dependencies;
    }
    
    // Update metrics
    _stateUpdates[key] = (_stateUpdates[key] ?? 0) + 1;
    _trackStateUpdateTime(key, DateTime.now().difference(startTime));
    
    // Notify dependent states
    _notifyDependentStates(key);
    
    if (kDebugMode) {
      debugPrint('🔄 State updated: $key');
    }
  }
  
  /// Get state with caching
  T? getState<T>(String key) {
    return _stateCache[key] as T?;
  }
  
  /// Track state update time
  void _trackStateUpdateTime(String key, Duration duration) {
    _stateUpdateTimes.putIfAbsent(key, () => []);
    _stateUpdateTimes[key]!.add(duration);
    
    // Keep only last 50 measurements per state
    if (_stateUpdateTimes[key]!.length > 50) {
      _stateUpdateTimes[key]!.removeAt(0);
    }
    
    // Log slow state updates
    if (duration.inMilliseconds > 10) {
      debugPrint('⚠️ Slow state update: $key took ${duration.inMilliseconds}ms');
    }
  }
  
  /// Notify dependent states
  void _notifyDependentStates(String changedKey) {
    for (final entry in _stateDependencies.entries) {
      if (entry.value.contains(changedKey)) {
        // Trigger dependent state update
        final dependentKey = entry.key;
        if (_stateCache.containsKey(dependentKey)) {
          // Mark dependent state as dirty
          _stateTimestamps[dependentKey] = DateTime.now();
        }
      }
    }
  }
  
  /// Cleanup old state
  void _cleanupState() {
    final now = DateTime.now();
    final cutoffTime = now.subtract(const Duration(minutes: 30));
    
    // Remove old state entries
    _stateTimestamps.removeWhere((key, timestamp) {
      if (timestamp.isBefore(cutoffTime)) {
        _stateCache.remove(key);
        _stateDependencies.remove(key);
        return true;
      }
      return false;
    });
    
    if (kDebugMode) {
      debugPrint('🧹 State cleanup completed. Active states: ${_stateCache.length}');
    }
  }
  
  /// Get state statistics
  Map<String, dynamic> getStateStats() {
    final updateStats = <String, dynamic>{};
    for (final entry in _stateUpdateTimes.entries) {
      final times = entry.value;
      if (times.isNotEmpty) {
        final avgMs = times.map((d) => d.inMilliseconds).reduce((a, b) => a + b) / times.length;
        updateStats[entry.key] = {
          'updates': _stateUpdates[entry.key] ?? 0,
          'avg_ms': avgMs,
        };
      }
    }
    
    return {
      'total_states': _stateCache.length,
      'total_updates': _stateUpdates.values.fold(0, (a, b) => a + b),
      'persistent_states': _persistentState.length,
      'update_stats': updateStats,
    };
  }
  
  /// Clear all state
  void clearState() {
    _stateCache.clear();
    _stateTimestamps.clear();
    _stateDependencies.clear();
    _stateUpdates.clear();
    _stateUpdateTimes.clear();
    debugPrint('🗑️ State cleared');
  }
  
  /// Dispose resources
  void dispose() {
    clearState();
  }
}

/// Optimized stateful widget mixin
mixin OptimizedStateMixin<W extends StatefulWidget> on State<W> {
  final Map<String, dynamic> _localState = {};
  final Set<String> _dirtyStates = {};
  
  /// Set local state with optimization
  void setLocalState(String key, dynamic value) {
    if (_localState[key] == value) return;
    
    _localState[key] = value;
    _dirtyStates.add(key);
    
    if (mounted) {
      setState(() {});
    }
  }
  
  /// Get local state
  T? getLocalState<T>(String key) {
    return _localState[key] as T?;
  }
  
  /// Clear local state
  void clearLocalState() {
    _localState.clear();
    _dirtyStates.clear();
  }
  
  @override
  void dispose() {
    clearLocalState();
    super.dispose();
  }
}

/// Selective rebuild widget
class SelectiveRebuild extends StatefulWidget {
  final Widget child;
  final List<String> dependencies;
  final Widget Function(BuildContext context, Map<String, dynamic> state) builder;
  
  const SelectiveRebuild({
    super.key,
    required this.child,
    required this.dependencies,
    required this.builder,
  });
  
  @override
  State<SelectiveRebuild> createState() => _SelectiveRebuildState();
}

class _SelectiveRebuildState extends State<SelectiveRebuild> {
  final Map<String, dynamic> _state = {};
  
  @override
  void initState() {
    super.initState();
    _initializeState();
  }
  
  void _initializeState() {
    for (final dependency in widget.dependencies) {
      _state[dependency] = StateOptimizationService().getState(dependency);
    }
  }
  
  void updateState() {
    bool hasChanges = false;
    
    for (final dependency in widget.dependencies) {
      final newValue = StateOptimizationService().getState(dependency);
      if (_state[dependency] != newValue) {
        _state[dependency] = newValue;
        hasChanges = true;
      }
    }
    
    if (hasChanges && mounted) {
      setState(() {});
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _state);
  }
}

/// State persistence service
class StatePersistenceService {
  static final StatePersistenceService _instance = StatePersistenceService._internal();
  factory StatePersistenceService() => _instance;
  StatePersistenceService._internal();
  
  final Map<String, dynamic> _persistentState = {};
  final Map<String, DateTime> _persistenceTimestamps = {};
  
  /// Persist state
  void persistState(String key, dynamic value) {
    _persistentState[key] = value;
    _persistenceTimestamps[key] = DateTime.now();
    
    if (kDebugMode) {
      debugPrint('💾 State persisted: $key');
    }
  }
  
  /// Restore state
  T? restoreState<T>(String key) {
    return _persistentState[key] as T?;
  }
  
  /// Clear persisted state
  void clearPersistedState(String key) {
    _persistentState.remove(key);
    _persistenceTimestamps.remove(key);
  }
  
  /// Get persistence statistics
  Map<String, dynamic> getPersistenceStats() {
    return {
      'persisted_states': _persistentState.length,
      'oldest_persistence': _persistenceTimestamps.values.isNotEmpty 
          ? _persistenceTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b)
          : null,
    };
  }
  
  /// Clear all persisted state
  void clearAllPersistedState() {
    _persistentState.clear();
    _persistenceTimestamps.clear();
    debugPrint('🗑️ All persisted state cleared');
  }
}

/// Memory-efficient list widget
class OptimizedListView extends StatelessWidget {
  final List<Widget> children;
  final ScrollController? controller;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  
  const OptimizedListView({
    super.key,
    required this.children,
    this.controller,
    this.shrinkWrap = false,
    this.physics,
  });
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: children.length,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          key: ValueKey('list_item_$index'),
          child: children[index],
        );
      },
    );
  }
}

/// Optimized grid widget
class OptimizedGridView extends StatelessWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final ScrollController? controller;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  
  const OptimizedGridView({
    super.key,
    required this.children,
    required this.crossAxisCount,
    this.crossAxisSpacing = 0.0,
    this.mainAxisSpacing = 0.0,
    this.controller,
    this.shrinkWrap = false,
    this.physics,
  });
  
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: controller,
      shrinkWrap: shrinkWrap,
      physics: physics,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          key: ValueKey('grid_item_$index'),
          child: children[index],
        );
      },
    );
  }
}

/// State-aware widget
class StateAwareWidget extends StatefulWidget {
  final String stateKey;
  final Widget Function(BuildContext context, dynamic state) builder;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  
  const StateAwareWidget({
    super.key,
    required this.stateKey,
    required this.builder,
    this.loadingWidget,
    this.errorWidget,
  });
  
  @override
  State<StateAwareWidget> createState() => _StateAwareWidgetState();
}

class _StateAwareWidgetState extends State<StateAwareWidget> {
  dynamic _state;
  bool _isLoading = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadState();
  }
  
  void _loadState() async {
    try {
      _state = StateOptimizationService().getState(widget.stateKey);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingWidget ?? const CircularProgressIndicator();
    }
    
    if (_error != null) {
      return widget.errorWidget ?? Text('Error: $_error');
    }
    
    return widget.builder(context, _state);
  }
}
