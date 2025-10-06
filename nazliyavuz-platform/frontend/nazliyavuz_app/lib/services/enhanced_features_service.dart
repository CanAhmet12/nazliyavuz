import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ThemeService {
  static const String _themeKey = 'theme_mode';
  static const String _languageKey = 'language_code';
  
  static ThemeMode _themeMode = ThemeMode.system;
  static String _languageCode = 'tr';
  
  static ThemeMode get themeMode => _themeMode;
  static String get languageCode => _languageCode;
  
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? 0;
    final language = prefs.getString(_languageKey) ?? 'tr';
    
    _themeMode = ThemeMode.values[themeIndex];
    _languageCode = language;
  }
  
  static Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }
  
  static Future<void> setLanguage(String languageCode) async {
    _languageCode = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }
}

class LanguageService {
  static const Map<String, Map<String, String>> _translations = {
    'tr': {
      'app_title': 'Rota Akademi',
      'welcome': 'Hoş Geldiniz',
      'login': 'Giriş Yap',
      'register': 'Kayıt Ol',
      'teachers': 'Öğretmenler',
      'reservations': 'Rezervasyonlar',
      'profile': 'Profil',
      'settings': 'Ayarlar',
      'search': 'Ara',
      'filter': 'Filtrele',
      'rating': 'Değerlendirme',
      'review': 'Yorum',
      'book_now': 'Şimdi Rezerve Et',
      'online': 'Online',
      'offline': 'Yüz Yüze',
      'price_per_hour': 'Saatlik Ücret',
      'experience': 'Deneyim',
      'education': 'Eğitim',
      'certifications': 'Sertifikalar',
      'languages': 'Diller',
      'availability': 'Müsaitlik',
      'schedule': 'Program',
      'notifications': 'Bildirimler',
      'dark_mode': 'Karanlık Mod',
      'language': 'Dil',
      'logout': 'Çıkış Yap',
      'save': 'Kaydet',
      'cancel': 'İptal',
      'confirm': 'Onayla',
      'delete': 'Sil',
      'edit': 'Düzenle',
      'add': 'Ekle',
      'remove': 'Kaldır',
      'loading': 'Yükleniyor...',
      'error': 'Hata',
      'success': 'Başarılı',
      'no_data': 'Veri bulunamadı',
      'try_again': 'Tekrar Dene',
      'refresh': 'Yenile',
      'back': 'Geri',
      'next': 'İleri',
      'previous': 'Önceki',
      'done': 'Tamam',
      'skip': 'Atla',
      'continue': 'Devam Et',
    },
    'en': {
      'app_title': 'Rota Akademi',
      'welcome': 'Welcome',
      'login': 'Login',
      'register': 'Register',
      'teachers': 'Teachers',
      'reservations': 'Reservations',
      'profile': 'Profile',
      'settings': 'Settings',
      'search': 'Search',
      'filter': 'Filter',
      'rating': 'Rating',
      'review': 'Review',
      'book_now': 'Book Now',
      'online': 'Online',
      'offline': 'In-Person',
      'price_per_hour': 'Price per Hour',
      'experience': 'Experience',
      'education': 'Education',
      'certifications': 'Certifications',
      'languages': 'Languages',
      'availability': 'Availability',
      'schedule': 'Schedule',
      'notifications': 'Notifications',
      'dark_mode': 'Dark Mode',
      'language': 'Language',
      'logout': 'Logout',
      'save': 'Save',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'delete': 'Delete',
      'edit': 'Edit',
      'add': 'Add',
      'remove': 'Remove',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'no_data': 'No data found',
      'try_again': 'Try Again',
      'refresh': 'Refresh',
      'back': 'Back',
      'next': 'Next',
      'previous': 'Previous',
      'done': 'Done',
      'skip': 'Skip',
      'continue': 'Continue',
    },
    'de': {
      'app_title': 'Rota Akademi',
      'welcome': 'Willkommen',
      'login': 'Anmelden',
      'register': 'Registrieren',
      'teachers': 'Lehrer',
      'reservations': 'Reservierungen',
      'profile': 'Profil',
      'settings': 'Einstellungen',
      'search': 'Suchen',
      'filter': 'Filter',
      'rating': 'Bewertung',
      'review': 'Rezension',
      'book_now': 'Jetzt Buchen',
      'online': 'Online',
      'offline': 'Persönlich',
      'price_per_hour': 'Preis pro Stunde',
      'experience': 'Erfahrung',
      'education': 'Bildung',
      'certifications': 'Zertifikate',
      'languages': 'Sprachen',
      'availability': 'Verfügbarkeit',
      'schedule': 'Zeitplan',
      'notifications': 'Benachrichtigungen',
      'dark_mode': 'Dunkler Modus',
      'language': 'Sprache',
      'logout': 'Abmelden',
      'save': 'Speichern',
      'cancel': 'Abbrechen',
      'confirm': 'Bestätigen',
      'delete': 'Löschen',
      'edit': 'Bearbeiten',
      'add': 'Hinzufügen',
      'remove': 'Entfernen',
      'loading': 'Laden...',
      'error': 'Fehler',
      'success': 'Erfolg',
      'no_data': 'Keine Daten gefunden',
      'try_again': 'Erneut versuchen',
      'refresh': 'Aktualisieren',
      'back': 'Zurück',
      'next': 'Weiter',
      'previous': 'Vorherige',
      'done': 'Fertig',
      'skip': 'Überspringen',
      'continue': 'Fortfahren',
    },
  };
  
