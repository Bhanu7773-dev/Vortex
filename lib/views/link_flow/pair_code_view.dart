import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vortex/services/connection_manager.dart';
import 'package:vortex/services/discovery_service.dart';

class PairCodeView extends StatefulWidget {
  final bool isInitiator;
  final String? targetIp;
  final int? targetPort;
  final String? targetDeviceName;
  final String? incomingCode;

  const PairCodeView({
    Key? key,
    required this.isInitiator,
    this.targetIp,
    this.targetPort,
    this.targetDeviceName,
    this.incomingCode,
  }) : super(key: key);

  @override
  State<PairCodeView> createState() => _PairCodeViewState();
}

class _PairCodeViewState extends State<PairCodeView> {
  final _codeController = TextEditingController();
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    if (widget.isInitiator) {
      _sendLinkRequest();
    }
    context.read<ConnectionManager>().onConnectionEstablished = () {
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    };
  }

  @override
  void dispose() {
    // We only remove the listener if we are the one being disposed,
    // to avoid clearing a new connection's listener by accident if things happen fast.
    final cm = context.read<ConnectionManager>();
    if (cm.onConnectionEstablished != null) {
      cm.onConnectionEstablished = null;
    }
    super.dispose();
  }

  Future<void> _sendLinkRequest() async {
    final myDeviceName = context.read<DiscoveryService>().registeredName;
    final success = await context.read<ConnectionManager>().sendLinkRequest(
      widget.targetIp!,
      widget.targetPort!,
      myDeviceName,
    );
    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to request link')));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _verifyAndConnect() async {
    setState(() => _isConnecting = true);
    final success = await context.read<ConnectionManager>().connectWebSocket(
      widget.targetIp!,
      widget.targetPort!,
      _codeController.text,
      widget.targetDeviceName ?? 'Unknown Device',
    );

    if (mounted) setState(() => _isConnecting = false);

    if (success && mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid code or connection failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isInitiator ? 'Enter Code' : 'Pairing Code'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.isInitiator
                    ? 'Enter the 6-digit code shown on ${widget.targetDeviceName}'
                    : '${widget.targetDeviceName} wants to link.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 40),
              if (widget.isInitiator) ...[
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, letterSpacing: 8),
                  decoration: const InputDecoration(
                    hintText: '000000',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _isConnecting ? null : _verifyAndConnect,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: _isConnecting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Link Devices',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 40,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Text(
                    widget.incomingCode ?? '000000',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 10,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                const Text('Waiting for other device to enter code...'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
