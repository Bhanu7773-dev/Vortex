import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:vortex/theme/app_theme.dart';
import 'package:vortex/services/connection_manager.dart';
import 'package:vortex/services/transfer_service.dart';
import 'package:vortex/utils/file_opener.dart';

class ReceiveView extends StatelessWidget {
  const ReceiveView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          'Incoming files',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Consumer<TransferService>(
            builder: (context, ts, _) {
              final hasDone = ts.receiveJobs.any(
                (j) => j.isComplete || j.hasError || j.cancelled,
              );
              if (!hasDone) return const SizedBox.shrink();
              return TextButton(
                onPressed: ts.dismissCompletedReceives,
                child: const Text(
                  'Clear done',
                  style: TextStyle(
                    color: AppTheme.accentLime,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<TransferService>(
        builder: (context, ts, _) {
          final jobs = ts.receiveJobs;
          final failedCount =
              jobs.where((j) => j.hasError && !j.cancelled).length;
          final cancelledCount = jobs.where((j) => j.cancelled).length;
          final activeCount = jobs
              .where((j) => !j.isComplete && !j.hasError && !j.cancelled)
              .length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary counter header: 1 failed  2 cancelled  0 active
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    _buildCounterItem(
                      count: failedCount,
                      label: 'failed',
                      color: const Color(0xFFFF5C5C),
                    ),
                    const SizedBox(width: 24),
                    _buildCounterItem(
                      count: cancelledCount,
                      label: 'cancelled',
                      color: Colors.white,
                    ),
                    const SizedBox(width: 24),
                    _buildCounterItem(
                      count: activeCount,
                      label: 'active',
                      color: activeCount > 0
                          ? AppTheme.accentLime
                          : const Color(0xFF78828A),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFF14171B)),

              // Content list or empty state
              Expanded(
                child: jobs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14171B),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFF1E2228),
                                ),
                              ),
                              child: const Icon(
                                Icons.download_rounded,
                                size: 48,
                                color: Color(0xFF78828A),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Nothing receiving',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Files sent to this device will appear here',
                              style: TextStyle(
                                color: Color(0xFF78828A),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms)
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: jobs.length,
                        itemBuilder: (context, index) {
                          final job = jobs[index];
                          return _ReceiveJobRow(job: job)
                              .animate()
                              .fadeIn(duration: 300.ms, delay: (40 * index).ms);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCounterItem({
    required int count,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: count > 0 ? color : const Color(0xFF78828A),
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF78828A),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ReceiveJobRow extends StatelessWidget {
  const _ReceiveJobRow({required this.job});
  final ReceiveJob job;

  @override
  Widget build(BuildContext context) {
    final progress = job.progress;
    final int percentInt =
        (progress >= 0 ? (progress * 100) : 0).clamp(0, 100).toInt();

    final bool isFailed = job.hasError && !job.cancelled;
    final bool isCancelled = job.cancelled;
    final bool isComplete = job.isComplete && !job.hasError;
    final bool isSaving = job.isSaving;

    // Status label and color
    final String statusText;
    final Color statusColor;
    final Color barColor;

    if (isFailed) {
      statusText = 'Failed · $percentInt%';
      statusColor = const Color(0xFFFF5C5C);
      barColor = const Color(0xFFFF5C5C);
    } else if (isCancelled) {
      statusText = 'Cancelled · $percentInt%';
      statusColor = const Color(0xFF78828A);
      barColor = const Color(0xFF5A636C);
    } else if (isSaving) {
      statusText = 'Saving to disk…';
      statusColor = Colors.orange.shade300;
      barColor = Colors.orange.shade300;
    } else if (isComplete) {
      statusText = 'Completed · 100%';
      statusColor = AppTheme.accentLime;
      barColor = AppTheme.accentLime;
    } else {
      // Active receiving
      statusText = 'Receiving · $percentInt%  (${job.speedText})';
      statusColor = AppTheme.accentLime;
      barColor = AppTheme.accentLime;
    }

    final double barValue = isSaving
        ? 1.0
        : (progress >= 0 ? progress.clamp(0.0, 1.0) : 0.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: File name (Bold White)
              Text(
                job.fileName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Row 2: Status & percentage (Left) and Action button (Right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isFailed || isCancelled)
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please ask sender to re-send ${job.fileName}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            backgroundColor: const Color(0xFF16191E),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          color: AppTheme.accentLime,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else if (isComplete && job.savedPath != null)
                    GestureDetector(
                      onTap: () => FileOpener.openFile(context, job.savedPath!),
                      child: const Text(
                        'Open',
                        style: TextStyle(
                          color: AppTheme.accentLime,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else if (!isComplete && !job.hasError)
                    GestureDetector(
                      onTap: () {
                        context.read<TransferService>().cancelReceive(
                          id: job.id,
                          connectionManager: context.read<ConnectionManager>(),
                        );
                      },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFFFF5C5C),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 3: Slim Progress Bar
              LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Background Track
                      Container(
                        height: 2.5,
                        width: constraints.maxWidth,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2228),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Progress Fill
                      Container(
                        height: 2.5,
                        width: constraints.maxWidth * barValue,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFF14171B)),
      ],
    );
  }
}
