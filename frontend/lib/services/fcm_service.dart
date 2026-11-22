import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If native background isolate needs Firebase
  try {
    if (!kIsWeb) {
      await Firebase.initializeApp();
    }
  } catch (_) {}

  // If payload does not contain notification body, display local notification
  if (message.notification == null && message.data.isNotEmpty) {
    final title = message.data['sender_name'] ?? message.data['title'] ?? 'Pesan Baru';
    final body = message.data['message'] ?? message.data['body'] ?? 'Anda menerima pesan baru.';
    await NotificationService.showNotification(
      id: message.hashCode,
      title: title.toString(),
      body: body.toString(),
    );
  }
}

class FcmService {
  static String? _cachedToken;
  static bool _isInitialized = false;

  static String? get currentToken => _cachedToken;

  static Future<void> init(ApiClient apiClient) async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      await Firebase.initializeApp();
      _isInitialized = true;
    } catch (e) {
      debugPrint('[FCM] Firebase.initializeApp skipped or credentials not configured: $e');
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      // 1. Request push notification permissions (sound, badge, alert)
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('[FCM] User granted permission: ${settings.authorizationStatus}');

      // 2. Set foreground presentation options
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Get device FCM token
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _cachedToken = token;
        debugPrint('[FCM] Device Token: $token');
        await _syncTokenToBackend(apiClient, token);
      }

      // 4. Listen to token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        _cachedToken = newToken;
        await _syncTokenToBackend(apiClient, newToken);
      });

      // 5. Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM] Foreground message received: ${message.data}');
        final notif = message.notification;
        if (notif != null) {
          NotificationService.showNotification(
            id: message.hashCode,
            title: notif.title ?? 'Pesan Baru',
            body: notif.body ?? '',
          );
        } else if (message.data.isNotEmpty) {
          final title = message.data['sender_name'] ?? message.data['title'] ?? 'Pesan Baru';
          final body = message.data['message'] ?? message.data['body'] ?? 'Anda menerima pesan baru.';
          NotificationService.showNotification(
            id: message.hashCode,
            title: title.toString(),
            body: body.toString(),
          );
        }
      });

      // 6. Handle notification click from background / lock screen
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM] User tapped notification from background: ${message.data}');
        // Room ID or routing payload can be handled here
      });

      // 7. Check if app was opened from a terminated state notification
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM] App opened from terminated state via notification: ${initialMessage.data}');
      }
    } catch (e) {
      debugPrint('[FCM] Error setting up Firebase Messaging: $e');
    }
  }

  static Future<void> syncToken(ApiClient apiClient) async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      final token = _cachedToken ?? await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        _cachedToken = token;
        await _syncTokenToBackend(apiClient, token);
      }
    } catch (_) {}
  }

  static Future<void> _syncTokenToBackend(ApiClient apiClient, String token) async {
    try {
      final res = await apiClient.post(
        ApiConstants.userDeviceToken,
        body: {
          'fcm_token': token,
          'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
        },
      );
      if (res is Map && res['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_synced_fcm_token', token);
        debugPrint('[FCM] Token successfully registered to backend API');
      }
    } catch (e) {
      debugPrint('[FCM] Failed to sync token to backend (will retry): $e');
    }
  }

  static Future<void> unregisterToken(ApiClient apiClient) async {
    if (_cachedToken == null || !_isInitialized) return;
    try {
      await apiClient.delete(
        ApiConstants.userDeviceToken,
        body: {'fcm_token': _cachedToken},
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_synced_fcm_token');
      debugPrint('[FCM] Token successfully unregistered from backend');
    } catch (_) {}
  }
}
