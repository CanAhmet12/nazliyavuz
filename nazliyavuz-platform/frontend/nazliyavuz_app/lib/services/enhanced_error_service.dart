import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../theme/app_theme.dart';

/// Enhanced error handling service with user-friendly messages
class EnhancedErrorService {
  static const Map<String, String> _errorCodeMap = {
    // Authentication errors
    'INVALID_CREDENTIALS': 'E-posta adresi veya şifre hatalı',
    'USER_NOT_FOUND': 'Bu e-posta adresi kayıtlı değil',
    'EMAIL_NOT_VERIFIED': 'E-posta adresinizi doğrulamanız gerekiyor',
    'ACCOUNT_LOCKED': 'Hesabınız geçici olarak kilitlendi',
    'TOO_MANY_ATTEMPTS': 'Çok fazla deneme yaptınız. Lütfen birkaç dakika bekleyin',
    
    // Registration errors
    'EMAIL_ALREADY_EXISTS': 'Bu e-posta adresi zaten kayıtlı',
    'WEAK_PASSWORD': 'Şifre çok zayıf. Daha güçlü bir şifre seçin',
    'INVALID_EMAIL_FORMAT': 'Geçersiz e-posta formatı',
    'NAME_TOO_SHORT': 'İsim çok kısa',
    
    // Validation errors
    'VALIDATION_ERROR': 'Lütfen formu doğru şekilde doldurun',
    'REQUIRED_FIELD': 'Bu alan zorunludur',
    'INVALID_FORMAT': 'Geçersiz format',
    
    // Network errors
    'NETWORK_ERROR': 'İnternet bağlantınızı kontrol edin',
    'TIMEOUT_ERROR': 'Bağlantı zaman aşımına uğradı',
    'SERVER_ERROR': 'Sunucu hatası. Lütfen daha sonra tekrar deneyin',
    'MAINTENANCE_MODE': 'Sistem bakımda. Lütfen daha sonra tekrar deneyin',
    
    // Permission errors
    'PERMISSION_DENIED': 'Bu işlem için yetkiniz yok',
    'UNAUTHORIZED': 'Oturum süreniz dolmuş. Lütfen tekrar giriş yapın',
    'FORBIDDEN': 'Bu içeriğe erişim izniniz yok',
    
    // Business logic errors
    'INSUFFICIENT_BALANCE': 'Yetersiz bakiye',
    'LESSON_ALREADY_BOOKED': 'Bu ders saati zaten rezerve edilmiş',
    'TEACHER_UNAVAILABLE': 'Öğretmen bu saatte müsait değil',
    'ASSIGNMENT_NOT_FOUND': 'Ödev bulunamadı',
    'DEADLINE_PASSED': 'Teslim tarihi geçmiş',
    
    // File upload errors
    'FILE_TOO_LARGE': 'Dosya çok büyük',
    'INVALID_FILE_TYPE': 'Desteklenmeyen dosya türü',
    'UPLOAD_FAILED': 'Dosya yüklenemedi',
  };

  static const Map<int, String> _httpStatusMap = {
    400: 'Geçersiz istek',
    401: 'Oturum süreniz dolmuş. Lütfen tekrar giriş yapın',
    403: 'Bu işlem için yetkiniz yok',
    404: 'Aranan içerik bulunamadı',
    409: 'Bu işlem zaten gerçekleştirilmiş',
    422: 'Lütfen formu doğru şekilde doldurun',
    429: 'Çok fazla istek gönderildi. Lütfen bekleyin',
    500: 'Sunucu hatası. Lütfen daha sonra tekrar deneyin',
    502: 'Geçici sunucu hatası',
    503: 'Sistem bakımda. Lütfen daha sonra tekrar deneyin',
  };

  /// Get user-friendly error message from DioException
  static ErrorInfo parseError(dynamic error) {
    if (error is DioException) {
      return _parseDioError(error);
    } else if (error is String) {
      return _parseStringError(error);
    } else {
      return ErrorInfo(
        message: 'Beklenmeyen bir hata oluştu',
        action: 'Tekrar dene',
        type: ErrorType.unknown,
      );
    }
  }

