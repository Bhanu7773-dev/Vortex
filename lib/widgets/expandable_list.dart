import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../viewmodels/home_viewmodel.dart';
import '../models/category_model.dart';
import '../theme/app_theme.dart';

class ExpandableSection extends StatelessWidget {
  final ExpandableSectionModel section;

  const ExpandableSection({Key? key, required this.section}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children:
          [
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(
                      section.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    iconColor: AppTheme.textGrey,
                    collapsedIconColor: AppTheme.textGrey,
                    initiallyExpanded: true,
                    childrenPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                    ),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                    children: [
                      Card(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: section.items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final isLast = index == section.items.length - 1;

                            return Column(
                              children: [
                                ListTile(
                                  leading: Icon(
                                    item.icon,
                                    color: item.iconColor,
                                    size: 24,
                                  ),
                                  title: Text(
                                    item.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (item.trailingInfo.isNotEmpty)
                                        Text(
                                          item.trailingInfo,
                                          style: const TextStyle(
                                            color: AppTheme.textGrey,
                                            fontSize: 14,
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.chevron_right,
                                        color: AppTheme.textGrey,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 0.0,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  onTap: () {
                                    final vm = Provider.of<HomeViewModel>(
                                      context,
                                      listen: false,
                                    );
                                    vm.onSectionItemTap(
                                      context,
                                      section.title,
                                      item.title,
                                    );
                                  },
                                  onLongPress: () {
                                    _showDeleteOptions(
                                      context,
                                      section.title,
                                      item.title,
                                    );
                                  },
                                ),
                                if (!isLast)
                                  const Divider(
                                    color: Colors.white10,
                                    height: 1,
                                    indent: 56, // Align divider with text
                                    endIndent: 16,
                                  ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ]
              .animate()
              .fade(duration: 400.ms)
              .slideY(
                begin: 0.1,
                end: 0,
                duration: 400.ms,
                curve: Curves.easeOut,
              ),
    );
  }

  void _showDeleteOptions(
    BuildContext context,
    String sectionTitle,
    String itemTitle,
  ) {
    if (sectionTitle == 'Sources') return;

    final homeViewModel = Provider.of<HomeViewModel>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: const BoxDecoration(
          color: AppTheme.cardGrey,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(color: Colors.black54, blurRadius: 10, spreadRadius: 1),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.settings_suggest_outlined,
                    color: AppTheme.accentBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Item Settings',
                        style: TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        itemTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            InkWell(
              onTap: () async {
                Navigator.pop(sheetContext);

                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppTheme.cardGrey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Text(
                      'Remove Bookmark?',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: Text(
                      'This will remove "$itemTitle" from your Home screen. The actual files will not be deleted.',
                      style: const TextStyle(color: AppTheme.textGrey),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: AppTheme.textGrey),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  if (sectionTitle == 'Quick access') {
                    await homeViewModel.removeQuickAccessByTitle(itemTitle);
                  } else if (sectionTitle == 'Tag') {
                    await homeViewModel.removeTag(itemTitle);
                  }
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Remove from Home',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: AppTheme.textGrey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text(
                'Close',
                style: TextStyle(color: AppTheme.accentBlue),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
