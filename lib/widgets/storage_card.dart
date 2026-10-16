import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vortex/views/all_files_view.dart';

class StorageCard extends StatefulWidget {
  final String totalStorage;
  final String usedStorage;
  final double percentage;

  const StorageCard({
    Key? key,
    required this.totalStorage,
    required this.usedStorage,
    required this.percentage,
  }) : super(key: key);

  @override
  State<StorageCard> createState() => _StorageCardState();
}

class _StorageCardState extends State<StorageCard> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _percentAnim;
  late Animation<double> _barAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _percentAnim = Tween<double>(begin: 0, end: widget.percentage).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _barAnim = Tween<double>(begin: 0, end: widget.percentage.clamp(0.0, 1.0)).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void didUpdateWidget(StorageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percentage != widget.percentage) {
      _percentAnim = Tween<double>(begin: _percentAnim.value, end: widget.percentage).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
      );
      _barAnim = Tween<double>(begin: _barAnim.value, end: widget.percentage.clamp(0.0, 1.0)).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
      );
      _animController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color _getStorageColor() {
    if (widget.percentage > 0.9) return const Color(0xFFFF6B6B);
    if (widget.percentage > 0.75) return const Color(0xFFFFB347);
    return const Color(0xFF4ECDC4);
  }

  @override
  Widget build(BuildContext context) {
    final storageColor = _getStorageColor();
    final freeStorage = _calculateFreeStorage();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AllFilesView()),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              storageColor.withOpacity(0.15),
              storageColor.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: storageColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: storageColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.folder_rounded,
                    color: storageColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Device Storage',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$freeStorage free of ${widget.totalStorage}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: storageColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _percentAnim,
                        builder: (context, child) {
                          return Text(
                            '${(_percentAnim.value * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: storageColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: storageColor,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _barAnim,
                    builder: (context, child) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _barAnim.value,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                storageColor,
                                storageColor.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StorageIndicator(
                  color: storageColor,
                  label: 'Used',
                  value: widget.usedStorage,
                ),
                const SizedBox(width: 24),
                _StorageIndicator(
                  color: Colors.white.withOpacity(0.3),
                  label: 'Free',
                  value: freeStorage,
                ),
              ],
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 600.ms, curve: Curves.easeOut)
          .slideY(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
    );
  }

  String _calculateFreeStorage() {
    try {
      final totalNum = _parseStorageValue(widget.totalStorage);
      final usedNum = _parseStorageValue(widget.usedStorage);
      final freeNum = totalNum - usedNum;
      return _formatStorage(freeNum);
    } catch (e) {
      return '...';
    }
  }

  double _parseStorageValue(String storage) {
    final match = RegExp(r'([\d.]+)\s*(GB|MB|TB)', caseSensitive: false).firstMatch(storage);
    if (match == null) return 0;
    final value = double.parse(match.group(1)!);
    final unit = match.group(2)!.toUpperCase();
    switch (unit) {
      case 'TB':
        return value * 1024;
      case 'GB':
        return value;
      case 'MB':
        return value / 1024;
      default:
        return value;
    }
  }

  String _formatStorage(double gb) {
    if (gb >= 1024) {
      return '${(gb / 1024).toStringAsFixed(1)} TB';
    } else if (gb >= 1) {
      return '${gb.toStringAsFixed(1)} GB';
    } else {
      return '${(gb * 1024).toStringAsFixed(0)} MB';
    }
  }
}

class _StorageIndicator extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _StorageIndicator({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
