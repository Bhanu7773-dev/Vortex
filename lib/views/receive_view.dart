import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:vortex/services/connection_manager.dart';
import 'package:vortex/services/transfer_service.dart';

class ReceiveView extends StatelessWidget {
  const ReceiveView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Incoming Files',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          Consumer<TransferService>(
            builder: (context, ts, _) {
              final hasDone = ts.receiveJobs.any(
                (j) => j.isComplete || j.hasError,
              );
              if (!hasDone) return const SizedBox.shrink();
              return TextButton(
                onPressed: ts.dismissCompletedReceives,
                child: Text(
                  'Clear done',
                  style: TextStyle(color: Colors.blue.shade400),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<TransferService>(
        builder: (context, ts, _) {
          final jobs = ts.receiveJobs;

          if (jobs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Icon(
                      Icons.download_rounded,
                      size: 56,
                      color: Colors.blue.shade300,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Nothing receiving',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Files sent to this device will appear here',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 500.ms);
          }

          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            itemCount: jobs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final job = jobs[index];
              return _ReceiveJobCard(job: job)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: (50 * index).ms)
                  .slideX(begin: 0.05, end: 0, duration: 300.ms);
            },
          );
        },
      ),
    );
  }
}

class _ReceiveJobCard extends StatelessWidget {
  const _ReceiveJobCard({required this.job});
  final ReceiveJob job;

  @override
  Widget build(BuildContext context) {
    final progress = job.progress;
    final isIndeterminate = job.isSaving || (!job.isComplete && !job.isSaving && progress < 0);
    final progressValue = job.isSaving
        ? null
        : (job.isComplete || job.hasError)
            ? (job.hasError ? null : 1.0)
            : (progress >= 0 ? progress : null);

    final Color barColor;
    final Color bgColor;
    if (job.hasError) {
      barColor = Colors.red.shade400;
      bgColor = Colors.red.withOpacity(0.08);
    } else if (job.isComplete) {
      barColor = Colors.green.shade400;
      bgColor = Colors.green.withOpacity(0.08);
    } else if (job.isSaving) {
      barColor = Colors.orange.shade400;
      bgColor = Colors.orange.withOpacity(0.08);
    } else {
      barColor = Colors.blue.shade400;
      bgColor = Colors.blue.withOpacity(0.08);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: barColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: barColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  job.hasError
                      ? Icons.error_outline_rounded
                      : job.isComplete
                      ? Icons.check_circle_outline_rounded
                      : Icons.downloading_rounded,
                  color: barColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.fileName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      job.isSaving
                          ? 'Writing to disk…'
                          : job.isComplete
                              ? (job.hasError ? 'Failed' : 'Completed')
                              : '${job.receivedText} / ${job.totalText}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (job.isSaving) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Saving',
                    style: TextStyle(
                      color: Colors.orange.shade300,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else if (!job.isComplete && !job.hasError) ...[
                Text(
                  job.speedText,
                  style: TextStyle(
                    color: Colors.blue.shade300,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    context.read<TransferService>().cancelReceive(
                      id: job.id,
                      connectionManager: context.read<ConnectionManager>(),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.red.shade300,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: isIndeterminate ? null : progressValue,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 6,
            ),
          ),

          if (!job.isComplete && !job.hasError && progress >= 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
