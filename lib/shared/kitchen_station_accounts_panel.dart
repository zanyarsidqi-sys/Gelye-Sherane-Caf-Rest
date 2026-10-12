import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Kitchen-owned station POS account administration. Passwords are never read back.
/// The server RPC enforces authenticated supervisor, Kitchen edit and station checks.
class KitchenStationAccountsPanel extends StatefulWidget {
  const KitchenStationAccountsPanel({super.key});
  @override State<KitchenStationAccountsPanel> createState() => _KitchenStationAccountsPanelState();
}
class _KitchenStationAccountsPanelState extends State<KitchenStationAccountsPanel> {
  List<Map<String,dynamic>> _accounts = [];
  bool _loading = true, _saving = false;
  String? _error;
  @override void initState() { super.initState(); _reload(); }
  Future<void> _reload() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await Supabase.instance.client.rpc('gs_1245_kitchen_station_account_setup_directory') as List;
      if (!mounted) return;
      setState(() => _accounts = data.map((e) => Map<String,dynamic>.from(e as Map)).toList());
    } catch (_) {
      if (mounted) setState(() => _error = 'Station account directory unavailable or access denied.');
    } finally { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _configure(Map<String,dynamic> station) async {
    final username = TextEditingController(text: station['username']?.toString() ?? '');
    final password = TextEditingController();
    bool orderPrint = station['order_print'] != false;
    bool billPrint = station['bill_print'] == true;
    bool hide = true;
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, update) => AlertDialog(
        title: Text('Station POS credentials: ${station['station_name'] ?? station['station_key']}'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: username, autocorrect: false, decoration: const InputDecoration(labelText: 'Unique station username')),
          TextField(controller: password, obscureText: hide, autocorrect: false,
            decoration: InputDecoration(labelText: 'New password (12–128 characters)',
              suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                onPressed: () => update(() => hide = !hide)))),
          SwitchListTile(title: const Text('Allow order tickets'), value: orderPrint,
            onChanged: (v) => update(() => orderPrint = v)),
          SwitchListTile(title: const Text('Allow customer bill printing'), value: billPrint,
            onChanged: (v) => update(() => billPrint = v)),
          const Text('Saving replaces the station password and revokes existing device sessions. Employee login and MFA remain separate.'),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext,false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext,true), child: const Text('Save & revoke old sessions'))],
      )));
    final user = username.text.trim().toLowerCase();
    final pass = password.text;
    username.dispose(); password.dispose();
    if (accepted != true) return;
    if (!RegExp(r'^[a-z][a-z0-9_.-]{3,63}$').hasMatch(user) || pass.length < 12 || pass.length > 128) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid username and a new 12–128 character password.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.rpc('gs_1222_upsert_station_account', params: {
        'p_station_key': station['station_key'], 'p_username': user,
        'p_password': pass, 'p_order_print': orderPrint, 'p_bill_print': billPrint,
      });
      await _reload();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account change denied. Confirm station supervisor and Kitchen edit permissions.')));
    } finally { if (mounted) setState(() => _saving = false); }
  }
  @override Widget build(BuildContext context) => Column(children: [
    ListTile(title: const Text('Kitchen station POS accounts'),
      subtitle: const Text('Device credentials are separate from employee accounts. Changes revoke previous sessions.'),
      trailing: IconButton(tooltip: 'Refresh accounts', icon: const Icon(Icons.refresh), onPressed: _saving ? null : _reload)),
    if (_loading) const LinearProgressIndicator(),
    if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
    Expanded(child: ListView.builder(itemCount: _accounts.length, itemBuilder: (context,index) {
      final row = _accounts[index];
      return ListTile(title: Text(row['station_name']?.toString() ?? row['station_key']?.toString() ?? 'Station'),
        subtitle: Text('Username: ${row['username']} · Orders: ${row['order_print'] == true ? 'allowed' : 'blocked'} · Bills: ${row['bill_print'] == true ? 'allowed' : 'blocked'} · ${row['online'] == true ? 'online' : 'offline'}'),
        trailing: OutlinedButton(onPressed: _saving ? null : () => _configure(row), child: const Text('Reset / configure')));
    })),
    const Padding(padding: EdgeInsets.all(8), child: Text('New station not listed? Create it in Kitchen → Stations. First-time station account setup requires a provisioned station; the directory currently lists provisioned accounts only.')),
  ]);
}
