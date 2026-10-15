import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vortex/services/discovery_service.dart';
import 'package:vortex/services/connection_manager.dart';
import 'package:vortex/services/transfer_service.dart';
import 'package:vortex/services/web_share_service.dart';
import 'package:vortex/theme/app_theme.dart';
import 'package:vortex/views/main_view.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DiscoveryService()),
        ChangeNotifierProvider(create: (_) => ConnectionManager()),
        ChangeNotifierProvider(create: (_) => TransferService()),
        ChangeNotifierProvider(create: (_) => WebShareService()),
      ],
      child: const VortexApp(),
    ),
  );
}

class VortexApp extends StatelessWidget {
  const VortexApp({super.key});

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
