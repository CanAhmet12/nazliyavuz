import 'package:flutter/material.dart';

/// Skeleton loading widget for better user experience
class SkeletonLoading extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final EdgeInsets? margin;
  final Widget? child;

  const SkeletonLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
    this.margin,
    this.child,
  });

  @override
  State<SkeletonLoading> createState() => _SkeletonLoadingState();
}

class _SkeletonLoadingState extends State<SkeletonLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.grey[300]!,
            Colors.grey[100]!,
            Colors.grey[300]!,
          ],
          stops: [
            0.0,
            0.5,
            1.0,
          ],
          transform: _SkeletonGradientTransform(_animation.value),
        ),
      ),
      child: widget.child,
    );
  }
}

class _SkeletonGradientTransform extends GradientTransform {
  final double animationValue;

  _SkeletonGradientTransform(this.animationValue);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * animationValue - bounds.width,
      0.0,
      0.0,
    );
  }
}

/// Skeleton card for list items
class SkeletonCard extends StatelessWidget {
  final double? width;
  final double? height;
  final EdgeInsets? margin;

  const SkeletonCard({
    super.key,
    this.width,
    this.height,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height ?? 120,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile section
          Row(
            children: [
              SkeletonLoading(
                width: 50,
                height: 50,
                borderRadius: BorderRadius.circular(25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoading(
                      width: double.infinity,
                      height: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    SkeletonLoading(
                      width: 120,
                      height: 14,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Content section
          SkeletonLoading(
            width: double.infinity,
            height: 14,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          SkeletonLoading(
            width: 200,
            height: 14,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

/// Skeleton list for multiple items
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index)? itemBuilder;
  final EdgeInsets? padding;

  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemBuilder,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding ?? const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: itemBuilder ?? (context, index) => const SkeletonCard(),
    );
  }
}

/// Skeleton grid for grid layouts
class SkeletonGrid extends StatelessWidget {
  final int itemCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final int crossAxisCount;
  final EdgeInsets? padding;

  const SkeletonGrid({
    super.key,
    this.itemCount = 6,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
    this.crossAxisCount = 2,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding ?? const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: 0.8,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const SkeletonCard(),
    );
  }
}

/// Skeleton for text content
class SkeletonText extends StatelessWidget {
  final int lines;
  final double? width;
  final double lineHeight;
  final EdgeInsets? margin;

  const SkeletonText({
    super.key,
    this.lines = 3,
    this.width,
    this.lineHeight = 16,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(lines, (index) {
          double currentWidth = width ?? double.infinity;
          if (index == lines - 1) {
            currentWidth = (width ?? double.infinity) * 0.7;
          }
          
          return Container(
            margin: EdgeInsets.only(bottom: index < lines - 1 ? 8 : 0),
            child: SkeletonLoading(
              width: currentWidth,
              height: lineHeight,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}
