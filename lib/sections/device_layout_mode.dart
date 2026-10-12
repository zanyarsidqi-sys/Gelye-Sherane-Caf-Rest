import 'package:flutter/material.dart';
import '../shared/section_shell.dart';

/// Informational layout diagnostics; the app continues to select its
/// responsive navigation based on the actual available screen width.
class DeviceLayoutModeScreen extends StatelessWidget {
  const DeviceLayoutModeScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: 'Device Layout Mode',
    description: 'Device layout diagnostics',
    sectionId: 'device_layout_mode',
    authorizedContent: _DeviceLayoutModeScreenContent(),
  );
}

class _DeviceLayoutModeScreenContent extends StatelessWidget {
  const _DeviceLayoutModeScreenContent();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 700;
    return Scaffold(
      appBar: AppBar(title: const Text('Device Layout Mode')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Card(child: ListTile(
          leading: Icon(compact ? Icons.phone_iphone : Icons.desktop_windows),
          title: Text(compact ? 'iPhone / Compact Layout' : 'Desktop / Wide Layout'),
          subtitle: Text('Available width: ${width.round()} px'),
        )),
        const SizedBox(height: 12),
        const Text('Layout automatically adapts to the window size. Resize your browser to preview compact and desktop navigation.'),
        const SizedBox(height: 12),
        const Text('This display setting does not change employee permissions or business data.'),
      ]),
    );
  }
}
