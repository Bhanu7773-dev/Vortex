import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:vortex/services/connection_manager.dart';
import 'package:vortex/services/multi_channel_transfer.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';

String _fmtSpeed(double bps) {
  if (bps >= 1024 * 1024) {
    return '${(bps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
  if (bps >= 1024) {
    return '${(bps / 1024).toStringAsFixed(1)} KB/s';
  }
  return '${bps.toStringAsFixed(0)} B/s';
}

String _fmtBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

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

/// One file being tracked in a transfer job.
class _TransferFile {
  final File file;
  final String relativePath;
  _TransferFile({required this.file, required this.relativePath});
}

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
  double get currentSpeed => _speed.bytesPerSec;
  String get speedText => _fmtSpeed(_speed.bytesPerSec);
  String get sentText => _fmtBytes(sentBytes);
  String get totalText => _fmtBytes(totalBytes);

  /// Per-channel statistics (populated during multi-channel transfers).
  List<ChannelStats> perChannelStats = [];

  /// Whether this job is using multi-channel mode.
  bool isMultiChannel = false;

  String get channelSpeedSummary {
    if (perChannelStats.isEmpty) return '';
    return perChannelStats
        .map((c) => '${c.name}: ${_fmtSpeed(c.sendSpeed)}')
        .join(' | ');
  }

  void addSentBytes(int bytes) {
    sentBytes += bytes;
    _speed.record(sentBytes);
  }

  /// Optional message shown instead of the generic 'Cancelled' label.
  String? cancelMessage;

  String get statusText {
    if (error != null) return 'Error: $error';
    if (cancelled) return cancelMessage ?? 'Cancelled';
    if (isComplete) {
      return 'Done – $completedFiles file${completedFiles == 1 ? '' : 's'}';
    }
    return '$completedFiles / $totalFiles  •  $sentText / $totalText';
  }
}

class ReceiveJob {
  final String id;
  final String relativePath;

  /// -1 when sender did not include Content-Length.
  final int totalBytes;
  int receivedBytes;
  bool isComplete;
  bool hasError;
  bool cancelled;
  bool isSaving;
  String? savedPath;
  final DateTime startedAt;

  /// Human-readable reason for cancellation / error.
  String? cancelMessage;

  final _SpeedSampler _speed = _SpeedSampler();

  ReceiveJob({
    required this.id,
    required this.relativePath,
    required this.totalBytes,
  }) : receivedBytes = 0,
       isComplete = false,
       hasError = false,
       cancelled = false,
       isSaving = false,
       startedAt = DateTime.now();

  String get fileName => relativePath.split('/').last;

  /// Returns -1 when total size is unknown.
  double get progress =>
      totalBytes <= 0 ? -1.0 : (receivedBytes / totalBytes).clamp(0.0, 1.0);

  String get speedText => _fmtSpeed(_speed.bytesPerSec);
  double get currentSpeed => _speed.bytesPerSec;
  String get receivedText => _fmtBytes(receivedBytes);
  String get totalText => totalBytes > 0 ? _fmtBytes(totalBytes) : '?';

  void addBytes(int bytes) {
    receivedBytes += bytes;
    _speed.record(receivedBytes);
  }
}

class TransferService extends ChangeNotifier {
  static const int _notifyThresholdBytes = 512 * 1024;

  bool _disposed = false;

  final List<TransferJob> jobs = [];

  /// The currently active multi-channel sender, if any.
  /// Stored so that cancelJob() can kill it immediately.
  MultiChannelSender? _activeMcSender;

  TransferJob? get activeJob =>
      jobs.where((j) => !j.isComplete && !j.cancelled).firstOrNull;
  bool get hasActiveJob => activeJob != null;

  final List<ReceiveJob> receiveJobs = [];

  bool get hasActiveReceive =>
      receiveJobs.any((j) => !j.isComplete && !j.hasError);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

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

