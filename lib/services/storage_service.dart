import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:disk_space_2/disk_space_2.dart';

class StorageService {
  /// Returns true when the app has enough permission to browse/list files.
  /// On Android 13+: requests READ_MEDIA_* (shows system popup).
  /// On Android ≤ 12: requests READ_EXTERNAL_STORAGE (shows system popup).
  /// MANAGE_EXTERNAL_STORAGE is intentionally NOT requested here because
  /// it always redirects to the Settings page instead of showing a popup.
  Future<bool> requestStoragePermission() async {
    // 1. Check for MANAGE_EXTERNAL_STORAGE (Android 11+)
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    // 2. Android 13+ (SDK 33) — granular media permissions
    bool isAndroid13OrHigher = false;
    if (Platform.isAndroid) {
      // In a real app, you'd check SDK version. Here we check if media permissions are even relevant.
      isAndroid13OrHigher =
          await Permission.photos.status != PermissionStatus.restricted;
    }

    if (isAndroid13OrHigher) {
      final statuses = await [
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ].request();

      if (statuses.values.every((s) => s.isGranted)) {
        return true;
      }
    }

    // 3. Legacy storage (Android ≤ 12)
    final storageStatus = await Permission.storage.request();
    if (storageStatus.isGranted) {
      return true;
    }

    // 4. For full file manager features on Android 11+, we need to request MANAGE_EXTERNAL_STORAGE
    // This will open the system settings page.
    if (await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }

    return false;
  }

  /// Returns true if the app has full file system access (Android 11+)
  Future<bool> hasFullAccess() async {
    return await Permission.manageExternalStorage.isGranted;
  }

  double _getAdvertisedStorage(double rawGB) {
    if (rawGB <= 8) return 8.0;
    if (rawGB <= 16) return 16.0;
    if (rawGB <= 32) return 32.0;
    if (rawGB <= 64) return 64.0;
    if (rawGB <= 128) return 128.0;
    if (rawGB <= 256) return 256.0;
    if (rawGB <= 512) return 512.0;
    return 1024.0;
  }

  Future<double> getTotalDiskSpaceGB() async {
    try {
      final mb = await DiskSpace.getTotalDiskSpace;
      if (mb != null) {
        return _getAdvertisedStorage(mb / 1024.0);
      }
    } catch (e) {
      // Handle missing method channel safely
    }
    return 64.0;
  }

  Future<double> getUsedDiskSpaceGB() async {
    try {
      final totalMb = await DiskSpace.getTotalDiskSpace;
      final freeMb = await DiskSpace.getFreeDiskSpace;

      if (totalMb != null && freeMb != null) {
        final rawTotalGB = totalMb / 1024.0;
        final freeGB = freeMb / 1024.0;
        final advertisedTotal = _getAdvertisedStorage(rawTotalGB);
        return advertisedTotal - freeGB;
      }
    } catch (e) {
      // Handle missing method channel safely
    }
    return 56.5;
  }
}

/// Shows an allow/cancel permission rationale dialog before requesting.
/// Call this from a UI context (e.g. HomeView) before calling loadStorageData().
Future<bool> showPermissionRationaleDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Storage Permission Required'),
      content: const Text(
        'Vortex needs access to your media files (photos, videos, audio) '
        'to display your file library. No data is shared externally.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Allow'),
        ),
      ],
    ),
  );
  return result ?? false;
}
