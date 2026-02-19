// lib/services/cache_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const String _prefix = 'album_cache_';
  static const String _tsPrefix = 'album_ts_';

  /// Simpan list {id, path} untuk album tertentu
  Future<void> saveAlbumData(
    String albumId,
    List<Map<String, String>> items,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const chunkSize = 300;
      int chunkIndex = 0;

      await clearAlbumCache(albumId);

      for (int i = 0; i < items.length; i += chunkSize) {
        final end = (i + chunkSize).clamp(0, items.length);
        final chunk = items.sublist(i, end);
        await prefs.setString(
          '${_prefix}${albumId}_$chunkIndex',
          jsonEncode(chunk),
        );
        chunkIndex++;
      }

      await prefs.setInt('${_prefix}${albumId}_chunks', chunkIndex);
      await prefs.setInt(
        '$_tsPrefix$albumId',
        DateTime.now().millisecondsSinceEpoch,
      );

      print('Cached ${items.length} items for album $albumId');
    } catch (e) {
      print('Error saving album cache: $e');
    }
  }

  /// Ambil cached {id, path} list
  Future<List<Map<String, String>>?> getAlbumData(String albumId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chunkCount = prefs.getInt('${_prefix}${albumId}_chunks');
      if (chunkCount == null) return null;

      List<Map<String, String>> allItems = [];

      for (int i = 0; i < chunkCount; i++) {
        final raw = prefs.getString('${_prefix}${albumId}_$i');
        if (raw == null) return null;
        final chunk = (jsonDecode(raw) as List)
            .map((e) => Map<String, String>.from(e as Map))
            .toList();
        allItems.addAll(chunk);
      }

      print('Loaded ${allItems.length} cached items for album $albumId');
      return allItems;
    } catch (e) {
      print('Error reading album cache: $e');
      return null;
    }
  }

  /// Cache valid selama maxAgeMinutes (default 24 jam)
  Future<bool> isCacheValid(String albumId, {int maxAgeMinutes = 1440}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('$_tsPrefix$albumId');
      if (timestamp == null) return false;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      return age < (maxAgeMinutes * 60 * 1000);
    } catch (e) {
      return false;
    }
  }

  Future<void> clearAlbumCache(String albumId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chunkCount = prefs.getInt('${_prefix}${albumId}_chunks') ?? 0;
      for (int i = 0; i < chunkCount; i++) {
        await prefs.remove('${_prefix}${albumId}_$i');
      }
      await prefs.remove('${_prefix}${albumId}_chunks');
      await prefs.remove('$_tsPrefix$albumId');
    } catch (e) {
      print('Error clearing album cache: $e');
    }
  }

  Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().toList();
      for (final key in keys) {
        if (key.startsWith(_prefix) || key.startsWith(_tsPrefix)) {
          await prefs.remove(key);
        }
      }
      print('All cache cleared');
    } catch (e) {
      print('Error clearing all cache: $e');
    }
  }
}