  /// Entry point: send [selectedPaths] (files and/or folders) to one device.
  /// Automatically uses multi-channel mode when the ConnectionManager has
  /// multiple usable network interfaces.
  Future<void> sendToDevice({
    required List<String> selectedPaths,
    required String deviceName,
    required String deviceIp,
    required int devicePort,
    ConnectionManager? connectionManager,
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

    if (connectionManager != null) {
      try {
        final mcResult = await _trySendMultiChannel(
          files: files,
          job: job,
          deviceName: deviceName,
          connectionManager: connectionManager,
        );
        if (mcResult) {
          job.isComplete = true;
          _safeNotify();
          return;
        }
      } catch (e) {
        debugPrint('[Transfer] Multi-channel failed, falling back: $e');
      }
    }

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

  /// Attempt multi-channel transfer. Returns true if successful.
  Future<bool> _trySendMultiChannel({
    required List<_TransferFile> files,
    required TransferJob job,
    required String deviceName,
    required ConnectionManager connectionManager,
  }) async {
    final fileManifest = <Map<String, dynamic>>[];
    for (final tf in files) {
      final stat = await tf.file.stat();
      fileManifest.add({
        'path': tf.relativePath,
        'size': stat.type == FileSystemEntityType.directory ? 0 : stat.size,
        'isDir': stat.type == FileSystemEntityType.directory,
      });
    }

    final response = await connectionManager.requestMultiChannel(
      deviceName: deviceName,
      files: fileManifest,
    );

    final receiverChannels = (response['channels'] as List)
        .map((e) => ChannelEndpoint.fromJson(e as Map<String, dynamic>))
        .toList();

    if (receiverChannels.isEmpty) return false;

    final targetIps = receiverChannels.map((e) => e.ip).toList();

    debugPrint(
        '[Transfer] Multi-channel: ${targetIps.length} channels to $targetIps');

    job.isMultiChannel = true;
    job.perChannelStats = [];
    _safeNotify();

    final completer = Completer<bool>();

    final sender = MultiChannelSender(
      targetIps: targetIps,
      files: files
          .map((f) => McTransferFile(file: f.file, relativePath: f.relativePath))
          .toList(),
      totalBytes: job.totalBytes,
      onProgress: (sent, total, channels) {
        job.sentBytes = sent;
        job._speed.record(sent);
        job.perChannelStats = channels;
        _safeNotify();
      },
      onComplete: () {
        job.completedFiles = job.totalFiles;
        _activeMcSender = null;
        if (!completer.isCompleted) completer.complete(true);
      },
      onError: (e) {
        debugPrint('[MultiSend] Error: $e');
        _activeMcSender = null;
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    _activeMcSender = sender;

    sender.start();

    return completer.future;
  }

  /// Send to multiple devices in parallel.
  Future<void> sendToDevices({
    required List<String> selectedPaths,
    required List<({String name, String ip, int port})> targets,
    ConnectionManager? connectionManager,
  }) async {
    await Future.wait(
      targets.map(
        (t) => sendToDevice(
          selectedPaths: selectedPaths,
          deviceName: t.name,
          deviceIp: t.ip,
          devicePort: t.port,
          connectionManager: connectionManager,
        ),
      ),
    );
  }

  /// High-speed raw TCP sender.  Opens a direct socket, writes a JSON
  /// header line, then streams the file in large chunks.
  static const int _tcpChunkSize = 1024 * 1024;

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

      bool pipeError = false;
      socket.done.catchError((e) {
        pipeError = true;
        debugPrint('[TCP Send] Async write error (absorbed): $e');
      });

      final fileLength = await tf.file.length();

      final header = jsonEncode({'path': tf.relativePath, 'size': fileLength});
      socket.add(utf8.encode('$header\n'));

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

      if (pipeError) return;

      await socket.flush();

      if (!job.cancelled) {
        try {
          await socket.first.timeout(const Duration(seconds: 30));
        } catch (_) {
        }
        job.completedFiles++;
        _safeNotify();
      }
    } catch (e) {
      debugPrint('[TCP Send] Error sending ${tf.relativePath}: $e');
      rethrow;
    } finally {
      try {
        socket?.destroy();
      } catch (_) {}
    }
  }

  /// Called before the first byte arrives. [totalBytes] is -1 if unknown.
  ReceiveJob startReceive({
    required String id,
    required String relativePath,
    required int totalBytes,
  }) {
    receiveJobs.removeWhere(
      (j) =>
          !j.isComplete &&
          !j.hasError &&
          j.relativePath == relativePath,
    );

    final job = ReceiveJob(
      id: id,
      relativePath: relativePath,
      totalBytes: totalBytes,
    );
    receiveJobs.insert(0, job);
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

  /// Called once all bytes are received but before the file is flushed/closed.
  void markReceiveSaving({required String id}) {
    final job = receiveJobs.where((j) => j.id == id).firstOrNull;
    if (job == null) return;
    job.isSaving = true;
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
    job.isSaving = false;
    job.hasError = hasError;
    job.savedPath = savedPath;
    _safeNotify();
  }

  /// Cancels all active and pending incoming receives at once.
  void cancelAllReceives({required ConnectionManager connectionManager}) {
    for (final job in List.of(receiveJobs)) {
      if (!job.isComplete) {
        job.cancelled = true;
        job.isComplete = true;
        job.hasError = true;
        job.cancelMessage = 'Cancelled';
        connectionManager.cancelReceiveJob(job.id);
      }
    }
    connectionManager.cancelReceiveJob('');
    _safeNotify();
  }

  /// Called when the user manually cancels an incoming transfer.
  void cancelReceive({
    required String id,
    required ConnectionManager connectionManager,
  }) {
    final job = receiveJobs.where((j) => j.id == id).firstOrNull;
    if (job != null) {
      job.cancelled = true;
      job.isComplete = true;
      job.hasError = true;
      job.cancelMessage = 'Cancelled';
    }
    connectionManager.cancelReceiveJob(id);
    cancelAllReceives(connectionManager: connectionManager);
  }

  /// Called when the SENDER remotely cancels the transfer.
  void cancelReceiveBySender(String id) {
    final job = receiveJobs.where((j) => j.id == id).firstOrNull;
    if (job == null || job.isComplete || job.cancelled) return;
    job.cancelled = true;
    job.isComplete = true;
    job.hasError = true;
    job.cancelMessage = 'Cancelled by sender';
    _safeNotify();
  }

  /// Called when the RECEIVER remotely cancels — marks outgoing job stopped.
  void cancelJobByReceiver() {
    final job = activeJob;
    if (job == null) return;
    job.cancelled = true;
    job.isComplete = true;
    job.cancelMessage = 'Cancelled by receiver';
    _activeMcSender?.cancel();
    _activeMcSender = null;
    _safeNotify();
  }

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

  void cancelJob(String jobId) {
    final job = jobs.where((j) => j.id == jobId).firstOrNull;
    if (job != null && !job.isComplete) {
      job.cancelled = true;
      job.isComplete = true;
      _activeMcSender?.cancel();
      _activeMcSender = null;
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
