import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:vortex/services/connection_manager.dart';
import 'package:vortex/services/transfer_service.dart';
import 'package:vortex/theme/app_theme.dart';

/// Floating glassmorphic "Transfer Island" that persists above navigation
/// whenever a file transfer (outgoing or incoming) is active.
class TransferIsland extends StatefulWidget {
  const TransferIsland({super.key});

  @override
  State<TransferIsland> createState() => _TransferIslandState();
}

class _TransferIslandState extends State<TransferIsland>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _calcEta(double bytesPerSec, int remainingBytes) {
    if (bytesPerSec <= 1024 || remainingBytes <= 0) return '';
    final seconds = (remainingBytes / bytesPerSec).round();
    if (seconds < 60) return '~${seconds}s left';
    final mins = seconds ~/ 60;
    final remSecs = seconds % 60;
    return '~${mins}m ${remSecs}s left';
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
        final bool isMultiChannel;
        final String statusDetail;

        if (activeSend != null && !activeSend.isComplete && !activeSend.cancelled) {
          title = 'Sending to ${activeSend.deviceName}';
          progress = activeSend.progress;
          speedText = activeSend.speedText;
          currentSpeed = activeSend.currentSpeed;
          remainingBytes = (activeSend.totalBytes - activeSend.sentBytes)
              .clamp(0, activeSend.totalBytes);
          isMultiChannel = activeSend.isMultiChannel;
          statusDetail =
              '${activeSend.completedFiles}/${activeSend.totalFiles} files';
        } else if (activeReceive != null) {
          title = 'Receiving ${activeReceive.fileName}';
          progress = activeReceive.progress < 0 ? 0.0 : activeReceive.progress;
          speedText = activeReceive.speedText;
          currentSpeed = activeReceive.currentSpeed;
          remainingBytes = activeReceive.totalBytes > 0
              ? (activeReceive.totalBytes - activeReceive.receivedBytes)
                  .clamp(0, activeReceive.totalBytes)
              : 0;
          isMultiChannel = false;
          statusDetail = activeReceive.isSaving
              ? 'Saving to disk...'
              : activeReceive.receivedText;
        } else {
          return const SizedBox.shrink();
        }

