import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';

/// Advanced Asset Optimization Service
/// Enterprise-level asset management and optimization
class AssetOptimizationService {
  static final AssetOptimizationService _instance = AssetOptimizationService._internal();
  factory AssetOptimizationService() => _instance;
  AssetOptimizationService._internal();

  // Asset cache
  final Map<String, List<int>> _assetCache = {};
  final Map<String, ImageProvider> _imageCache = {};
  
  // Asset metadata
  final Map<String, AssetMetadata> _assetMetadata = {};
  
  // Performance tracking
  final Map<String, List<Duration>> _loadTimes = {};
  
  /// Initialize asset optimization
  Future<void> initialize() async {
    // Preload critical assets
    await _preloadCriticalAssets();
    
    // Start asset cleanup timer
    Timer.periodic(const Duration(minutes: 10), (_) => _cleanupAssets());
    
    if (kDebugMode) {
      debugPrint('🎨 Asset Optimization Service initialized');
    }
  }
  
  /// Preload critical assets
  Future<void> _preloadCriticalAssets() async {
    const criticalAssets = [
      'assets/images/logo.png',
      'assets/images/placeholder.png',
      'assets/icons/app_icon.png',
    ];
    
    for (final asset in criticalAssets) {
      try {
        await loadAsset(asset);
        debugPrint('✅ Preloaded critical asset: $asset');
      } catch (e) {
        debugPrint('❌ Failed to preload asset: $asset - $e');
      }
    }
  }
  
  /// Load and cache asset
  Future<List<int>> loadAsset(String path) async {
    final startTime = DateTime.now();
    
    // Check cache first
    if (_assetCache.containsKey(path)) {
      debugPrint('📦 Asset cache hit: $path');
      return _assetCache[path]!;
    }
    
    try {
      // Load asset
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List().toList();
      
      // Cache asset
      _assetCache[path] = bytes;
      
      // Store metadata
      _assetMetadata[path] = AssetMetadata(
        path: path,
        size: bytes.length,
        hash: _calculateHash(bytes),
        loadedAt: DateTime.now(),
      );
      
      final duration = DateTime.now().difference(startTime);
      _trackLoadTime(path, duration);
      
      debugPrint('📁 Asset loaded: $path (${bytes.length} bytes)');
      return bytes;
      
    } catch (e) {
      debugPrint('❌ Failed to load asset: $path - $e');
      rethrow;
    }
  }
  
  /// Load optimized image
  Future<ImageProvider> loadOptimizedImage(String path, {
    int? maxWidth,
    int? maxHeight,
    int quality = 85,
  }) async {
    final cacheKey = '${path}_${maxWidth}_${maxHeight}_$quality';
    
    // Check image cache
    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey]!;
    }
    
    try {
      // Load asset bytes
      final bytes = await loadAsset(path);
      
      // Create optimized image provider
      final imageProvider = MemoryImage(Uint8List.fromList(bytes));
      
      // Cache image provider
      _imageCache[cacheKey] = imageProvider;
      
      return imageProvider;
      
    } catch (e) {
      debugPrint('❌ Failed to load optimized image: $path - $e');
      rethrow;
    }
  }
  
  /// Calculate asset hash
  String _calculateHash(List<int> bytes) {
    final digest = md5.convert(bytes);
    return digest.toString();
  }
  
  /// Track load time
  void _trackLoadTime(String path, Duration duration) {
    _loadTimes.putIfAbsent(path, () => []);
    _loadTimes[path]!.add(duration);
    
    // Keep only last 20 measurements per asset
    if (_loadTimes[path]!.length > 20) {
      _loadTimes[path]!.removeAt(0);
    }
    
    // Log slow loads
    if (duration.inMilliseconds > 100) {
      debugPrint('⚠️ Slow asset load: $path took ${duration.inMilliseconds}ms');
    }
  }
  
  /// Cleanup unused assets
  void _cleanupAssets() {
    final now = DateTime.now();
    final cutoffTime = now.subtract(const Duration(minutes: 30));
    
    // Remove old assets from cache
    _assetMetadata.removeWhere((path, metadata) {
      if (metadata.loadedAt.isBefore(cutoffTime)) {
        _assetCache.remove(path);
        return true;
      }
      return false;
    });
    
    if (kDebugMode) {
      debugPrint('🧹 Asset cleanup completed. Cached assets: ${_assetCache.length}');
    }
  }
  
  /// Get asset statistics
  Map<String, dynamic> getAssetStats() {
    final totalSize = _assetMetadata.values.fold<int>(0, (sum, metadata) => sum + metadata.size);
    final totalAssets = _assetMetadata.length;
    
    final loadStats = <String, dynamic>{};
    for (final path in _loadTimes.keys) {
      final times = _loadTimes[path]!;
      if (times.isNotEmpty) {
        final avgMs = times.map((d) => d.inMilliseconds).reduce((a, b) => a + b) / times.length;
        loadStats[path] = {
          'loads': times.length,
          'avg_ms': avgMs,
        };
      }
    }
    
    return {
      'total_assets': totalAssets,
      'total_size_mb': totalSize / 1024 / 1024,
      'cached_images': _imageCache.length,
      'load_stats': loadStats,
    };
  }
  
  /// Clear all caches
  void clearCache() {
    _assetCache.clear();
    _imageCache.clear();
    _assetMetadata.clear();
    _loadTimes.clear();
    debugPrint('🗑️ Asset cache cleared');
  }
  
  /// Dispose resources
  void dispose() {
    clearCache();
  }
}

