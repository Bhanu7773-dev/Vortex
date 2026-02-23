import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../theme/app_theme.dart';

class ExpandableSection extends StatelessWidget {
  final ExpandableSectionModel section;

  const ExpandableSection({Key? key, required this.section}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
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
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0),
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
      ],
    );
  }
}
