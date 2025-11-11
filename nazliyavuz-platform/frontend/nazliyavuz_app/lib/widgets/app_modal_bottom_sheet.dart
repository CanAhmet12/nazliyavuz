import 'package:flutter/material.dart';
import '../theme/design_system.dart';
import '../theme/app_theme.dart';

/// Standardized Modal Bottom Sheet Helper
/// Provides consistent modal bottom sheet styling across the app
class AppModalBottomSheet {
  /// Shows a standard modal bottom sheet with consistent styling
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isScrollControlled = false,
    bool enableDrag = true,
    double? maxHeight,
    bool showHandle = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: isScrollControlled,
      enableDrag: enableDrag,
      builder: (context) => ConstrainedBox(
        constraints: maxHeight != null 
            ? BoxConstraints(maxHeight: maxHeight)
            : const BoxConstraints(),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(DesignSystem.radiusXLarge),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              if (showHandle)
                Container(
                  margin: EdgeInsets.only(top: DesignSystem.modalHandleMarginTop),
                  width: DesignSystem.modalHandleWidth,
                  height: DesignSystem.modalHandleHeight,
                  decoration: BoxDecoration(
                    color: DesignSystem.modalHandleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              
              // Title
              if (title != null) ...[
                Padding(
                  padding: EdgeInsets.all(DesignSystem.xl),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.grey900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
              
              // Content
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Shows a modal bottom sheet with custom content and optional close button
  static Future<T?> showCustom<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool showCloseButton = true,
    bool isScrollControlled = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: isScrollControlled,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DesignSystem.radiusXLarge),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: EdgeInsets.only(top: DesignSystem.modalHandleMarginTop),
              width: DesignSystem.modalHandleWidth,
              height: DesignSystem.modalHandleHeight,
              decoration: BoxDecoration(
                color: DesignSystem.modalHandleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header with title and close button
            if (title != null) ...[
              Padding(
                padding: EdgeInsets.all(DesignSystem.xl),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: DesignSystem.headline(
                          color: AppTheme.grey900,
                        ),
                      ),
                    ),
                    if (showCloseButton)
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: AppTheme.grey600,
                          size: DesignSystem.iconLarge,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                  ],
                ),
              ),
            ],
            
            // Content
            child,
          ],
        ),
      ),
    );
  }
  
  /// Shows a full-screen modal bottom sheet
  static Future<T?> showFullScreen<T>({
    required BuildContext context,
    required Widget child,
    String? title,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DesignSystem.radiusXLarge),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: EdgeInsets.only(top: DesignSystem.modalHandleMarginTop),
              width: DesignSystem.modalHandleWidth,
              height: DesignSystem.modalHandleHeight,
              decoration: BoxDecoration(
                color: DesignSystem.modalHandleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            if (title != null)
              Padding(
                padding: EdgeInsets.all(DesignSystem.xl),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: DesignSystem.headline(
                          color: AppTheme.grey900,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppTheme.grey600,
                        size: DesignSystem.iconLarge,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            
            // Content
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
