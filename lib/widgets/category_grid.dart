import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../theme/app_theme.dart';
import '../viewmodels/home_viewmodel.dart';
import '../views/photos_view.dart';
import '../views/videos_view.dart';
import '../views/media_list_views.dart';

class CategoryGrid extends StatelessWidget {
  final List<CategoryModel> categories;

  const CategoryGrid({Key? key, required this.categories}) : super(key: key);

  Future<void> _onCategoryTap(
    BuildContext context,
    CategoryModel category,
  ) async {
    switch (category.name) {
      case 'Photos':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PhotosView()),
        );
        break;
      case 'Videos':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VideosView()),
        );
        break;
      case 'Audio':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AudioView()),
        );
        break;
      case 'Archives':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ArchivesView()),
        );
        break;
      case 'APKs':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ApksView()),
        );
        break;
      case 'Documents':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DocumentsView()),
        );
        break;
      default:
        return;
    }
    if (context.mounted) {
      context.read<HomeViewModel>().refreshCategoryCounts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 8),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Categories',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideX(begin: -0.1, end: 0, duration: 400.ms),
          // Top row - 3 items
          Row(
            children: List.generate(3, (index) {
              final category = categories[index];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index < 2 ? 10 : 0,
                  ),
                  child: _ModernCategoryCard(
                    category: category,
                    onTap: () => _onCategoryTap(context, category),
                    compact: true,
                  )
                      .animate()
                      .fadeIn(duration: 500.ms, delay: (100 * index).ms)
                      .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          // Bottom row - 3 items
          Row(
            children: List.generate(3, (index) {
              final category = categories[index + 3];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index < 2 ? 10 : 0,
                  ),
                  child: _ModernCategoryCard(
                    category: category,
                    onTap: () => _onCategoryTap(context, category),
                    compact: true,
                  )
                      .animate()
                      .fadeIn(duration: 500.ms, delay: (100 * (index + 3)).ms)
                      .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _ModernCategoryCard extends StatefulWidget {
  final CategoryModel category;
  final VoidCallback onTap;
  final bool compact;

  const _ModernCategoryCard({
    required this.category,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<_ModernCategoryCard> createState() => _ModernCategoryCardState();
}

class _ModernCategoryCardState extends State<_ModernCategoryCard> with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _countController;
  late Animation<int> _countAnim;
  int _targetCount = 0;
  String _suffix = '';

  @override
  void initState() {
    super.initState();
    _parseInfoString();
    _countController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _countAnim = IntTween(begin: 0, end: _targetCount).animate(
      CurvedAnimation(parent: _countController, curve: Curves.easeOutCubic),
    );
    // Delay matches the card's stagger animation
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _countController.forward();
    });
  }

  void _parseInfoString() {
    // Parse strings like "42 files", "128 items", "1.2 GB"
    final match = RegExp(r'^(\d+)\s*(.*)$').firstMatch(widget.category.info);
    if (match != null) {
      _targetCount = int.tryParse(match.group(1) ?? '0') ?? 0;
      _suffix = match.group(2) ?? '';
    } else {
      _targetCount = 0;
      _suffix = widget.category.info;
    }
  }

  @override
  void didUpdateWidget(_ModernCategoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category.info != widget.category.info) {
      final oldCount = _targetCount;
      _parseInfoString();
      _countAnim = IntTween(begin: oldCount, end: _targetCount).animate(
        CurvedAnimation(parent: _countController, curve: Curves.easeOutCubic),
      );
      _countController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.category.iconColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.category.iconColor.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.category.iconColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.category.icon,
                      color: widget.category.iconColor,
                      size: 20,
                    ),
                  ),
                  if (widget.category.badgeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.category.badgeCount > 9
                            ? '9+'
                            : widget.category.badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.category.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              AnimatedBuilder(
                animation: _countAnim,
                builder: (context, child) {
                  final displayText = _targetCount > 0
                      ? '${_countAnim.value}${_suffix.isNotEmpty ? ' $_suffix' : ''}'
                      : widget.category.info;
                  return Text(
                    displayText,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