  static ErrorInfo _parseDioError(DioException error) {
    // Network connectivity errors
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return ErrorInfo(
        message: 'İnternet bağlantınızı kontrol edin',
        action: 'Tekrar dene',
        type: ErrorType.network,
      );
    }

    if (error.type == DioExceptionType.connectionError) {
      return ErrorInfo(
        message: 'İnternet bağlantınızı kontrol edin',
        action: 'Tekrar dene',
        type: ErrorType.network,
      );
    }

    // Server response errors
    if (error.response != null) {
      final responseData = error.response!.data;
      final statusCode = error.response!.statusCode!;

      // Try to parse backend error response
      if (responseData is Map<String, dynamic>) {
        final backendError = _parseBackendError(responseData);
        if (backendError != null) {
          return backendError;
        }
      }

      // Fallback to HTTP status code mapping
      final statusMessage = _httpStatusMap[statusCode];
      if (statusMessage != null) {
        return ErrorInfo(
          message: statusMessage,
          action: _getActionForStatusCode(statusCode),
          type: _getErrorTypeForStatusCode(statusCode),
        );
      }
    }

    // Generic error
    return ErrorInfo(
      message: 'Bir hata oluştu. Lütfen tekrar deneyin',
      action: 'Tekrar dene',
      type: ErrorType.unknown,
    );
  }

  static ErrorInfo? _parseBackendError(Map<String, dynamic> responseData) {
    if (responseData.containsKey('error')) {
      final errorData = responseData['error'];
      if (errorData is Map<String, dynamic>) {
        final code = errorData['code']?.toString();
        final message = errorData['message'];

        // Handle validation errors
        if (code == 'VALIDATION_ERROR' && message is Map<String, dynamic>) {
          return ErrorInfo(
            message: 'Lütfen formu doğru şekilde doldurun',
            action: 'Formu kontrol et',
            type: ErrorType.validation,
            fieldErrors: message.map((key, value) => MapEntry(
              key,
              value is List ? value.first.toString() : value.toString(),
            )),
          );
        }

        // Handle specific error codes
        if (code != null && _errorCodeMap.containsKey(code)) {
          return ErrorInfo(
            message: _errorCodeMap[code]!,
            action: _getActionForErrorCode(code),
            type: _getErrorTypeForErrorCode(code),
          );
        }

        // Handle direct message
        if (message is String) {
          return ErrorInfo(
            message: message,
            action: 'Tekrar dene',
            type: ErrorType.business,
          );
        }
      }
    }

    return null;
  }

  static ErrorInfo _parseStringError(String error) {
    final lowerError = error.toLowerCase();
    
    if (lowerError.contains('socketexception') ||
        lowerError.contains('network') ||
        lowerError.contains('connection')) {
      return ErrorInfo(
        message: 'İnternet bağlantınızı kontrol edin',
        action: 'Tekrar dene',
        type: ErrorType.network,
      );
    }

    if (lowerError.contains('timeout')) {
      return ErrorInfo(
        message: 'Bağlantı zaman aşımına uğradı',
        action: 'Tekrar dene',
        type: ErrorType.network,
      );
    }

    return ErrorInfo(
      message: error,
      action: 'Tekrar dene',
      type: ErrorType.unknown,
    );
  }

  static String? _getActionForStatusCode(int statusCode) {
    switch (statusCode) {
      case 401:
        return 'Giriş yap';
      case 403:
        return 'Yetki al';
      case 404:
        return 'Ana sayfaya dön';
      case 429:
        return 'Bekle';
      case 500:
      case 502:
      case 503:
        return 'Tekrar dene';
      default:
        return 'Tekrar dene';
    }
  }

  static String? _getActionForErrorCode(String code) {
    switch (code) {
      case 'INVALID_CREDENTIALS':
      case 'USER_NOT_FOUND':
        return 'Kayıt ol';
      case 'EMAIL_ALREADY_EXISTS':
        return 'Giriş yap';
      case 'EMAIL_NOT_VERIFIED':
        return 'E-posta doğrula';
      case 'TOO_MANY_ATTEMPTS':
        return 'Bekle';
      case 'NETWORK_ERROR':
      case 'TIMEOUT_ERROR':
        return 'Tekrar dene';
      case 'UNAUTHORIZED':
        return 'Giriş yap';
      default:
        return 'Tekrar dene';
    }
  }

  static ErrorType _getErrorTypeForStatusCode(int statusCode) {
    if (statusCode >= 400 && statusCode < 500) {
      return ErrorType.client;
    } else if (statusCode >= 500) {
      return ErrorType.server;
    }
    return ErrorType.unknown;
  }

  static ErrorType _getErrorTypeForErrorCode(String code) {
    if (code.contains('CREDENTIALS') || code.contains('AUTH')) {
      return ErrorType.authentication;
    } else if (code.contains('VALIDATION') || code.contains('FORMAT')) {
      return ErrorType.validation;
    } else if (code.contains('NETWORK') || code.contains('TIMEOUT')) {
      return ErrorType.network;
    } else if (code.contains('PERMISSION') || code.contains('UNAUTHORIZED')) {
      return ErrorType.permission;
    }
    return ErrorType.business;
  }

  /// Show error dialog with action button
  static void showErrorDialog(
    BuildContext context,
    ErrorInfo errorInfo, {
    VoidCallback? onActionPressed,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              _getIconForErrorType(errorInfo.type),
              color: _getColorForErrorType(errorInfo.type),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _getTitleForErrorType(errorInfo.type),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          errorInfo.message,
          style: const TextStyle(
            fontSize: 16,
            height: 1.4,
          ),
        ),
        actions: [
          if (errorInfo.action != null) ...[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (onActionPressed != null) {
                  onActionPressed();
                }
              },
              child: Text(
                errorInfo.action!,
                style: TextStyle(
                  color: _getColorForErrorType(errorInfo.type),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Tamam',
              style: TextStyle(
                color: AppTheme.grey600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _getIconForErrorType(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Icons.wifi_off;
      case ErrorType.authentication:
        return Icons.lock_outline;
      case ErrorType.validation:
        return Icons.error_outline;
      case ErrorType.permission:
        return Icons.block;
      case ErrorType.server:
        return Icons.dns;
      case ErrorType.client:
        return Icons.warning;
      case ErrorType.business:
        return Icons.info_outline;
      default:
        return Icons.error;
    }
  }

  static Color _getColorForErrorType(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Colors.orange;
      case ErrorType.authentication:
        return Colors.red;
      case ErrorType.validation:
        return Colors.amber;
      case ErrorType.permission:
        return Colors.red;
      case ErrorType.server:
        return Colors.red;
      case ErrorType.client:
        return Colors.amber;
      case ErrorType.business:
        return Colors.blue;
      default:
        return AppTheme.error;
    }
  }

  static String _getTitleForErrorType(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return 'Bağlantı Hatası';
      case ErrorType.authentication:
        return 'Giriş Hatası';
      case ErrorType.validation:
        return 'Doğrulama Hatası';
      case ErrorType.permission:
        return 'Yetki Hatası';
      case ErrorType.server:
        return 'Sunucu Hatası';
      case ErrorType.client:
        return 'İstek Hatası';
      case ErrorType.business:
        return 'İşlem Hatası';
      default:
        return 'Hata';
    }
  }
}

class ErrorInfo {
  final String message;
  final String? action;
  final ErrorType type;
  final Map<String, String>? fieldErrors;

  const ErrorInfo({
    required this.message,
    this.action,
    required this.type,
    this.fieldErrors,
  });
}

enum ErrorType {
  network,
  authentication,
  validation,
  permission,
  server,
  client,
  business,
  unknown,
}
