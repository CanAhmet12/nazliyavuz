import 'package:google_sign_in/google_sign_in.dart';
// import 'package:sign_in_with_apple/sign_in_with_apple.dart'; // Temporarily disabled
import 'package:flutter/foundation.dart';
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

  /// Apple ile giriş yap (temporarily disabled)
  static Future<Map<String, dynamic>?> signInWithApple() async {
    if (kDebugMode) {
      print('❌ [SOCIAL_AUTH] Apple sign-in temporarily disabled');
    }
    throw Exception('Apple Sign-In geçici olarak devre dışı');
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
}