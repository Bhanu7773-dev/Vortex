import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vortex/services/connection_manager.dart';
import 'package:vortex/services/transfer_service.dart';
import 'package:vortex/theme/app_theme.dart';

/// Floating "Transfer Island" that persists above navigation
/// whenever a file transfer (outgoing or incoming) is active.
class TransferIsland extends StatefulWidget {
  const TransferIsland({super.key});

  @override
  State<TransferIsland> createState() => _TransferIslandState();
}

class _TransferIslandState extends State<TransferIsland> {
  String _calcEta(double bytesPerSec, int remainingBytes) {
    if (bytesPerSec <= 1024 || remainingBytes <= 0) return '';
    final seconds = (remainingBytes / bytesPerSec).round();
    if (seconds < 60) return '~${seconds}s left';
    final mins = seconds ~/ 60;
    final remSecs = seconds % 60;
    return '~${mins}m ${remSecs}s left';
  }

  String _formatTransferredBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransferService>(
      builder: (context, transferService, _) {
        final activeSend = transferService.activeJob;
        final activeReceive = transferService.receiveJobs
            .where((j) => !j.isComplete && !j.hasError && !j.cancelled)
            .firstOrNull;

        final bool isSending =
            activeSend != null && !activeSend.isComplete && !activeSend.cancelled;
        final bool isReceiving = activeReceive != null;

        if (!isSending && !isReceiving) {
          return const SizedBox.shrink();
        }

        final bool isSend = isSending;
        final String title;
        final double progress;
        final String speedText;
        final double currentSpeed;
        final int remainingBytes;
        final int transferredBytes;

        if (activeSend != null && !activeSend.isComplete && !activeSend.cancelled) {
          title = 'Sending to ${activeSend.deviceName}';
          progress = activeSend.progress.clamp(0.0, 1.0);
          speedText = activeSend.speedText;
          currentSpeed = activeSend.currentSpeed;
          remainingBytes = (activeSend.totalBytes - activeSend.sentBytes)
              .clamp(0, activeSend.totalBytes);
          transferredBytes = activeSend.sentBytes;
        } else if (activeReceive != null) {
          title = 'Receiving ${activeReceive.fileName}';
          progress = (activeReceive.progress >= 0 ? activeReceive.progress : 0.0)
              .clamp(0.0, 1.0);
          speedText = activeReceive.speedText;
          currentSpeed = activeReceive.currentSpeed;
          remainingBytes = activeReceive.totalBytes > 0
              ? (activeReceive.totalBytes - activeReceive.receivedBytes)
                  .clamp(0, activeReceive.totalBytes)
              : 0;
          transferredBytes = activeReceive.receivedBytes;
        } else {
          return const SizedBox.shrink();
        }

        final String eta = _calcEta(currentSpeed, remainingBytes);
        final String transferredText = _formatTransferredBytes(transferredBytes);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: GestureDetector(
            onTap: () => _openTransferDetails(
              context: context,
              isSend: isSend,
              sendJob: activeSend,
              receiveJob: activeReceive,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: const Color(0xFF14171A),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: const Color(0xFF22272E),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: 3.5,
                          color: Color(0xFF22272E),
                        ),
                        CircularProgressIndicator(
                          value: progress > 0 ? progress : 0.05,
                          strokeWidth: 3.5,
                          strokeCap: StrokeCap.round,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.accentLime,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              speedText,
                              style: const TextStyle(
                                color: AppTheme.accentLime,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              '·',
                              style: TextStyle(
                                color: Color(0xFF78828A),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              transferredText,
                              style: const TextStyle(
                                color: Color(0xFF78828A),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (eta.isNotEmpty) ...[
                              const SizedBox(width: 5),
                              const Text(
                                '·',
                                style: TextStyle(
                                  color: Color(0xFF78828A),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                eta,
                                style: const TextStyle(
                                  color: Color(0xFF78828A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _confirmCancel(
                      context,
                      transferService,
                      isSend,
                      activeSend?.id,
                      activeSend?.deviceName,
                      activeReceive?.id,
                    ),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF8A939E),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmCancel(
    BuildContext context,
    TransferService transferService,
    bool isSend,
    String? sendJobId,
    String? sendDeviceName,
    String? receiveJobId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14171B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cancel Transfer?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isSend
              ? 'Are you sure you want to stop sending?'
              : 'Are you sure you want to stop receiving this file?',
          style: const TextStyle(color: Color(0xFF78828A), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continue', style: TextStyle(color: Color(0xFF78828A))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5C5C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (isSend && sendJobId != null) {
                transferService.cancelJob(sendJobId);
                if (sendDeviceName != null) {
                  context
                      .read<ConnectionManager>()
                      .sendTransferCancelledBySender(sendDeviceName);
                }
              } else if (!isSend && receiveJobId != null) {
                final cm = context.read<ConnectionManager>();
                transferService.cancelReceive(
                  id: receiveJobId,
                  connectionManager: cm,
                );
              }
            },
            child: const Text('Stop Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openTransferDetails({
    required BuildContext context,
    required bool isSend,
    TransferJob? sendJob,
    ReceiveJob? receiveJob,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _TransferDetailsSheet(
        isSend: isSend,
        sendJobId: sendJob?.id,
        receiveJobId: receiveJob?.id,
      ),
    );
  }
}

class _TransferDetailsSheet extends StatefulWidget {
  final bool isSend;
  final String? sendJobId;
  final String? receiveJobId;

  const _TransferDetailsSheet({
    required this.isSend,
    this.sendJobId,
    this.receiveJobId,
  });

  @override
  State<_TransferDetailsSheet> createState() => _TransferDetailsSheetState();
}

class _TransferDetailsSheetState extends State<_TransferDetailsSheet> {
  final List<double> _speedSamples = [];
  Timer? _samplerTimer;

  @override
  void initState() {
    super.initState();
    _samplerTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final ts = context.read<TransferService>();
      final speed = widget.isSend
          ? (ts.activeJob?.currentSpeed ?? 0.0)
          : (ts.receiveJobs
                  .where((j) => j.id == widget.receiveJobId)
                  .firstOrNull
                  ?.currentSpeed ??
              0.0);

      if (mounted) {
        setState(() {
          _speedSamples.add(speed);
          if (_speedSamples.length > 25) {
            _speedSamples.removeAt(0);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _samplerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransferService>(
      builder: (context, transferService, _) {
        final sendJob = widget.sendJobId != null
            ? transferService.jobs
                .where((j) => j.id == widget.sendJobId)
                .firstOrNull
            : transferService.activeJob;

        final receiveJob = widget.receiveJobId != null
            ? transferService.receiveJobs
                .where((j) => j.id == widget.receiveJobId)
                .firstOrNull
            : transferService.receiveJobs
                .where((j) => !j.isComplete && !j.hasError)
                .firstOrNull;

        final bool isStillActive = widget.isSend
            ? (sendJob != null && !sendJob.isComplete && !sendJob.cancelled)
            : (receiveJob != null && !receiveJob.isComplete && !receiveJob.hasError);

        final double progress = widget.isSend
            ? (sendJob?.progress ?? 0.0)
            : (receiveJob != null && receiveJob.progress >= 0 ? receiveJob.progress : 0.0);

        final String speedText = widget.isSend
            ? (sendJob?.speedText ?? '0 B/s')
            : (receiveJob?.speedText ?? '0 B/s');

        final speedParts = speedText.split(' ');
        final speedNum = speedParts.isNotEmpty ? speedParts[0].trim() : '0.0';
        final speedUnit = speedParts.length > 1 ? speedParts[1].trim() : 'MB/s';

        final String title = widget.isSend
            ? 'Sending to ${sendJob?.deviceName ?? "Device"}'
            : 'Receiving ${receiveJob?.fileName ?? "File"}';

        final String progressText = widget.isSend
            ? '${sendJob?.sentText ?? "0 B"} of ${sendJob?.totalText ?? "0 B"}'
            : '${receiveJob?.receivedText ?? "0 B"} of ${receiveJob?.totalText ?? "0 B"}';

        final bool isMulti = widget.isSend && (sendJob?.isMultiChannel ?? false);

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF14171A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Color(0xFF22272E), width: 1.0),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E333B),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppTheme.accentLime,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isStillActive
                                    ? (isMulti
                                        ? 'Multi-channel turbo link'
                                        : 'Direct TCP stream')
                                    : 'Transfer completed',
                                style: const TextStyle(
                                  color: Color(0xFF78828A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70,
                        size: 26,
                      ),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const Text(
                  'Transfer speed',
                  style: TextStyle(
                    color: Color(0xFF78828A),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      speedNum,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      speedUnit,
                      style: const TextStyle(
                        color: Color(0xFF78828A),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  height: 110,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1215),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF1E2228),
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CustomPaint(
                    size: const Size(double.infinity, 110),
                    painter: _SpeedWavePainter(
                      samples: _speedSamples,
                      lineColor: AppTheme.accentLime,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      progressText,
                      style: const TextStyle(
                        color: Color(0xFF78828A),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                _SlicedProgressBar(
                  progress: progress,
                  height: 26,
                  activeColor: AppTheme.accentLime,
                  inactiveColor: const Color(0xFF20252D),
                ),
                const SizedBox(height: 32),

                if (isStillActive)
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      if (widget.isSend && sendJob != null) {
                        transferService.cancelJob(sendJob.id);
                        context
                            .read<ConnectionManager>()
                            .sendTransferCancelledBySender(sendJob.deviceName);
                      } else if (!widget.isSend && receiveJob != null) {
                        transferService.cancelReceive(
                          id: receiveJob.id,
                          connectionManager: context.read<ConnectionManager>(),
                        );
                      }
                    },
                    child: Container(
                      height: 52,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1315),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFFF5C5C).withValues(alpha: 0.55),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5C5C),
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Stop transfer',
                            style: TextStyle(
                              color: Color(0xFFFF5C5C),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 52,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.accentLime,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SlicedProgressBar extends StatelessWidget {
  final double progress;
  final double height;
  final Color activeColor;
  final Color inactiveColor;

  const _SlicedProgressBar({
    required this.progress,
    this.height = 26,
    this.activeColor = AppTheme.accentLime,
    this.inactiveColor = const Color(0xFF20252D),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final count = (totalWidth / 6.5).floor().clamp(25, 55);
        final activeCount = (count * progress.clamp(0.0, 1.0)).round();

        return SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(count, (index) {
              final isFilled = index < activeCount;
              return Container(
                width: 3.5,
                height: height,
                decoration: BoxDecoration(
                  color: isFilled ? activeColor : inactiveColor,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _SpeedWavePainter extends CustomPainter {
  final List<double> samples;
  final Color lineColor;

  _SpeedWavePainter({
    required this.samples,
    this.lineColor = AppTheme.accentLime,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final List<double> data = samples.length >= 3
        ? samples
        : [0.35, 0.42, 0.50, 0.46, 0.54, 0.50, 0.44, 0.52];

    double maxVal = 0.0;
    for (final s in data) {
      if (s > maxVal) maxVal = s;
    }
    if (maxVal <= 0.0) maxVal = 1.0;

    final path = Path();
    final fillPath = Path();
    final stepX = size.width / (data.length - 1);

    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalized = (data[i] / maxVal).clamp(0.08, 0.92);
      final y = size.height - (normalized * (size.height - 20)) - 10;
      points.add(Offset(x, y));
    }

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, size.height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cp1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final cp2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.16),
          lineColor.withValues(alpha: 0.01),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SpeedWavePainter oldDelegate) => true;
}
