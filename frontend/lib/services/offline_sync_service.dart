import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/offline_sync_item.dart';

class OfflineSyncService {
  static const String _keyDashboardPrefix = 'offline_dashboard_cache_';
  static const String _keyQueuePrefix = 'offline_sync_queue_';
  static const String _keyChatQueuePrefix = 'offline_chat_queue_';

  // In-memory fallback in case SharedPreferences hasn't loaded or in unit tests
  static final Map<String, String> _memoryStore = {};

  static String generateIdempotencyKey() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(900000) + 100000;
    return 'idemp_${timestamp}_$rand';
  }

  // ======================== DASHBOARD SNAPSHOT CACHE ========================

  static Future<void> cacheDashboard(String userId, Map<String, dynamic> data) async {
    final key = '$_keyDashboardPrefix$userId';
    final serialized = jsonEncode(data);
    _memoryStore[key] = serialized;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, serialized);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> getCachedDashboard(String userId) async {
    final key = '$_keyDashboardPrefix$userId';
    String? raw = _memoryStore[key];

    if (raw == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        raw = prefs.getString(key);
      } catch (_) {}
    }

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {}
    }
    return null;
  }

  // ======================== PENDING SYNC QUEUE ========================

  static Future<List<OfflineSyncItem>> getQueue(String userId) async {
    final key = '$_keyQueuePrefix$userId';
    String? raw = _memoryStore[key];

    if (raw == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        raw = prefs.getString(key);
      } catch (_) {}
    }

    if (raw != null && raw.isNotEmpty) {
      return OfflineSyncItem.decodeList(raw);
    }
    return [];
  }

  static Future<void> enqueue(String userId, OfflineSyncItem item) async {
    final items = await getQueue(userId);
    // Deduplicate in queue if already present
    items.removeWhere((i) => i.idempotencyKey == item.idempotencyKey);
    items.add(item);

    final key = '$_keyQueuePrefix$userId';
    final serialized = OfflineSyncItem.encodeList(items);
    _memoryStore[key] = serialized;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, serialized);
    } catch (_) {}
  }

  static Future<void> remove(String userId, String itemId) async {
    final items = await getQueue(userId);
    items.removeWhere((i) => i.id == itemId || i.idempotencyKey == itemId);

    final key = '$_keyQueuePrefix$userId';
    final serialized = OfflineSyncItem.encodeList(items);
    _memoryStore[key] = serialized;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, serialized);
    } catch (_) {}
  }

  static Future<void> clearQueue(String userId) async {
    final key = '$_keyQueuePrefix$userId';
    _memoryStore.remove(key);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  // ======================== CHAT OFFLINE QUEUE ========================

  static Future<List<Map<String, dynamic>>> getChatQueue(String userId) async {
    final key = '$_keyChatQueuePrefix$userId';
    String? raw = _memoryStore[key];
    if (raw == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        raw = prefs.getString(key);
      } catch (_) {}
    }

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  static Future<void> enqueueChatMessage(String userId, Map<String, dynamic> message) async {
    final list = await getChatQueue(userId);
    list.removeWhere((i) => i['temp_id'] == message['temp_id']);
    list.add(message);

    final key = '$_keyChatQueuePrefix$userId';
    final serialized = jsonEncode(list);
    _memoryStore[key] = serialized;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, serialized);
    } catch (_) {}
  }

  static Future<void> removeChatMessage(String userId, int tempId) async {
    final list = await getChatQueue(userId);
    list.removeWhere((i) => i['temp_id'] == tempId);

    final key = '$_keyChatQueuePrefix$userId';
    final serialized = jsonEncode(list);
    _memoryStore[key] = serialized;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, serialized);
    } catch (_) {}
  }
}
