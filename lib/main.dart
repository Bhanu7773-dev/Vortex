import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vortex/services/discovery_service.dart';
import 'package:vortex/services/connection_manager.dart';
import 'package:vortex/services/transfer_service.dart';
import 'package:vortex/theme/app_theme.dart';
import 'package:vortex/views/main_view.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DiscoveryService()),
        ChangeNotifierProvider(create: (_) => ConnectionManager()),
        ChangeNotifierProvider(create: (_) => TransferService()),
      ],
      child: const VortexApp(),
    ),
  );
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
