import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local appearance preference. Never controls access or business rules.
class AppearancePreferencesPanel extends StatefulWidget {
  const AppearancePreferencesPanel({super.key});

  @override
  State<AppearancePreferencesPanel> createState() => _AppearancePreferencesPanelState();
}

class _AppearancePreferencesPanelState extends State<AppearancePreferencesPanel> {
  static const _key = 'cafe_theme_mode_v2';
  String _mode = 'system';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final saved = prefs.getString(_key);
    setState(() {
      _mode = {'system', 'light', 'dark'}.contains(saved) ? saved! : 'system';
      _loading = false;
    });
  }

  Future<void> _select(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode);
    if (!mounted) return;
    setState(() => _mode = mode);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Appearance saved. Restart the app to apply the theme.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final isDark = _mode == 'dark' ||
        (_mode == 'system' && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final previewTheme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.blue,
      brightness: isDark ? Brightness.dark : Brightness.light,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Appearance', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Choose how the app looks on this device. Your selection is saved locally.'),
        const SizedBox(height: 12),
        Card(child: RadioGroup<String>(groupValue: _mode, onChanged: (v) { if (v != null) { _select(v); } }, child: Column(children: [
          RadioListTile<String>(title: const Text('System'), subtitle: const Text('Follow device appearance'), value: 'system'),
          const Divider(height: 1),
          RadioListTile<String>(title: const Text('Light'), value: 'light'),
          const Divider(height: 1),
          RadioListTile<String>(title: const Text('Dark'), value: 'dark'),
        ]))),
        const SizedBox(height: 16),
        Text('Preview', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Theme(data: previewTheme, child: Builder(builder: (context) => Card(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gelye Sherane', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Management workspace preview'),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                Chip(label: const Text('Dashboard'), avatar: const Icon(Icons.dashboard_outlined, size: 18)),
                Chip(label: const Text('Orders'), avatar: const Icon(Icons.receipt_long_outlined, size: 18)),
              ]),
            ],
          )),
        ))),
        const SizedBox(height: 12),
        const Text('The existing quick theme toggle may override this selection until the next launch.'),
      ],
    );
  }
}
