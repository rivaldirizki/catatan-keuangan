import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return true;
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    final res = await Permission.notification.request();
    return res.isGranted;
  }

  static Future<bool> requestCameraPermission() async {
    if (kIsWeb) return true;
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    final res = await Permission.camera.request();
    return res.isGranted;
  }

  static Future<bool> requestStoragePermission() async {
    if (kIsWeb) return true;
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    // For Android 13+ (API 33+), check photos and videos
    if (Platform.isAndroid) {
      final photosStatus = await Permission.photos.request();
      final videosStatus = await Permission.videos.request();
      if (photosStatus.isGranted || videosStatus.isGranted) {
        return true;
      }
    }

    // Fallback for older Android versions
    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  static Future<bool> requestBackgroundPermission() async {
    if (kIsWeb) return true;
    if (!Platform.isAndroid) return true;
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (status.isGranted) return true;
      final res = await Permission.ignoreBatteryOptimizations.request();
      return res.isGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isBackgroundPermissionGranted() async {
    if (kIsWeb) return true;
    if (!Platform.isAndroid) return true;
    try {
      return await Permission.ignoreBatteryOptimizations.isGranted;
    } catch (_) {
      return true;
    }
  }
}
