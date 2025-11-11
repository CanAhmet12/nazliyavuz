import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Design System
/// Centralized design tokens for consistent UI across the app
class DesignSystem {
  // ============================================================================
  // SPACING - 4px grid system
  // ============================================================================
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  
  // Spacing helpers
  static EdgeInsets spacingAll(double value) => EdgeInsets.all(value);
  static EdgeInsets spacingHorizontal(double value) => EdgeInsets.symmetric(horizontal: value);
  static EdgeInsets spacingVertical(double value) => EdgeInsets.symmetric(vertical: value);
  static EdgeInsets spacingSymmetric({required double horizontal, required double vertical}) =>
      EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  
  // ============================================================================
  // BORDER RADIUS
  // ============================================================================
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;
  static const double radiusPill = 100.0; // For fully rounded elements
  
  // BorderRadius helpers
  static BorderRadius borderRadius(double radius) => BorderRadius.circular(radius);
  static BorderRadius borderRadiusOnly({
    double topLeft = 0,
    double topRight = 0,
    double bottomLeft = 0,
    double bottomRight = 0,
  }) => BorderRadius.only(
    topLeft: Radius.circular(topLeft),
    topRight: Radius.circular(topRight),
    bottomLeft: Radius.circular(bottomLeft),
    bottomRight: Radius.circular(bottomRight),
  );
  
  // ============================================================================
  // SHADOWS
  // ============================================================================
  static const BoxShadow shadowSubtle = BoxShadow(
    color: Color(0x0D000000), // Opacity 0.05
    blurRadius: 4,
    offset: Offset(0, 1),
  );
  
  static const BoxShadow shadowMedium = BoxShadow(
    color: Color(0x1A000000), // Opacity 0.1
    blurRadius: 8,
    offset: Offset(0, 2),
  );
  
  static const BoxShadow shadowStrong = BoxShadow(
    color: Color(0x33000000), // Opacity 0.2
    blurRadius: 12,
    offset: Offset(0, 4),
  );
  
  static const BoxShadow shadowElevated = BoxShadow(
    color: Color(0x40000000), // Opacity 0.25
    blurRadius: 16,
    offset: Offset(0, 6),
  );
  
  // Shadow lists for common use cases
  static List<BoxShadow> get cardShadow => [shadowMedium];
  static List<BoxShadow> get elevatedShadow => [shadowStrong];
  static List<BoxShadow> get buttonShadow => [shadowSubtle];
  
  // ============================================================================
  // ICON SIZES
  // ============================================================================
  static const double iconSmall = 16.0;
  static const double iconMedium = 20.0;
  static const double iconLarge = 24.0;
  static const double iconXLarge = 32.0;
  static const double iconXXLarge = 48.0;
  
  // ============================================================================
  // TYPOGRAPHY
  // ============================================================================
  static const double fontSizeCaption = 12.0;
  static const double fontSizeBodySmall = 14.0;
  static const double fontSizeBody = 16.0;
  static const double fontSizeTitle = 18.0;
  static const double fontSizeHeadline = 20.0;
  static const double fontSizeDisplay = 24.0;
  
  // Typography helpers
  static TextStyle caption({Color? color, FontWeight? weight}) => TextStyle(
    fontSize: fontSizeCaption,
    color: color ?? AppTheme.grey600,
    fontWeight: weight ?? FontWeight.w500,
  );
  
  static TextStyle bodySmall({Color? color, FontWeight? weight}) => TextStyle(
    fontSize: fontSizeBodySmall,
    color: color ?? AppTheme.grey900,
    fontWeight: weight ?? FontWeight.w400,
  );
  
  static TextStyle body({Color? color, FontWeight? weight}) => TextStyle(
    fontSize: fontSizeBody,
    color: color ?? AppTheme.grey900,
    fontWeight: weight ?? FontWeight.w400,
  );
  
  static TextStyle title({Color? color, FontWeight? weight}) => TextStyle(
    fontSize: fontSizeTitle,
    color: color ?? AppTheme.grey900,
    fontWeight: weight ?? FontWeight.w600,
  );
  
  static TextStyle headline({Color? color, FontWeight? weight}) => TextStyle(
    fontSize: fontSizeHeadline,
    color: color ?? AppTheme.grey900,
    fontWeight: weight ?? FontWeight.w700,
  );
  
  // ============================================================================
  // WHATSAPP THEME COLORS (for chat screens)
  // ============================================================================
  static const Color whatsappDarkBg = Color(0xFF0B141A);        // Dark background
  static const Color whatsappDarkBar = Color(0xFF1F2C34);       // AppBar
  static const Color whatsappDarkSecondary = Color(0xFF2A3942); // Input background
  static const Color whatsappDarkTertiary = Color(0xFF202C33);  // Message incoming
  static const Color whatsappGreen = Color(0xFF005C4B);         // Message outgoing
  static const Color whatsappTextPrimary = Color(0xFFE9EDEF);   // Primary text
  static const Color whatsappTextSecondary = Color(0xFF8696A0); // Secondary text
  static const Color whatsappGreenLight = Color(0xFF00A884);    // Accent green
  
  // ============================================================================
  // MODAL BOTTOM SHEET STANDARDS
  // ============================================================================
  static const double modalHandleWidth = 40.0;
  static const double modalHandleHeight = 4.0;
  static const double modalHandleMarginTop = 12.0;
  static const double modalBorderRadius = radiusXLarge;
  static const Color modalHandleColor = Color(0xFFE0E0E0);
  
  // ============================================================================
  // CARD STANDARDS
  // ============================================================================
  static const double cardPadding = lg;
  static const double cardBorderRadius = radiusLarge;
  static const EdgeInsets cardMargin = EdgeInsets.symmetric(horizontal: lg, vertical: sm);
  
  // ============================================================================
  // BUTTON STANDARDS
  // ============================================================================
  static const double buttonHeight = 48.0;
  static const double buttonBorderRadius = radiusMedium;
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: xl, vertical: md);
  
  // ============================================================================
  // DURATION (for animations)
  // ============================================================================
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);
}

/// Common color semantics
class AppColors {
  // Primary colors
  static const Color primary = AppTheme.primaryBlue;
  static const Color primaryDark = AppTheme.primaryBlueDark;
  static const Color primaryLight = AppTheme.primaryBlueLight;
  
  // Status colors
  static const Color success = AppTheme.accentGreen;
  static const Color warning = AppTheme.accentOrange;
  static const Color error = AppTheme.accentRed;
  static const Color info = AppTheme.primaryBlue;
  
  // Background colors
  static const Color background = AppTheme.grey50;
  static const Color surface = AppTheme.white;
  
  // Text colors
  static const Color textPrimary = AppTheme.grey900;
  static const Color textSecondary = AppTheme.grey600;
  static const Color textDisabled = AppTheme.grey400;
  
  // Border colors
  static const Color border = AppTheme.grey300;
  static const Color borderLight = AppTheme.grey200;
}

/// Standard elevation values
class Elevation {
  static const double none = 0;
  static const double small = 2;
  static const double medium = 4;
  static const double large = 8;
  static const double xLarge = 12;
}
