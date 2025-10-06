import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class ErrorHandlerService {
  /// Handle API errors and show user-friendly messages
  static void handleError(BuildContext context, dynamic error, {String? customMessage}) {
    if (kDebugMode) {
      print('❌ [ERROR_HANDLER] Error: $error');
    }
    
    String message = customMessage ?? _getErrorMessage(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Tamam',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  /// Handle API errors silently (for background operations)
  static void handleErrorSilently(dynamic error) {
    if (kDebugMode) {
      print('❌ [ERROR_HANDLER_SILENT] Error: $error');
    }
  }
  
  /// Get user-friendly error message
  static String _getErrorMessage(dynamic error) {
    String errorString = error.toString().toLowerCase();
    
    // Network errors
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'İnternet bağlantınızı kontrol edin';
    }
    
    // Timeout errors
    if (errorString.contains('timeout')) {
      return 'Bağlantı zaman aşımına uğradı, lütfen tekrar deneyin';
    }
    
    // Server errors
    if (errorString.contains('500') || errorString.contains('server error')) {
      return 'Sunucu hatası, lütfen daha sonra tekrar deneyin';
    }
    
    // Authentication errors
    if (errorString.contains('401') || errorString.contains('unauthorized')) {
      return 'Oturum süreniz dolmuş, lütfen tekrar giriş yapın';
    }
    
    // Not found errors
    if (errorString.contains('404') || errorString.contains('not found')) {
      return 'Aranan içerik bulunamadı';
    }
    
    // Validation errors
    if (errorString.contains('validation') || errorString.contains('invalid')) {
      return 'Girdiğiniz bilgilerde hata var, lütfen kontrol edin';
    }
    
    // Default error message
    return 'Beklenmeyen bir hata oluştu, lütfen tekrar deneyin';
  }
  
  /// Show success message
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Tamam',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  /// Show info message
  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Tamam',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  /// Show warning message
  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Tamam',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}
