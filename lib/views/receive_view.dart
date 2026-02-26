import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vortex/services/connection_manager.dart';
import 'package:vortex/services/transfer_service.dart';

class ReceiveView extends StatelessWidget {
  const ReceiveView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Incoming Files',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Consumer<TransferService>(
            builder: (context, ts, _) {
              final hasDone = ts.receiveJobs.any(
                (j) => j.isComplete || j.hasError,
              );
              if (!hasDone) return const SizedBox.shrink();
              return TextButton(
                onPressed: ts.dismissCompletedReceives,
                child: const Text(
                  'Clear done',
                  style: TextStyle(color: Colors.blueAccent),
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
                  Icon(
                    Icons.download_outlined,
                    size: 72,
                    color: Colors.white.withOpacity(0.15),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nothing receiving',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Files sent to this device will appear here.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.2),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: jobs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final job = jobs[index];
              return _ReceiveJobCard(job: job);
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
    final progress = job.progress; // -1 if unknown
    final isIndeterminate = !job.isComplete && progress < 0;
    final progressValue = (job.isComplete || job.hasError)
        ? (job.hasError ? null : 1.0)
        : (progress >= 0 ? progress : null);

    final Color barColor;
    if (job.hasError) {
      barColor = Colors.redAccent;
    } else if (job.isComplete) {
      barColor = Colors.greenAccent;
    } else {
      barColor = Colors.blueAccent;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── File name + status icon ──────────────────────────────────────
          Row(
            children: [
              Icon(
                job.hasError
                    ? Icons.error_outline
                    : job.isComplete
                    ? Icons.check_circle_outline
                    : Icons.downloading,
                color: barColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  job.fileName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!job.isComplete && !job.hasError) ...[
                Text(
                  job.speedText,
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    context.read<TransferService>().cancelReceive(
                      id: job.id,
                      connectionManager: context.read<ConnectionManager>(),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // ── Progress bar ─────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: isIndeterminate ? null : progressValue,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 8),

          // ── Bytes info ───────────────────────────────────────────────────
          Row(
            children: [
              Text(
                job.isComplete
                    ? (job.hasError ? 'Error' : 'Received')
                    : '${job.receivedText} / ${job.totalText}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
              if (!job.isComplete && !job.hasError && progress >= 0) ...[
                const Spacer(),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
