// lib/widgets/share_sheet.dart
//
// Public share-sheet widget + helper used by all file views.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vortex/services/connection_manager.dart';
import 'package:vortex/services/discovery_service.dart';
import 'package:vortex/services/transfer_service.dart';
import 'package:vortex/theme/app_theme.dart';

/// Shows the Vortex "Send via Vortex" bottom sheet.
///
/// [filePaths]      – absolute paths of the files / folders to send.
/// [onSendStarted]  – optional callback fired when the user confirms and the
///   transfer begins (use it to exit selection mode, close previews, etc.).
void showVortexShareSheet(
  BuildContext context,
  List<String> filePaths, {
  VoidCallback? onSendStarted,
}) {
  final connectionManager = context.read<ConnectionManager>();
  final discoveryService = context.read<DiscoveryService>();
  final transferService = context.read<TransferService>();

  final deviceNames = connectionManager.connectedDeviceNames;
  final ipMap = <String, String?>{};
  for (final name in deviceNames) {
    String? ip = connectionManager.getDeviceIp(name);
    if (ip == null) {
      // Fuzzy match by name against recently discovered devices.
      final match = discoveryService.discoveredServices
          .where((d) => d.name == name || name.startsWith(d.name))
          .firstOrNull;
      ip = match?.host;
    }
    ipMap[name] = ip;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => ShareSheetContent(
      transferService: transferService,
      connectionManager: connectionManager,
      selectedPaths: filePaths,
      connectedDeviceNames: deviceNames,
      deviceIps: ipMap,
      onSendStarted: onSendStarted ?? () {},
    ),
  );
}

// ─── Share sheet widget ───────────────────────────────────────────────────────

class ShareSheetContent extends StatefulWidget {
  final TransferService transferService;
  final ConnectionManager connectionManager;
  final List<String> selectedPaths;
  final List<String> connectedDeviceNames;
  final Map<String, String?> deviceIps; // name → ip (null = unknown)
  final VoidCallback onSendStarted;

  const ShareSheetContent({
    super.key,
    required this.transferService,
    required this.connectionManager,
    required this.selectedPaths,
    required this.connectedDeviceNames,
    required this.deviceIps,
    required this.onSendStarted,
  });

  @override
  State<ShareSheetContent> createState() => _ShareSheetContentState();
}

class _ShareSheetContentState extends State<ShareSheetContent> {
  final Set<String> _selectedDevices = {};
  bool _sendToAll = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _selectedDevices.addAll(widget.connectedDeviceNames);
    _sendToAll =
        _selectedDevices.isNotEmpty &&
        _selectedDevices.length == widget.connectedDeviceNames.length;
  }

  @override
  Widget build(BuildContext context) {
    final devices = widget.connectedDeviceNames;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.send, color: AppTheme.accentBlue, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Send via Vortex',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.selectedPaths.length} item${widget.selectedPaths.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (devices.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.devices_other,
                          color: AppTheme.textGrey,
                          size: 52,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'No connected devices',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Pair with another device first using the\nLink button on the home screen.',
                          style: TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                _DeviceRow(
                  icon: Icons.all_inclusive,
                  title: 'Send to all devices',
                  subtitle:
                      '${devices.length} device${devices.length == 1 ? '' : 's'}',
                  isSelected: _sendToAll,
                  onTap: () => setState(() {
                    _sendToAll = !_sendToAll;
                    if (_sendToAll) {
                      _selectedDevices.addAll(devices);
                    } else {
                      _selectedDevices.clear();
                    }
                  }),
                ),
                const SizedBox(height: 6),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 6),

                ...devices.map((name) {
                  final ip = widget.deviceIps[name];
                  final isSelected = _selectedDevices.contains(name);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _DeviceRow(
                      icon: Icons.laptop,
                      title: name,
                      subtitle: ip ?? 'IP unknown',
                      isSelected: isSelected,
                      onTap: () => setState(() {
                        if (isSelected) {
                          _selectedDevices.remove(name);
                          _sendToAll = false;
                        } else {
                          _selectedDevices.add(name);
                          _sendToAll =
                              _selectedDevices.length == devices.length;
                        }
                      }),
                    ),
                  );
                }),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSending || _selectedDevices.isEmpty
                        ? null
                        : () => _startSending(context),
                    icon: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, size: 18),
                    label: Text(
                      _isSending
                          ? 'Sending…'
                          : 'Send to ${_selectedDevices.length} device${_selectedDevices.length == 1 ? '' : 's'}',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.white12,
                      disabledForegroundColor: Colors.white38,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startSending(BuildContext context) async {
    setState(() => _isSending = true);

    final targets = _selectedDevices
        .map((name) {
          final ip = widget.deviceIps[name];
          if (ip == null) return null;
          return (name: name, ip: ip, port: ConnectionManager.serverFixedPort);
        })
        .whereType<({String name, String ip, int port})>()
        .toList();

    if (targets.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not resolve IP for selected devices. Re-pair and try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isSending = false);
      return;
    }

    if (mounted) Navigator.pop(context);
    widget.onSendStarted();

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            TransferProgressDialog(transferService: widget.transferService),
      );
    }

    await widget.transferService.sendToDevices(
      selectedPaths: widget.selectedPaths,
      targets: targets,
      connectionManager: widget.connectionManager,
    );
  }
}

// ─── Device row tile ──────────────────────────────────────────────────────────

