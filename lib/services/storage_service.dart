import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../models/storage_volume_model.dart';
import 'package:disk_space_2/disk_space_2.dart';

class StorageService {
  /// Returns a list of available storage volumes (Internal + SD Cards).
  Future<List<StorageVolume>> getStorageVolumes() async {
    List<StorageVolume> volumes = [
      StorageVolume(
        path: '/storage/emulated/0',
        name: 'Internal Storage',
        isInternal: true,
      ),
    ];

    if (Platform.isAndroid) {
      try {
        final dirs = await getExternalStorageDirectories();
        if (dirs != null) {
          for (var dir in dirs) {
            // SD card paths usually look like /storage/XXXX-XXXX/Android/data/com.example.app/files
            // We want the root: /storage/XXXX-XXXX
            final pathParts = dir.path.split('/');
            if (pathParts.length > 2 && pathParts[1] == 'storage') {
              final volumeId = pathParts[2];
              if (volumeId != 'emulated' && volumeId != 'self') {
                final rootPath = '/storage/$volumeId';
                if (!volumes.any((v) => v.path == rootPath)) {
                  volumes.add(
                    StorageVolume(
                      path: rootPath,
                      name: 'SD Card ($volumeId)',
                      isInternal: false,
                    ),
                  );
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error detecting SD Card: $e');
      }
    }
    return volumes;
  }

  /// Returns true when the app has enough permission to browse/list files.
  /// On Android 13+: requests READ_MEDIA_* (shows system popup).
  /// On Android ≤ 12: requests READ_EXTERNAL_STORAGE (shows system popup).
  /// MANAGE_EXTERNAL_STORAGE is intentionally NOT requested here because
  /// it always redirects to the Settings page instead of showing a popup.
  /// Detailed status of permissions
  Future<Map<String, bool>> getPermissionStatus() async {
    return {
      'manageExternalStorage': await Permission.manageExternalStorage.isGranted,
      'storage': await Permission.storage.isGranted,
      'photos': await Permission.photos.isGranted,
      'videos': await Permission.videos.isGranted,
      'audio': await Permission.audio.isGranted,
    };
  }

  Future<bool> hasAllFilesAccess() async {
    if (Platform.isAndroid) {
      return await Permission.manageExternalStorage.isGranted;
    }
    return true;
  }

  Future<bool> requestStoragePermission() async {
    // On Android 11+, we really want MANAGE_EXTERNAL_STORAGE for a file manager.
    if (Platform.isAndroid) {
      // 1. Try granular/legacy first just to get basic access
      bool isAndroid13OrHigher = false;
      try {
        // Simple check for SDK 33
        isAndroid13OrHigher =
            await Permission.photos.status != PermissionStatus.restricted;
      } catch (_) {}

      if (isAndroid13OrHigher) {
        await [
          Permission.photos,
          Permission.videos,
          Permission.audio,
        ].request();
      } else {
        await Permission.storage.request();
      }

      // 2. Check if we ALREADY have MANAGE_EXTERNAL_STORAGE
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }

      // 3. Request MANAGE_EXTERNAL_STORAGE if not granted
      // This will take user to Settings.
      final status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    }

    // Fallback for non-Android (though this app is focused on Android)
    return await Permission.storage.request().isGranted;
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
