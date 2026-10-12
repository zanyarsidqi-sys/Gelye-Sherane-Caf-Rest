import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Device-local display preferences only. Never used for financial rules,
/// authorization, MFA, or backend pricing decisions.
class SettingsRulesPanel extends StatefulWidget {
  const SettingsRulesPanel({super.key});

  @override
  State<SettingsRulesPanel> createState() => _SettingsRulesPanelState();
}

class _SettingsRulesPanelState extends State<SettingsRulesPanel> {
  bool _loading = true;
  bool _compact = false;
  bool _confirmActions = true;
  bool _showHints = true;
  String _scope = '';

  String get _keyPrefix => 'gs_local_ui_${_scope}_';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _scope = uid;
      _compact = prefs.getBool('${_keyPrefix}compact') ?? false;
      _confirmActions = prefs.getBool('${_keyPrefix}confirm') ?? true;
      _showHints = prefs.getBool('${_keyPrefix}hints') ?? true;
      _loading = false;
    });
  }

  Future<void> _save(String key, bool value) async {
    if (_scope.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyPrefix$key', value);
  }

  Future<void> _reset() async {
    if (_scope.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove('${_keyPrefix}compact'),
      prefs.remove('${_keyPrefix}confirm'),
      prefs.remove('${_keyPrefix}hints'),
    ]);
    if (!mounted) return;
    setState(() {
      _compact = false;
      _confirmActions = true;
      _showHints = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local display preferences reset')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_scope.isEmpty) {
      return const Center(child: Text('Sign in to manage your device preferences.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Settings & Rules', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Personal display preferences for this employee on this device.'),
        const SizedBox(height: 16),
        Card(child: Column(children: [
          SwitchListTile(
            title: const Text('Compact layout preference'),
            subtitle: const Text('Saved for future compact-layout integration.'),
            value: _compact,
            onChanged: (value) { setState(() => _compact = value); _save('compact', value); },
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Confirm important actions'),
            subtitle: const Text('Preference only; mandatory server checks cannot be disabled.'),
            value: _confirmActions,
            onChanged: (value) { setState(() => _confirmActions = value); _save('confirm', value); },
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Show help hints'),
            subtitle: const Text('Saved for future contextual guidance.'),
            value: _showHints,
            onChanged: (value) { setState(() => _showHints = value); _save('hints', value); },
          ),
        ])),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reset my local preferences'),
        ),
        const SizedBox(height: 16),
        const Card(child: ListTile(
          leading: Icon(Icons.shield_outlined),
          title: Text('Business rules are server controlled'),
          subtitle: Text('Pricing, Tourism Mode, credit limits, employee permissions, MFA and financial approvals cannot be changed from these local settings.'),
        )),
      ],
    );
  }
}
