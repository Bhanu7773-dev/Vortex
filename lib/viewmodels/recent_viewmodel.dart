import 'package:flutter/material.dart';
import '../models/recent_model.dart';

class RecentViewModel extends ChangeNotifier {
  final String totalItemsText = '0 items in total';

  final List<RecentSectionModel> sections = [];
}
