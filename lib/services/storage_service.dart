import 'package:permission_handler/permission_handler.dart';
import 'package:disk_space_2/disk_space_2.dart';

class StorageService {
  Future<bool> requestStoragePermission() async {
    // Check if we already have modern MANAGE_EXTERNAL_STORAGE (Android 11+)
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    // Check legacy storage
    if (await Permission.storage.isGranted) {
      return true;
    }

    // Request permissions based on availability
    var manageStatus = await Permission.manageExternalStorage.request();
    if (manageStatus.isGranted) {
      return true;
    }

    var storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
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
    return 64.0; // Fallback placeholder
  }

  Future<double> getUsedDiskSpaceGB() async {
    try {
      final totalMb = await DiskSpace.getTotalDiskSpace;
      final freeMb = await DiskSpace.getFreeDiskSpace;

      if (totalMb != null && freeMb != null) {
        final rawTotalGB = totalMb / 1024.0;
        final freeGB = freeMb / 1024.0;
        final advertisedTotal = _getAdvertisedStorage(rawTotalGB);
        // By subtracting free disk space from the advertised total,
        // we correctly include OS-reserved system space in the "Used" metric.
        return advertisedTotal - freeGB;
      }
    } catch (e) {
      // Handle missing method channel safely
    }
    return 56.5; // Fallback placeholder
  }
}
