import 'package:flutter/material.dart';
import 'package:vortex/theme/app_theme.dart';
import 'package:vortex/views/main_view.dart';

void main() {
  runApp(const VortexApp());
}

class VortexApp extends StatelessWidget {
  const VortexApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vortex',
      theme: AppTheme.trueBlackTheme,
      home: const MainWrapperView(),
      debugShowCheckedModeBanner: false,
    );
  }
}
