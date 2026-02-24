import 'package:flutter/material.dart';

class CategoryModel {
  final String name;
  final IconData icon;
  final Color iconColor;
  final String info; // Usually item count or size
  final int badgeCount;

  CategoryModel({
    required this.name,
    required this.icon,
    required this.iconColor,
    required this.info,
    this.badgeCount = 0,
  });
}

class ExpandableSectionModel {
  final String title;
  final List<ExpandableItemModel> items;

  ExpandableSectionModel({required this.title, required this.items});
}

class ExpandableItemModel {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String trailingInfo;

  ExpandableItemModel({
    required this.title,
    required this.icon,
    this.iconColor = Colors.white,
    this.trailingInfo = '',
  });
}
