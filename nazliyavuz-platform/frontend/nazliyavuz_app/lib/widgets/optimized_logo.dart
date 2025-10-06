import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Optimized logo widget with caching, preloading, and multiple resolutions
class OptimizedLogo extends StatelessWidget {
  final double size;
  final BoxFit fit;
  final Color? color;
  final bool enableCache;
  final FilterQuality filterQuality;

  const OptimizedLogo({
    super.key,
    required this.size,
    this.fit = BoxFit.contain,
    this.color,
    this.enableCache = true,
    this.filterQuality = FilterQuality.high,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate cache dimensions (2x for high DPI)
    final cacheSize = (size * 2).round();
    
    debugPrint('🔍 [OPTIMIZED_LOGO] Building logo with size: $size');
    debugPrint('🔍 [OPTIMIZED_LOGO] Cache size: $cacheSize');
    debugPrint('🔍 [OPTIMIZED_LOGO] Enable cache: $enableCache');
    
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: fit,
      color: color, // Bu logo'yu beyaz yapıyor!
      filterQuality: filterQuality,
      cacheWidth: enableCache ? cacheSize : null,
      cacheHeight: enableCache ? cacheSize : null,
      errorBuilder: (context, error, stackTrace) {
        // Debug: Print error information
        debugPrint('❌ [OPTIMIZED_LOGO] Logo loading error: $error');
        debugPrint('❌ [OPTIMIZED_LOGO] Stack trace: $stackTrace');
        
        // Fallback to icon if logo fails to load
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(size * 0.2),
          ),
          child: Icon(
            Icons.school_rounded,
            size: size * 0.6,
            color: Colors.white,
          ),
        );
      },
    );
  }

  /// Preload logo for better performance
  static Future<void> preload(BuildContext context) async {
    try {
      await precacheImage(
        const AssetImage('assets/images/logo.png'),
        context,
      );
    } catch (e) {
      // Silently handle preload errors
      debugPrint('Logo preload failed: $e');
    }
  }

  /// Preload logo with specific size
  static Future<void> preloadWithSize(
    BuildContext context, {
    required double size,
  }) async {
    try {
      final imageProvider = AssetImage('assets/images/logo.png');
      await precacheImage(imageProvider, context);
      
      // Also cache with specific dimensions
      await imageProvider.resolve(ImageConfiguration(
        size: Size(size, size),
        devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
      ));
    } catch (e) {
      debugPrint('Logo preload with size failed: $e');
    }
  }
}

/// Animated logo widget with smooth transitions
class AnimatedOptimizedLogo extends StatefulWidget {
  final double size;
  final BoxFit fit;
  final Color? color;
  final Duration duration;
  final Curve curve;
  final bool enablePulse;
  final double pulseScale;

  const AnimatedOptimizedLogo({
    super.key,
    required this.size,
    this.fit = BoxFit.contain,
    this.color,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.enablePulse = false,
    this.pulseScale = 1.1,
  });

  @override
  State<AnimatedOptimizedLogo> createState() => _AnimatedOptimizedLogoState();
}

class _AnimatedOptimizedLogoState extends State<AnimatedOptimizedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    // Start animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.enablePulse 
              ? _scaleAnimation.value * (1.0 + 0.1 * _scaleAnimation.value)
              : _scaleAnimation.value,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: OptimizedLogo(
              size: widget.size,
              fit: widget.fit,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}

/// Logo with shimmer effect
class ShimmerOptimizedLogo extends StatefulWidget {
  final double size;
  final BoxFit fit;
  final Color? color;
  final Color shimmerColor;
  final Duration shimmerDuration;

  const ShimmerOptimizedLogo({
    super.key,
    required this.size,
    this.fit = BoxFit.contain,
    this.color,
    this.shimmerColor = Colors.white,
    this.shimmerDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<ShimmerOptimizedLogo> createState() => _ShimmerOptimizedLogoState();
}

class _ShimmerOptimizedLogoState extends State<ShimmerOptimizedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.shimmerDuration,
      vsync: this,
    );

    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                widget.shimmerColor.withOpacity(0.3),
                Colors.transparent,
              ],
              stops: [
                0.0,
                0.5,
                1.0,
              ],
              transform: GradientRotation(_shimmerAnimation.value * 3.14159),
            ).createShader(bounds);
          },
          child: OptimizedLogo(
            size: widget.size,
            fit: widget.fit,
            color: widget.color,
          ),
        );
      },
    );
  }
}