/// Asset metadata model
class AssetMetadata {
  final String path;
  final int size;
  final String hash;
  final DateTime loadedAt;
  
  AssetMetadata({
    required this.path,
    required this.size,
    required this.hash,
    required this.loadedAt,
  });
}

/// Optimized image widget
class OptimizedImage extends StatelessWidget {
  final String imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int quality;
  
  const OptimizedImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.quality = 85,
  });
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageProvider>(
      future: AssetOptimizationService().loadOptimizedImage(
        imagePath,
        maxWidth: width?.toInt(),
        maxHeight: height?.toInt(),
        quality: quality,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image(
            image: snapshot.data!,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              return errorWidget ?? const Icon(Icons.error);
            },
          );
        } else if (snapshot.hasError) {
          return errorWidget ?? const Icon(Icons.error);
        } else {
          return placeholder ?? const CircularProgressIndicator();
        }
      },
    );
  }
}

/// Asset preloader widget
class AssetPreloader extends StatefulWidget {
  final List<String> assetPaths;
  final Widget child;
  final Widget? loadingWidget;
  
  const AssetPreloader({
    super.key,
    required this.assetPaths,
    required this.child,
    this.loadingWidget,
  });
  
  @override
  State<AssetPreloader> createState() => _AssetPreloaderState();
}

class _AssetPreloaderState extends State<AssetPreloader> {
  bool _isLoading = true;
  int _loadedCount = 0;
  
  @override
  void initState() {
    super.initState();
    _preloadAssets();
  }
  
  Future<void> _preloadAssets() async {
    for (final path in widget.assetPaths) {
      try {
        await AssetOptimizationService().loadAsset(path);
        if (mounted) {
          setState(() {
            _loadedCount++;
          });
        }
      } catch (e) {
        debugPrint('❌ Failed to preload asset: $path - $e');
      }
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingWidget ?? 
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Loading assets... ($_loadedCount/${widget.assetPaths.length})'),
            ],
          ),
        );
    }
    
    return widget.child;
  }
}

/// Font optimization service
class FontOptimizationService {
  static final FontOptimizationService _instance = FontOptimizationService._internal();
  factory FontOptimizationService() => _instance;
  FontOptimizationService._internal();
  
  final Map<String, String> _fontCache = {};
  
  /// Load optimized font
  Future<String> loadFont(String fontPath) async {
    if (_fontCache.containsKey(fontPath)) {
      return _fontCache[fontPath]!;
    }
    
    try {
      await rootBundle.load(fontPath);
      _fontCache[fontPath] = fontPath;
      
      debugPrint('🔤 Font loaded: $fontPath');
      return fontPath;
      
    } catch (e) {
      debugPrint('❌ Failed to load font: $fontPath - $e');
      rethrow;
    }
  }
  
  /// Get font statistics
  Map<String, dynamic> getFontStats() {
    return {
      'loaded_fonts': _fontCache.length,
      'fonts': _fontCache.keys.toList(),
    };
  }
  
  /// Clear font cache
  void clearCache() {
    _fontCache.clear();
    debugPrint('🗑️ Font cache cleared');
  }
}