class _DeviceRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _DeviceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentBlue.withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.accentBlue : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withOpacity(
                  isSelected ? 0.25 : 0.12,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.accentBlue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? AppTheme.accentBlue : AppTheme.textGrey,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Transfer progress dialog ─────────────────────────────────────────────────

String _fmtSpeed(double bps) {
  if (bps >= 1024 * 1024)
    return '${(bps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  if (bps >= 1024) return '${(bps / 1024).toStringAsFixed(1)} KB/s';
  return '${bps.toStringAsFixed(0)} B/s';
}

class TransferProgressDialog extends StatefulWidget {
  final TransferService transferService;

  const TransferProgressDialog({super.key, required this.transferService});

  @override
  State<TransferProgressDialog> createState() => _TransferProgressDialogState();
}

class _TransferProgressDialogState extends State<TransferProgressDialog> {
  bool _done = false;
  Timer? _speedTimer;
  final List<double> _speedHistory = [];
  static const int _maxSpeedSamples = 30;
  /// The ID of the job this dialog was opened for, so we can track it even
  /// after it becomes isComplete/cancelled (when activeJob returns null).
  String? _trackedJobId;

  @override
  void initState() {
    super.initState();
    // Sample speed every 200ms for sparkline
    _speedTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final job = widget.transferService.activeJob;
      if (job != null && !job.isComplete && !job.cancelled) {
        setState(() {
          _speedHistory.add(job.currentSpeed);
          if (_speedHistory.length > _maxSpeedSamples) {
            _speedHistory.removeAt(0);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _speedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _done,
      child: AlertDialog(
        backgroundColor: AppTheme.cardGrey,
        title: Text(
          _done ? 'On Its Way!' : 'Transferring…',
          style: const TextStyle(color: Colors.white),
        ),
        content: ListenableBuilder(
          listenable: widget.transferService,
          builder: (context, _) {
            // Try to track by ID so we see cancelled state even after
            // activeJob returns null.
            TransferJob? job = widget.transferService.activeJob;
            if (job != null && _trackedJobId == null) {
              _trackedJobId = job.id;
            } else if (job == null && _trackedJobId != null) {
              job = widget.transferService.jobs
                  .where((j) => j.id == _trackedJobId)
                  .firstOrNull;
            }

            // Job was cancelled — show cancel message, then close.
            if (job != null && job.cancelled) {
              if (!_done) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _done = true);
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) {
                      widget.transferService.dismissCompleted();
                      Navigator.of(context, rootNavigator: true).pop();
                    }
                  });
                });
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.cancel_rounded,
                        color: Colors.grey.shade400, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        job.cancelMessage ?? 'Transfer cancelled.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final allBytesSent = job == null || job.progress >= 1.0;
            if (allBytesSent && !_done) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _done = true);
                widget.transferService.dismissCompleted();
              });
            }

            if (_done || job == null || job.progress >= 1.0) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.send_rounded,
                      color: Colors.blueAccent,
                      size: 28,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Your file has been sent.\nIt will be saved on the receiver\'s device shortly.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'To: ${job.deviceName}',
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  job.statusText,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!job.isComplete && !job.cancelled) ...[
                  const SizedBox(height: 4),
                  Text(
                    job.speedText,
                    style: const TextStyle(
                      color: AppTheme.accentBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (job.isMultiChannel && job.perChannelStats.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ...job.perChannelStats.map(
                      (ch) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.cable_rounded,
                              size: 12,
                              color: Colors.white38,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${ch.name}: ${_fmtSpeed(ch.sendSpeed)}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  // Speed sparkline graph
                  if (_speedHistory.length > 2) ...[
                    const SizedBox(height: 12),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CustomPaint(
                          size: const Size(double.infinity, 40),
                          painter: _SparklinePainter(
                            data: _speedHistory,
                            lineColor: AppTheme.accentBlue,
                            fillColor: AppTheme.accentBlue.withOpacity(0.2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: job.progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.black,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.accentBlue,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(job.progress * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          ListenableBuilder(
            listenable: widget.transferService,
            builder: (context, _) {
              if (_done ||
                  widget.transferService.activeJob == null ||
                  (widget.transferService.activeJob?.progress ?? 0) >= 1.0) {
                return TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      color: AppTheme.accentBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }
              return TextButton(
                onPressed: () {
                  final job = widget.transferService.activeJob;
                  if (job != null) {
                    widget.transferService.cancelJob(job.id);
                    // Tell the receiver we cancelled.
                    context
                        .read<ConnectionManager>()
                        .sendTransferCancelledBySender(job.deviceName);
                  }
                  Navigator.pop(context);
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.textGrey),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
/// Custom painter for drawing a sparkline speed graph
class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final Color fillColor;

  _SparklinePainter({
    required this.data,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final maxValue = data.reduce(math.max);
    if (maxValue == 0) return;

    final path = Path();
    final fillPath = Path();
    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalizedY = (data[i] / maxValue).clamp(0.0, 1.0);
      final y = size.height - (normalizedY * (size.height - 4)) - 2;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Complete fill path
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw fill
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // Draw current speed dot at the end
    if (data.isNotEmpty) {
      final lastX = (data.length - 1) * stepX;
      final lastY = size.height - ((data.last / maxValue).clamp(0.0, 1.0) * (size.height - 4)) - 2;
      final dotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(lastX, lastY), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.data.length != data.length ||
      (data.isNotEmpty && oldDelegate.data.isNotEmpty && oldDelegate.data.last != data.last);
}