        final String eta = _calcEta(currentSpeed, remainingBytes);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: GestureDetector(
            onTap: () => _openTransferDetails(
              context: context,
              isSend: isSend,
              sendJob: activeSend,
              receiveJob: activeReceive,
            ),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulseAlpha = 0.12 + (_pulseController.value * 0.12);
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xF2121722),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppTheme.accentBlue.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentBlue.withValues(alpha: pulseAlpha),
                        blurRadius: 18,
                        spreadRadius: 1,
                        offset: const Offset(0, 3),
                      ),
                      const BoxShadow(
                        color: Colors.black54,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                      child: Row(
                        children: [
                          // ── Progress Ring with directional icon ────────
                          SizedBox(
                            width: 38,
                            height: 38,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: progress > 0 ? progress : null,
                                  strokeWidth: 3.2,
                                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isMultiChannel
                                        ? const Color(0xFF00E5FF)
                                        : AppTheme.accentBlue,
                                  ),
                                ),
                                Icon(
                                  isSend
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded,
                                  color: isMultiChannel
                                      ? const Color(0xFF00E5FF)
                                      : AppTheme.accentBlue,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // ── Title & Live Stats ─────────────────────────
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.1,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isMultiChannel)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00E5FF)
                                              .withValues(alpha: 0.18),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: const Color(0xFF00E5FF)
                                                .withValues(alpha: 0.5),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: const Text(
                                          'DUAL-LINK',
                                          style: TextStyle(
                                            color: Color(0xFF00E5FF),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      '⚡ $speedText',
                                      style: TextStyle(
                                        color: isMultiChannel
                                            ? const Color(0xFF00E5FF)
                                            : AppTheme.accentBlue,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '•  ${(progress * 100).toInt()}%',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (statusDetail.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '•  $statusDetail',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.5),
                                            fontSize: 11,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                    if (eta.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        eta,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.45),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // ── Action Buttons ─────────────────────────────
                          const SizedBox(width: 6),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _confirmCancel(
                                context,
                                transferService,
                                isSend,
                                activeSend?.id,
                                activeSend?.deviceName,
                                activeReceive?.id,
                              ),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Subtle Bottom Progress Bar ───────────────────────
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(22),
                      ),
                      child: LinearProgressIndicator(
                        value: progress > 0 ? progress : null,
                        minHeight: 2.5,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isMultiChannel
                              ? const Color(0xFF00E5FF)
                              : AppTheme.accentBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ).animate().slideY(
              begin: 0.3,
              end: 0,
              duration: 250.ms,
              curve: Curves.easeOutCubic,
            ).fadeIn(duration: 200.ms);
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
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cancel Transfer?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isSend
              ? 'Are you sure you want to cancel the outgoing transfer?'
              : 'Are you sure you want to stop receiving this file?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continue Transfer', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCF6679),
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
            child: const Text('Cancel Transfer'),
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

// ─── Transfer Details Expanded Modal ─────────────────────────────────────────

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
    _samplerTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      final ts = context.read<TransferService>();
      final speed = widget.isSend
          ? (ts.activeJob?.currentSpeed ?? 0)
          : (ts.receiveJobs
                  .where((j) => j.id == widget.receiveJobId)
                  .firstOrNull
                  ?.currentSpeed ??
              0);

      if (mounted) {
        setState(() {
          _speedSamples.add(speed);
          if (_speedSamples.length > 30) {
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

        final String title = widget.isSend
            ? 'Sending to ${sendJob?.deviceName ?? "Peer"}'
            : 'Receiving ${receiveJob?.fileName ?? "File"}';

        final bool isMulti = widget.isSend && (sendJob?.isMultiChannel ?? false);

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161922),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Color(0x336EBEFB), width: 1.2),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isMulti ? const Color(0xFF00E5FF) : AppTheme.accentBlue)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        widget.isSend
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: isMulti ? const Color(0xFF00E5FF) : AppTheme.accentBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isStillActive
                                ? (isMulti
                                    ? 'Multi-Channel Turbo Active'
                                    : 'Direct TCP Stream')
                                : 'Transfer Ended',
                            style: TextStyle(
                              color: isStillActive
                                  ? (isMulti
                                      ? const Color(0xFF00E5FF)
                                      : Colors.greenAccent)
                                  : Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.white70, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Speedometer & Sparkline Card ─────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1118),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Transfer Speed',
                            style: TextStyle(color: Colors.white60, fontSize: 13),
                          ),
                          Text(
                            '⚡ $speedText',
                            style: TextStyle(
                              color: isMulti
                                  ? const Color(0xFF00E5FF)
                                  : AppTheme.accentBlue,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 48,
                        child: _speedSamples.length > 2
                            ? CustomPaint(
                                size: const Size(double.infinity, 48),
                                painter: _IslandSparklinePainter(
                                  data: _speedSamples,
                                  lineColor: isMulti
                                      ? const Color(0xFF00E5FF)
                                      : AppTheme.accentBlue,
                                  fillColor: (isMulti
                                          ? const Color(0xFF00E5FF)
                                          : AppTheme.accentBlue)
                                      .withValues(alpha: 0.18),
                                ),
                              )
                            : Center(
                                child: Text(
                                  'Sampling real-time speed...',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Per-Channel Breakdown (If Multi-Channel) ─────────────
                if (isMulti &&
                    sendJob != null &&
                    sendJob.perChannelStats.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E1118),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.hub_rounded,
                                color: Color(0xFF00E5FF), size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Bonded Channels Breakdown',
                              style: TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...sendJob.perChannelStats.map((ch) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  ch.name.toLowerCase().contains('usb')
                                      ? Icons.usb_rounded
                                      : Icons.wifi_rounded,
                                  color: Colors.white60,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    ch.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  sendJob.speedText,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Progress Details ──────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.isSend
                          ? '${sendJob?.sentText ?? "0 B"} of ${sendJob?.totalText ?? "0 B"}'
                          : '${receiveJob?.receivedText ?? "0 B"} of ${receiveJob?.totalText ?? "0 B"}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                    minHeight: 8,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isMulti ? const Color(0xFF00E5FF) : AppTheme.accentBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Controls ─────────────────────────────────────────────
                if (isStillActive)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF281C20),
                      foregroundColor: const Color(0xFFFF6E6E),
                      side: const BorderSide(color: Color(0x66FF6E6E)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.stop_rounded, size: 20),
                    label: const Text(
                      'Stop Transfer',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
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
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentBlue,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.bold),
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

// ─── Sparkline Painter for Speed Chart ───────────────────────────────────────

class _IslandSparklinePainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final Color fillColor;

  _IslandSparklinePainter({
    required this.data,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final maxVal = data.reduce(math.max);
    final effectiveMax = maxVal > 0 ? maxVal : 1.0;

    final path = Path();
    final fillPath = Path();
    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalizedY = (1.0 - (data[i] / effectiveMax).clamp(0.0, 1.0));
      final y = normalizedY * (size.height - 8) + 4;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _IslandSparklinePainter oldDelegate) => true;
}
