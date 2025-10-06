import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class BiometricAuthService {
  static final BiometricAuthService _instance = BiometricAuthService._internal();
  factory BiometricAuthService() => _instance;
  BiometricAuthService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricTokenKey = 'biometric_token';

  /// Check if biometric authentication is available on device
  Future<bool> isBiometricAvailable() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      
      if (kDebugMode) {
        print('🔐 [BIOMETRIC] Available: $isAvailable, Supported: $isDeviceSupported');
      }
      
      return isAvailable && isDeviceSupported;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BIOMETRIC] Error checking availability: $e');
      }
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
      
      if (kDebugMode) {
        print('🔐 [BIOMETRIC] Available types: $availableBiometrics');
      }
      
      return availableBiometrics;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BIOMETRIC] Error getting biometric types: $e');
      }
      return [];
    }
  }

  /// Check if biometric authentication is enabled by user
  Future<bool> isBiometricEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_biometricEnabledKey) ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BIOMETRIC] Error checking enabled status: $e');
      }
      return false;
    }
  }

  /// Enable biometric authentication
  Future<bool> enableBiometric() async {
    try {
      // Check if biometric is available
      if (!await isBiometricAvailable()) {
        if (kDebugMode) {
          print('❌ [BIOMETRIC] Biometric not available');
        }
        return false;
      }

      // Authenticate user first
      final bool authenticated = await authenticate(
        reason: 'Biyometrik kimlik doğrulamayı etkinleştirmek için kimliğinizi doğrulayın',
      );

      if (!authenticated) {
        if (kDebugMode) {
          print('❌ [BIOMETRIC] Authentication failed');
        }
        return false;
      }

      // Generate and store biometric token
      final String token = _generateBiometricToken();
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool(_biometricEnabledKey, true);
      await prefs.setString(_biometricTokenKey, token);

      if (kDebugMode) {
        print('✅ [BIOMETRIC] Biometric authentication enabled');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BIOMETRIC] Error enabling biometric: $e');
      }
      return false;
    }
  }

  /// Disable biometric authentication
  Future<bool> disableBiometric() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, false);
      await prefs.remove(_biometricTokenKey);

      if (kDebugMode) {
        print('✅ [BIOMETRIC] Biometric authentication disabled');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BIOMETRIC] Error disabling biometric: $e');
      }
      return false;
    }
  }

  /// Authenticate using biometric
  Future<bool> authenticate({
    required String reason,
    String? fallbackTitle,
    String? cancelTitle,
  }) async {
    try {
      // Check if biometric is available
      if (!await isBiometricAvailable()) {
        if (kDebugMode) {
          print('❌ [BIOMETRIC] Biometric not available for authentication');
        }
        return false;
      }

      final bool authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );

      if (kDebugMode) {
        print('🔐 [BIOMETRIC] Authentication result: $authenticated');
      }

      return authenticated;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BIOMETRIC] Authentication error: $e');
      }
      return false;
    }
  }

  /// Authenticate and get stored token
  Future<String?> authenticateAndGetToken() async {
    try {
      // Check if biometric is enabled
      if (!await isBiometricEnabled()) {
        if (kDebugMode) {
          print('❌ [BIOMETRIC] Biometric not enabled');
        }
        return null;
      }

      // Authenticate user
      final bool authenticated = await authenticate(
        reason: 'Uygulamaya giriş yapmak için kimliğinizi doğrulayın',
      );

      if (!authenticated) {
        if (kDebugMode) {
          print('❌ [BIOMETRIC] Authentication failed');
        }
        return null;
      }

      // Get stored token
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString(_biometricTokenKey);

      if (kDebugMode) {
        print('✅ [BIOMETRIC] Token retrieved successfully');
      }

      return token;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BIOMETRIC] Error getting token: $e');
      }
      return null;
    }
  }

  /// Generate a secure biometric token
  String _generateBiometricToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = (timestamp.hashCode * 1000).toString();
    final combined = '$timestamp-$random-${DateTime.now().microsecondsSinceEpoch}';
    
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    
    return digest.toString();
  }

  /// Get biometric type display name
  String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.fingerprint:
        return 'Parmak İzi';
      case BiometricType.face:
        return 'Yüz Tanıma';
      case BiometricType.iris:
        return 'İris Tanıma';
      case BiometricType.strong:
        return 'Güçlü Biyometrik';
      case BiometricType.weak:
        return 'Zayıf Biyometrik';
    }
  }

  /// Get all available biometric types as display names
  Future<List<String>> getAvailableBiometricNames() async {
    final types = await getAvailableBiometrics();
    return types.map((type) => getBiometricTypeName(type)).toList();
  }

  /// Check if device has strong biometric (Face ID, Touch ID, etc.)
  Future<bool> hasStrongBiometric() async {
    final types = await getAvailableBiometrics();
    return types.contains(BiometricType.strong) || 
           types.contains(BiometricType.face) || 
           types.contains(BiometricType.fingerprint);
  }

  /// Get biometric status summary
  Future<Map<String, dynamic>> getBiometricStatus() async {
    try {
      final isAvailable = await isBiometricAvailable();
      final isEnabled = await isBiometricEnabled();
      final availableTypes = await getAvailableBiometrics();
      final hasStrong = await hasStrongBiometric();

      return {
        'isAvailable': isAvailable,
        'isEnabled': isEnabled,
        'availableTypes': availableTypes,
        'availableTypeNames': availableTypes.map((type) => getBiometricTypeName(type)).toList(),
        'hasStrongBiometric': hasStrong,
        'canEnable': isAvailable && !isEnabled,
        'canDisable': isEnabled,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BIOMETRIC] Error getting status: $e');
      }
      return {
        'isAvailable': false,
        'isEnabled': false,
        'availableTypes': <BiometricType>[],
        'availableTypeNames': <String>[],
        'hasStrongBiometric': false,
        'canEnable': false,
        'canDisable': false,
        'error': e.toString(),
      };
    }
  }
}
