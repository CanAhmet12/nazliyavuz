import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'api_service.dart';

class SocialAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Android için SHA-1 fingerprint eklenmeli
    // iOS için bundle ID eklenmeli
  );
  
  static final ApiService _apiService = ApiService();

  /// Google ile giriş yap
  static Future<Map<String, dynamic>?> signInWithGoogle() async {
    if (kDebugMode) {
      print('🔐 [SOCIAL_AUTH] Starting Google sign-in...');
    }

    try {
      // Google Sign-In işlemi
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        if (kDebugMode) {
          print('❌ [SOCIAL_AUTH] Google sign-in cancelled by user');
        }
        return null;
      }

      // Authentication detaylarını al
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.accessToken == null) {
        if (kDebugMode) {
          print('❌ [SOCIAL_AUTH] Google access token is null');
        }
        throw Exception('Google access token alınamadı');
      }

      if (kDebugMode) {
        print('✅ [SOCIAL_AUTH] Google authentication successful');
        print('✅ [SOCIAL_AUTH] User: ${googleUser.email}');
      }

      // Backend'e gönder
      final result = await _apiService.googleLogin(
        accessToken: googleAuth.accessToken!,
        idToken: googleAuth.idToken,
      );

      if (kDebugMode) {
        print('✅ [SOCIAL_AUTH] Backend authentication successful');
      }

      return result;

    } catch (e) {
      if (kDebugMode) {
        print('❌ [SOCIAL_AUTH] Google sign-in failed: $e');
      }
      rethrow;
    }
  }

  /// Apple ile giriş yap
  static Future<Map<String, dynamic>?> signInWithApple() async {
    if (kDebugMode) {
      print('🍎 [SOCIAL_AUTH] Starting Apple sign-in...');
    }

    try {
      // Apple Sign-In sadece iOS ve macOS'da destekleniyor
      if (!Platform.isIOS && !Platform.isMacOS) {
        throw Exception('Apple Sign-In sadece iOS ve macOS\'ta desteklenir');
      }

      // Apple Sign-In işlemi
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      if (kDebugMode) {
        print('✅ [SOCIAL_AUTH] Apple authentication successful');
        print('✅ [SOCIAL_AUTH] User ID: ${credential.userIdentifier}');
      }

      // Backend'e gönder
      final result = await _apiService.appleLogin(
        identityToken: credential.identityToken!,
        authorizationCode: credential.authorizationCode,
      );

      if (kDebugMode) {
        print('✅ [SOCIAL_AUTH] Backend authentication successful');
      }

      return result;

    } catch (e) {
      if (kDebugMode) {
        print('❌ [SOCIAL_AUTH] Apple sign-in failed: $e');
      }
      rethrow;
    }
  }

  /// Google hesabından çıkış yap
  static Future<void> signOutGoogle() async {
    try {
      await _googleSignIn.signOut();
      if (kDebugMode) {
        print('✅ [SOCIAL_AUTH] Google sign-out successful');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SOCIAL_AUTH] Google sign-out failed: $e');
      }
    }
  }

  /// Mevcut Google kullanıcısını kontrol et
  static Future<GoogleSignInAccount?> getCurrentGoogleUser() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SOCIAL_AUTH] Silent sign-in failed: $e');
      }
      return null;
    }
  }

  /// Facebook ile giriş yap
  static Future<Map<String, dynamic>?> signInWithFacebook() async {
    if (kDebugMode) {
      print('📘 [SOCIAL_AUTH] Facebook sign-in not yet implemented');
    }
    
    // TODO: Facebook SDK integration
    // Bu özellik için facebook_login paketi veya flutter_facebook_auth gerekli
    throw Exception('Facebook Sign-In henüz implement edilmedi');
  }

  /// Sosyal hesap bağlama
  static Future<Map<String, dynamic>> linkSocialAccount({
    required String provider,
    required String accessToken,
  }) async {
    if (kDebugMode) {
      print('🔗 [SOCIAL_AUTH] Linking $provider account...');
    }

    try {
      final result = await _apiService.linkSocialAccount(
        provider: provider,
        accessToken: accessToken,
      );

      if (kDebugMode) {
        print('✅ [SOCIAL_AUTH] Account linked successfully');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SOCIAL_AUTH] Account linking failed: $e');
      }
      rethrow;
    }
  }

  /// Bağlı sosyal hesapları getir
  static Future<List<Map<String, dynamic>>> getLinkedAccounts() async {
    try {
      return await _apiService.getLinkedAccounts();
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SOCIAL_AUTH] Failed to get linked accounts: $e');
      }
      rethrow;
    }
  }

  /// Sosyal hesap bağlantısını kes
  static Future<void> unlinkSocialAccount(String provider) async {
    try {
      await _apiService.unlinkSocialAccount(provider);
      
      if (kDebugMode) {
        print('✅ [SOCIAL_AUTH] Account unlinked: $provider');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SOCIAL_AUTH] Failed to unlink account: $e');
      }
      rethrow;
    }
  }
}