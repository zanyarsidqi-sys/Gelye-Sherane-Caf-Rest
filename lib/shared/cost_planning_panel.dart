import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Device-only monthly planning estimates, NOT accounting records.
/// Scoped to the current Supabase user and selected calendar month.
class CostPlanningPanel extends StatefulWidget {
  const CostPlanningPanel({super.key});

  @override
  State<CostPlanningPanel> createState() => _CostPlanningPanelState();
}

class _CostPlanningPanelState extends State<CostPlanningPanel> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{
    'Salaries': TextEditingController(),
    'Food and transport': TextEditingController(),
    'Supplies': TextEditingController(),
    'Utilities': TextEditingController(),
    'Repairs': TextEditingController(),
    'Other': TextEditingController(),
  };
  late DateTime _month;
  bool _busy = true;
  bool _dirty = false;

  String get _storageKey {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'no-user';
    return 'cafe_cost_plan_v1_${userId}_${_month.year}_${_month.month}';
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);
      final values = saved == null ? <String, dynamic>{} : jsonDecode(saved) as Map<String, dynamic>;
      if (!mounted) return;
      for (final entry in _controllers.entries) {
        entry.value.text = values[entry.key]?.toString() ?? '';
      }
      setState(() => _dirty = false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read saved estimate on this device.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final values = <String, int>{
        for (final entry in _controllers.entries)
          entry.key: int.tryParse(entry.value.text.trim()) ?? 0,
      };
      final saved = await prefs.setString(_storageKey, jsonEncode(values));
      if (!saved) throw StateError('Storage rejected the save');
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estimate saved on this device only.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the estimate.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeMonth(int offset) async {
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved estimate'),
          content: const Text('Switch months and discard unsaved changes?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _month = DateTime(_month.year, _month.month + offset));
    await _load();
  }

  int _amount(String key) => int.tryParse(_controllers[key]!.text.trim()) ?? 0;

  String? _validate(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return null;
    final amount = int.tryParse(input);
    if (amount == null || amount < 0) return 'Enter a non-negative whole IQD amount';
    return null;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _controllers.keys.fold<int>(0, (sum, key) => sum + _amount(key));
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Monthly Cost Planner', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Planning estimates only. Saved on this device for the signed-in employee, not in Supabase or accounting.'),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(onPressed: _busy ? null : () => _changeMonth(-1), icon: const Icon(Icons.chevron_left), tooltip: 'Previous month'),
              Expanded(child: Center(child: Text('${_month.year}-${_month.month.toString().padLeft(2, '0')}', style: Theme.of(context).textTheme.titleMedium))),
              IconButton(onPressed: _busy ? null : () => _changeMonth(1), icon: const Icon(Icons.chevron_right), tooltip: 'Next month'),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          for (final entry in _controllers.entries) ...[
            TextFormField(
              controller: entry.value,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: entry.key, suffixText: 'IQD', border: const OutlineInputBorder()),
              validator: _validate,
              onChanged: (_) => setState(() => _dirty = true),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Estimated monthly total'),
                const SizedBox(height: 6),
                Text('$total IQD', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(_dirty ? 'Unsaved changes' : 'Saved values loaded or blank month'),
              ]),
            ),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save estimate on this device'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : () {
              for (final controller in _controllers.values) {
                controller.clear();
              }
              setState(() => _dirty = true);
            },
            icon: const Icon(Icons.restart_alt),
            label: const Text('Clear fields (save to confirm)'),
          ),
        ],
      ),
    );
  }
}
