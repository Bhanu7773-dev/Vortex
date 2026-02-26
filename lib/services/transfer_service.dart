import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:vortex/services/connection_manager.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _fmtSpeed(double bps) {
  if (bps >= 1024 * 1024)
    return '${(bps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  if (bps >= 1024) return '${(bps / 1024).toStringAsFixed(1)} KB/s';
  return '${bps.toStringAsFixed(0)} B/s';
}

String _fmtBytes(int bytes) {
  if (bytes >= 1024 * 1024)
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}

// ─── Speed sampler ───────────────────────────────────────────────────────────

/// Rolling speed measurement. Call [record] with cumulative byte count;
/// read [bytesPerSec] for the current sample.
class _SpeedSampler {
  static const _windowMs = 400;

  DateTime _lastTime = DateTime.now();
  int _lastBytes = 0;
  double bytesPerSec = 0;

  void record(int totalBytes) {
    final now = DateTime.now();
    final elapsed = now.difference(_lastTime).inMilliseconds;
    if (elapsed >= _windowMs) {
      bytesPerSec = (totalBytes - _lastBytes) * 1000 / elapsed;
      _lastTime = now;
      _lastBytes = totalBytes;
    }
  }
}

// ─── Internal file ────────────────────────────────────────────────────────────

/// One file being tracked in a transfer job.
class _TransferFile {
  final File file;
  final String relativePath; // e.g. "Music/Album/song.mp3"
  _TransferFile({required this.file, required this.relativePath});
}

// ─── Outgoing job ─────────────────────────────────────────────────────────────

/// State of a single outgoing transfer job (one job = one target device).
class TransferJob {
  final String id;
  final String deviceName;
  int totalFiles;
  int completedFiles;
  int totalBytes;
  int sentBytes;
  bool isComplete;
  bool cancelled;
  String? error;

  final _SpeedSampler _speed = _SpeedSampler();

  TransferJob({
    required this.id,
    required this.deviceName,
    required this.totalFiles,
    required this.totalBytes,
  }) : completedFiles = 0,
       sentBytes = 0,
       isComplete = false,
       cancelled = false;

  double get progress =>
      totalBytes == 0 ? 0.0 : (sentBytes / totalBytes).clamp(0.0, 1.0);
  String get speedText => _fmtSpeed(_speed.bytesPerSec);
  String get sentText => _fmtBytes(sentBytes);
  String get totalText => _fmtBytes(totalBytes);

  void addSentBytes(int bytes) {
    sentBytes += bytes;
    _speed.record(sentBytes);
  }

  String get statusText {
    if (error != null) return 'Error: $error';
    if (cancelled) return 'Cancelled';
    if (isComplete)
      return 'Done – $completedFiles file${completedFiles == 1 ? '' : 's'}';
    return '$completedFiles / $totalFiles  •  $sentText / $totalText';
  }
}

// ─── Incoming job ─────────────────────────────────────────────────────────────

class ReceiveJob {
  final String id;
  final String relativePath;

  /// -1 when sender did not include Content-Length.
  final int totalBytes;
  int receivedBytes;
  bool isComplete;
  bool hasError;
  bool cancelled;
  String? savedPath;
  final DateTime startedAt;

  final _SpeedSampler _speed = _SpeedSampler();

  ReceiveJob({
    required this.id,
    required this.relativePath,
    required this.totalBytes,
  }) : receivedBytes = 0,
       isComplete = false,
       hasError = false,
       cancelled = false,
       startedAt = DateTime.now();

  String get fileName => relativePath.split('/').last;

  /// Returns -1 when total size is unknown.
  double get progress =>
      totalBytes <= 0 ? -1.0 : (receivedBytes / totalBytes).clamp(0.0, 1.0);

  String get speedText => _fmtSpeed(_speed.bytesPerSec);
  String get receivedText => _fmtBytes(receivedBytes);
  String get totalText => totalBytes > 0 ? _fmtBytes(totalBytes) : '?';

  void addBytes(int bytes) {
    receivedBytes += bytes;
    _speed.record(receivedBytes);
  }
}

// ─── TransferService ─────────────────────────────────────────────────────────

class TransferService extends ChangeNotifier {
  static const int _notifyThresholdBytes = 65536; // notify UI every 64 KB

  bool _disposed = false;

  // ── Outgoing ────────────────────────────────────────────────────────────────
  final List<TransferJob> jobs = [];

