import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class OfflineService {
  static const String _teachersKey = 'cached_teachers';
  static const String _categoriesKey = 'cached_categories';
  static const String _userKey = 'cached_user';
  static const String _reservationsKey = 'cached_reservations';
  
  static SharedPreferences? _prefs;
  
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  // Teachers cache
  static Future<void> cacheTeachers(List<Map<String, dynamic>> teachers) async {
    if (_prefs == null) await init();
    final jsonString = jsonEncode(teachers);
    await _prefs!.setString(_teachersKey, jsonString);
    await _prefs!.setInt('${_teachersKey}_timestamp', DateTime.now().millisecondsSinceEpoch);
  }
  
  static Future<List<Map<String, dynamic>>?> getCachedTeachers() async {
    if (_prefs == null) await init();
    final jsonString = _prefs!.getString(_teachersKey);
    if (jsonString == null) return null;
    
    final timestamp = _prefs!.getInt('${_teachersKey}_timestamp') ?? 0;
    final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
    
    // Cache expires after 1 hour
    if (cacheAge > 3600000) {
      await clearTeachersCache();
      return null;
    }
    
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      return null;
    }
  }
  
  static Future<void> clearTeachersCache() async {
    if (_prefs == null) await init();
    await _prefs!.remove(_teachersKey);
    await _prefs!.remove('${_teachersKey}_timestamp');
  }
  
  // Categories cache
  static Future<void> cacheCategories(List<Map<String, dynamic>> categories) async {
    if (_prefs == null) await init();
    final jsonString = jsonEncode(categories);
    await _prefs!.setString(_categoriesKey, jsonString);
    await _prefs!.setInt('${_categoriesKey}_timestamp', DateTime.now().millisecondsSinceEpoch);
  }
  
  static Future<List<Map<String, dynamic>>?> getCachedCategories() async {
    if (_prefs == null) await init();
    final jsonString = _prefs!.getString(_categoriesKey);
    if (jsonString == null) return null;
    
    final timestamp = _prefs!.getInt('${_categoriesKey}_timestamp') ?? 0;
    final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
    
    // Categories cache expires after 24 hours
    if (cacheAge > 86400000) {
      await clearCategoriesCache();
      return null;
    }
    
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      return null;
    }
  }
  
  static Future<void> clearCategoriesCache() async {
    if (_prefs == null) await init();
    await _prefs!.remove(_categoriesKey);
    await _prefs!.remove('${_categoriesKey}_timestamp');
  }
  
  // User cache
  static Future<void> cacheUser(Map<String, dynamic> user) async {
    if (_prefs == null) await init();
    final jsonString = jsonEncode(user);
    await _prefs!.setString(_userKey, jsonString);
  }
  
  static Future<Map<String, dynamic>?> getCachedUser() async {
    if (_prefs == null) await init();
    final jsonString = _prefs!.getString(_userKey);
    if (jsonString == null) return null;
    
    try {
      return jsonDecode(jsonString);
    } catch (e) {
      return null;
    }
  }
  
  static Future<void> clearUserCache() async {
    if (_prefs == null) await init();
    await _prefs!.remove(_userKey);
  }
  
  // Reservations cache
  static Future<void> cacheReservations(List<Map<String, dynamic>> reservations) async {
    if (_prefs == null) await init();
    final jsonString = jsonEncode(reservations);
    await _prefs!.setString(_reservationsKey, jsonString);
    await _prefs!.setInt('${_reservationsKey}_timestamp', DateTime.now().millisecondsSinceEpoch);
  }
  
  static Future<List<Map<String, dynamic>>?> getCachedReservations() async {
    if (_prefs == null) await init();
    final jsonString = _prefs!.getString(_reservationsKey);
    if (jsonString == null) return null;
    
    final timestamp = _prefs!.getInt('${_reservationsKey}_timestamp') ?? 0;
    final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
    
    // Reservations cache expires after 30 minutes
    if (cacheAge > 1800000) {
      await clearReservationsCache();
      return null;
    }
    
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      return null;
    }
  }
  
  static Future<void> clearReservationsCache() async {
    if (_prefs == null) await init();
    await _prefs!.remove(_reservationsKey);
    await _prefs!.remove('${_reservationsKey}_timestamp');
  }
  
  // Queue for offline actions
  static Future<void> queueOfflineAction(String action, Map<String, dynamic> data) async {
    if (_prefs == null) await init();
    final queueKey = 'offline_queue';
    final existingQueue = _prefs!.getString(queueKey);
    
    List<Map<String, dynamic>> queue = [];
    if (existingQueue != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(existingQueue);
        queue = jsonList.cast<Map<String, dynamic>>();
      } catch (e) {
        queue = [];
      }
    }
    
    queue.add({
      'action': action,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    await _prefs!.setString(queueKey, jsonEncode(queue));
  }
  
  static Future<List<Map<String, dynamic>>> getOfflineQueue() async {
    if (_prefs == null) await init();
    final queueKey = 'offline_queue';
    final existingQueue = _prefs!.getString(queueKey);
    
    if (existingQueue == null) return [];
    
    try {
      final List<dynamic> jsonList = jsonDecode(existingQueue);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }
  
  static Future<void> clearOfflineQueue() async {
    if (_prefs == null) await init();
    await _prefs!.remove('offline_queue');
  }
  
  static Future<void> removeOfflineAction(int index) async {
    if (_prefs == null) await init();
    final queue = await getOfflineQueue();
    if (index >= 0 && index < queue.length) {
      queue.removeAt(index);
      await _prefs!.setString('offline_queue', jsonEncode(queue));
    }
  }
  
  // Clear all cache
  static Future<void> clearAllCache() async {
    if (_prefs == null) await init();
    await clearTeachersCache();
    await clearCategoriesCache();
    await clearUserCache();
    await clearReservationsCache();
    await clearOfflineQueue();
  }

  // Clear cache for category update
  static Future<void> clearCacheForCategoryUpdate() async {
    if (_prefs == null) await init();
    await clearCategoriesCache();
    await clearTeachersCache(); // Teachers might have category references
    await clearReservationsCache(); // Reservations have category references
  }
  
  // Get cache size
  static Future<int> getCacheSize() async {
    if (_prefs == null) await init();
    int totalSize = 0;
    
    final keys = [
      _teachersKey,
      _categoriesKey,
      _userKey,
      _reservationsKey,
      'offline_queue',
    ];
    
    for (final key in keys) {
      final value = _prefs!.getString(key);
      if (value != null) {
        totalSize += value.length;
      }
    }
    
    return totalSize;
  }
}
