import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vortex/services/discovery_service.dart';
import 'package:vortex/services/connection_manager.dart';
import 'pair_code_view.dart';

class WifiScanView extends StatefulWidget {
  const WifiScanView({Key? key}) : super(key: key);

  @override
  State<WifiScanView> createState() => _WifiScanViewState();
}

class _WifiScanViewState extends State<WifiScanView> {
  // Cache Provider references so dispose() never looks up a deactivated
  // widget's ancestor.
  late final DiscoveryService _discoveryService;
  late final ConnectionManager _connectionManager;

  @override
  void initState() {
    super.initState();
    _discoveryService = context.read<DiscoveryService>();
    _connectionManager = context.read<ConnectionManager>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDiscoveryAndServer();
    });
  }

  @override
  void dispose() {
    // Use cached reference — context.read() would crash here.
    _discoveryService.stopDiscovery();
    super.dispose();
  }

  Future<void> _startDiscoveryAndServer() async {
    if (!mounted) return;
    await _discoveryService.startDiscovery();
    await _connectionManager.startServer();

    final port = _connectionManager.serverPort;
    if (port != null && mounted) {
      await _discoveryService.registerService(
        _discoveryService.registeredName,
        _connectionManager.deviceId,
        port,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Linked Devices'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<DiscoveryService>(
        builder: (context, discovery, child) {
          final services = discovery.discoveredServices;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Center(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.withOpacity(0.1),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.radar, size: 60, color: Colors.blue),
                    ),
                  ),
                ),
              ),
              const Text(
                'Searching for Vortex devices...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: services.isEmpty
                    ? const Center(
                        child: Text('No devices found yet on your Wi-Fi.'),
                      )
                    : ListView.builder(
                        itemCount: services.length,
                        itemBuilder: (context, index) {
                          final service = services[index];
                          final rawName = service.name;
                          final name = rawName.replaceAll(
                            RegExp(r'\s*\(\d+\)$'),
                            '',
                          );
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.blue,
                              child: Icon(
                                Icons.phone_android,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(name),
                            subtitle: const Text('Tap to Link'),
                            onTap: () async {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PairCodeView(
                                    isInitiator: true,
                                    targetIp: service.host,
                                    targetPort: service.port,
                                    targetDeviceName: name,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