  static String translate(String key) {
    final translations = _translations[ThemeService.languageCode] ?? _translations['tr']!;
    return translations[key] ?? key;
  }
  
  static List<String> get supportedLanguages => _translations.keys.toList();
  
  static String getLanguageName(String code) {
    switch (code) {
      case 'tr': return 'Türkçe';
      case 'en': return 'English';
      case 'de': return 'Deutsch';
      default: return 'Türkçe';
    }
  }
}

class AccessibilityService {
  static bool _isAccessibilityEnabled = false;
  static double _fontScale = 1.0;
  static bool _highContrast = false;
  static bool _reduceMotion = false;
  
  static bool get isAccessibilityEnabled => _isAccessibilityEnabled;
  static double get fontScale => _fontScale;
  static bool get highContrast => _highContrast;
  static bool get reduceMotion => _reduceMotion;
  
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isAccessibilityEnabled = prefs.getBool('accessibility_enabled') ?? false;
    _fontScale = prefs.getDouble('font_scale') ?? 1.0;
    _highContrast = prefs.getBool('high_contrast') ?? false;
    _reduceMotion = prefs.getBool('reduce_motion') ?? false;
  }
  
  static Future<void> setAccessibilityEnabled(bool enabled) async {
    _isAccessibilityEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('accessibility_enabled', enabled);
  }
  
  static Future<void> setFontScale(double scale) async {
    _fontScale = scale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_scale', scale);
  }
  
  static Future<void> setHighContrast(bool enabled) async {
    _highContrast = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('high_contrast', enabled);
  }
  
  static Future<void> setReduceMotion(bool enabled) async {
    _reduceMotion = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reduce_motion', enabled);
  }
}

class OfflineSyncService {
  static bool _isOnline = true;
  static List<Map<String, dynamic>> _pendingActions = [];
  
  static bool get isOnline => _isOnline;
  static List<Map<String, dynamic>> get pendingActions => _pendingActions;
  
  static Future<void> init() async {
    await _loadPendingActions();
  }
  
  static void setOnlineStatus(bool online) {
    _isOnline = online;
    if (online) {
      _syncPendingActions();
    }
  }
  
  static Future<void> addPendingAction(String action, Map<String, dynamic> data) async {
    _pendingActions.add({
      'action': action,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await _savePendingActions();
  }
  
  static Future<void> _loadPendingActions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('pending_actions');
    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _pendingActions = jsonList.cast<Map<String, dynamic>>();
      } catch (e) {
        _pendingActions = [];
      }
    }
  }
  
  static Future<void> _savePendingActions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_actions', jsonEncode(_pendingActions));
  }
  
  static Future<void> _syncPendingActions() async {
    // Implement sync logic here
    // This would typically make API calls for each pending action
    _pendingActions.clear();
    await _savePendingActions();
  }
  
  static Future<void> clearPendingActions() async {
    _pendingActions.clear();
    await _savePendingActions();
  }
}