  TransferJob? get activeJob =>
      jobs.where((j) => !j.isComplete && !j.cancelled).firstOrNull;
  bool get hasActiveJob => activeJob != null;

  // ── Incoming ────────────────────────────────────────────────────────────────
  final List<ReceiveJob> receiveJobs = [];

  bool get hasActiveReceive =>
      receiveJobs.any((j) => !j.isComplete && !j.hasError);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ── Safe notify ─────────────────────────────────────────────────────────────

  void _safeNotify() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.transientCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    } else {
      if (!_disposed) notifyListeners();
    }
  }

  // ------------------------------------------------------------------
  // Send
  // ------------------------------------------------------------------

  /// Entry point: send [selectedPaths] (files and/or folders) to one device.
  Future<void> sendToDevice({
    required List<String> selectedPaths,
    required String deviceName,
    required String deviceIp,
    required int devicePort,
  }) async {
    final files = await _expandPaths(selectedPaths);

    int totalBytes = 0;
    for (final tf in files) {
      try {
        totalBytes += await tf.file.length();
      } catch (_) {}
    }

    final job = TransferJob(
      id: '${deviceName}_${DateTime.now().millisecondsSinceEpoch}',
      deviceName: deviceName,
      totalFiles: files.length,
      totalBytes: totalBytes,
    );
    jobs.add(job);
    _safeNotify();

    for (int i = 0; i < files.length; i++) {
      final tf = files[i];
      if (job.cancelled) break;
      try {
        await _sendFileTcp(tf, deviceIp, job);
      } catch (e) {
        job.error = e.toString();
        debugPrint('[Transfer] Error sending ${tf.relativePath}: $e');
        break;
      }
    }

    job.isComplete = true;
    _safeNotify();
  }

  /// Send to multiple devices in parallel.
  Future<void> sendToDevices({
    required List<String> selectedPaths,
    required List<({String name, String ip, int port})> targets,
  }) async {
    await Future.wait(
      targets.map(
        (t) => sendToDevice(
          selectedPaths: selectedPaths,
          deviceName: t.name,
          deviceIp: t.ip,
          devicePort: t.port,
        ),
      ),
    );
  }

  /// High-speed raw TCP sender.  Opens a direct socket, writes a JSON
  /// header line, then streams the file in large chunks.
  static const int _tcpChunkSize = 256 * 1024; // 256 KB chunks for throughput

  Future<void> _sendFileTcp(
    _TransferFile tf,
    String ip,
    TransferJob job,
  ) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        ip,
        ConnectionManager.tcpTransferPort,
        timeout: const Duration(seconds: 15),
      );
      socket.setOption(SocketOption.tcpNoDelay, true);

      // Absorb async write errors (broken pipe, connection reset) so they
      // don't surface as unhandled exceptions.  The await-flush below will
      // still rethrow them synchronously where we can catch them.
      bool pipeError = false;
      socket.done.catchError((e) {
        pipeError = true;
        debugPrint('[TCP Send] Async write error (absorbed): $e');
      });

      final fileLength = await tf.file.length();

      // ── Send JSON header terminated by newline ─────────────────────────
      final header = jsonEncode({'path': tf.relativePath, 'size': fileLength});
      socket.add(utf8.encode('$header\n'));

      // ── Stream file bytes in large chunks ──────────────────────────────
      int pendingNotify = 0;
      final raf = await tf.file.open(mode: FileMode.read);
      try {
        while (true) {
          if (job.cancelled || pipeError) break;
          final chunk = await raf.read(_tcpChunkSize);
          if (chunk.isEmpty) break;
          socket.add(chunk);
          job.addSentBytes(chunk.length);
          pendingNotify += chunk.length;
          if (pendingNotify >= _notifyThresholdBytes) {
            pendingNotify = 0;
            _safeNotify();
          }
        }
      } finally {
        await raf.close();
      }

      if (pipeError) return; // receiver already gone, skip flush/ACK

      // Flush all data before waiting for ACK.
      await socket.flush();

      if (!job.cancelled) {
        // Wait for single-byte ACK (0x06) from receiver, with a timeout.
        try {
          await socket.first.timeout(const Duration(seconds: 30));
        } catch (_) {
          // Timeout or stream closed — treat as success for robustness.
        }
        job.completedFiles++;
        _safeNotify();
      }
    } catch (e) {
      debugPrint('[TCP Send] Error sending ${tf.relativePath}: $e');
      rethrow;
    } finally {
      // destroy() force-closes without trying to flush (avoids double errors).
      try {
        socket?.destroy();
      } catch (_) {}
    }
  }

  // ------------------------------------------------------------------
  // Receive-side callbacks (called by ConnectionManager via main_view wiring)
  // ------------------------------------------------------------------

  /// Called before the first byte arrives. [totalBytes] is -1 if unknown.
  ReceiveJob startReceive({
    required String id,
    required String relativePath,
    required int totalBytes,
  }) {
    final job = ReceiveJob(
      id: id,
      relativePath: relativePath,
      totalBytes: totalBytes,
    );
    receiveJobs.add(job);
    _safeNotify();
    return job;
  }

  /// Called with the *cumulative* byte count received so far.
  void updateReceive({required String id, required int receivedBytes}) {
    final job = receiveJobs.where((j) => j.id == id).firstOrNull;
    if (job == null) return;
    final delta = receivedBytes - job.receivedBytes;
    if (delta > 0) job.addBytes(delta);
    _safeNotify();
  }

  /// Called when the file is fully received (or errored).
  void completeReceive({
    required String id,
    required String savedPath,
    bool hasError = false,
  }) {
    final job = receiveJobs.where((j) => j.id == id).firstOrNull;
    if (job == null) return;
    job.isComplete = true;
    job.hasError = hasError;
    job.savedPath = savedPath;
    _safeNotify();
  }

  /// Called when the user manually cancels an incoming transfer.
  void cancelReceive({
    required String id,
    required ConnectionManager connectionManager,
  }) {
    final job = receiveJobs.where((j) => j.id == id).firstOrNull;
    if (job == null || job.isComplete || job.cancelled) return;

    job.cancelled = true;
    job.hasError =
        true; // treat cancellation as an error state for UI bar color
    _safeNotify();

    // Tell the connection manager to close the socket
    connectionManager.cancelReceiveJob(id);
  }

  // ------------------------------------------------------------------
  // Receive-side: save directory helper (used by ConnectionManager)
  // ------------------------------------------------------------------

  /// Returns (and creates) the folder where received files are saved.
  static Future<Directory> getReceiveDir() async {
    final Directory base;
    if (Platform.isAndroid) {
      base = Directory('/storage/emulated/0/Downloads');
    } else {
      final downloads = await getDownloadsDirectory();
      base = downloads ?? await getApplicationDocumentsDirectory();
    }
    final dir = Directory('${base.path}/Vortex');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  /// Flatten files + folders into individual files with relative paths.
  Future<List<_TransferFile>> _expandPaths(List<String> paths) async {
    final result = <_TransferFile>[];
    for (final path in paths) {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.file) {
        result.add(
          _TransferFile(file: File(path), relativePath: path.split('/').last),
        );
      } else if (type == FileSystemEntityType.directory) {
        final folderName = path.split('/').last;
        await _expandDir(Directory(path), folderName, result);
      }
    }
    return result;
  }

  Future<void> _expandDir(
    Directory dir,
    String prefix,
    List<_TransferFile> out,
  ) async {
    try {
      await for (final entity in dir.list(
        recursive: false,
        followLinks: false,
      )) {
        if (entity is File) {
          out.add(
            _TransferFile(
              file: entity,
              relativePath: '$prefix/${entity.path.split('/').last}',
            ),
          );
        } else if (entity is Directory) {
          final name = entity.path.split('/').last;
          await _expandDir(entity, '$prefix/$name', out);
        }
      }
    } catch (_) {}
  }

  // ------------------------------------------------------------------
  // Job management
  // ------------------------------------------------------------------

  void cancelJob(String jobId) {
    final job = jobs.where((j) => j.id == jobId).firstOrNull;
    if (job != null && !job.isComplete) {
      job.cancelled = true;
      job.isComplete = true;
      _safeNotify();
    }
  }

  void dismissCompleted() {
    jobs.removeWhere((j) => j.isComplete || j.cancelled);
    receiveJobs.removeWhere((j) => j.isComplete || j.hasError);
    _safeNotify();
  }

  void dismissCompletedReceives() {
    receiveJobs.removeWhere((j) => j.isComplete || j.hasError);
    _safeNotify();
  }
}
