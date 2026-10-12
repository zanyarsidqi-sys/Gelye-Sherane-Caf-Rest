import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Station names and activation; new station device provisioning remains
/// managed through the existing station/printer setup RPC.
class StationManagementPanel extends StatefulWidget {
  const StationManagementPanel({super.key});
  @override State<StationManagementPanel> createState() => _StationManagementPanelState();
}
class _StationManagementPanelState extends State<StationManagementPanel> {
  List<Map<String,dynamic>> stations = [];
  bool loading = true;
  bool _creatingStation = false;
  String? error;
  @override void initState() { super.initState(); reload(); }
  Future<void> reload() async {
    setState(() {loading=true;error=null;});
    try {
      final rows=await Supabase.instance.client.rpc('gs_1217_station_directory') as List;
      if (!mounted) return;
      setState(() => stations=rows.map((e)=>Map<String,dynamic>.from(e as Map)).toList());
    } catch (_) { if (mounted) setState(()=>error='Unable to load stations. Check your permissions.'); }
    finally { if (mounted) setState(()=>loading=false); }
  }
  Future<void> addStation() async {
    if (_creatingStation) return;
    final key = TextEditingController();
    final name = TextEditingController();
    final target = TextEditingController();
    String method = 'printer';
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: const Text('Add preparation station'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: key, decoration: const InputDecoration(
                labelText: 'Station key', hintText: 'barista_2')),
              TextField(controller: name, decoration: const InputDecoration(
                labelText: 'Station display name')),
              DropdownButtonFormField<String>(
                value: method,
                decoration: const InputDecoration(labelText: 'Online target type'),
                items: const [
                  DropdownMenuItem(value: 'printer', child: Text('Printer')),
                  DropdownMenuItem(value: 'pos', child: Text('POS device')),
                ],
                onChanged: (value) { if (value != null) update(() => method = value); },
              ),
              TextField(controller: target,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: method == 'printer' ? 'Existing printer ID' : 'Existing POS device ID',
                  helperText: 'Configure the device first; a new station cannot print without a target.',
                )),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Create station')),
          ],
        ),
      ),
    );
    final stationKey = key.text.trim();
    final displayName = name.text.trim();
    final targetId = int.tryParse(target.text.trim());
    key.dispose(); name.dispose(); target.dispose();
    if (approved != true) return;
    if (!RegExp(r'^[a-z][a-z0-9_]{1,39}$').hasMatch(stationKey) ||
        displayName.isEmpty || displayName.length > 100 ||
        targetId == null || targetId <= 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valid station key, name and existing device ID required.')));
      return;
    }
    if (!mounted) return;
    setState(() => _creatingStation = true);
    try {
      await Supabase.instance.client.rpc('gs_1242_create_station', params: {
        'p_key': stationKey,
        'p_name': displayName,
        'p_method': method,
        'p_target_id': targetId,
      });
      await reload();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Station creation denied. Verify supervisor permissions and target device.')));
    } finally {
      if (mounted) setState(() => _creatingStation = false);
    }
  }

  Future<void> edit(Map<String,dynamic> station) async {
    final name=TextEditingController(text:station['display_name']?.toString()??'');
    bool enabled=station['enabled']==true;
    final save=await showDialog<bool>(context:context,builder:(context)=>StatefulBuilder(builder:(context,refresh)=>AlertDialog(
      title:Text('Edit ${station['station_key']}'),content:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:name,decoration:const InputDecoration(labelText:'Station name')),
      SwitchListTile(title:const Text('Active'),value:enabled,onChanged:(v)=>refresh(()=>enabled=v)),
      const Text('Device changes use Station Devices. Deactivation is blocked while pending tickets exist.'),
      ]),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),
      FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Save'))])));
    if (save!=true) {name.dispose();return;}
    try {
      await Supabase.instance.client.rpc('gs_1217_save_station',params:{'p_key':station['station_key'],'p_name':name.text.trim(),'p_enabled':enabled});
      await reload();
    } catch (_) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Station update denied or pending tickets exist.'))); }
    name.dispose();
  }
  @override Widget build(BuildContext context) => Column(children:[
    ListTile(title:const Text('Preparation stations'),subtitle:const Text('Station routing requires a configured POS/printer. Employee visibility is enforced by station assignments.'),trailing:Wrap(spacing:4,children:[IconButton(tooltip:'Refresh stations',onPressed:reload,icon:const Icon(Icons.refresh)),FilledButton.icon(onPressed:_creatingStation ? null : addStation,icon:const Icon(Icons.add),label:const Text('Add Station'))])),
    // All station setup stays inside Section 05 Kitchen; these links select
    // sibling Kitchen tabs, never navigate to Workplace or another section.
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(
          onPressed: () => DefaultTabController.of(context).animateTo(4),
          icon: const Icon(Icons.alt_route), label: const Text('Assign products')),
        OutlinedButton.icon(
          onPressed: () => DefaultTabController.of(context).animateTo(5),
          icon: const Icon(Icons.people_outline), label: const Text('Station employees')),
        OutlinedButton.icon(
          onPressed: () => DefaultTabController.of(context).animateTo(6),
          icon: const Icon(Icons.print_outlined), label: const Text('Printers & POS devices')),
        OutlinedButton.icon(
          onPressed: () => DefaultTabController.of(context).animateTo(12),
          icon: const Icon(Icons.lock_person_outlined), label: const Text('Station POS accounts')),
        OutlinedButton.icon(
          onPressed: () => DefaultTabController.of(context).animateTo(11),
          icon: const Icon(Icons.fact_check_outlined), label: const Text('Print review')),
      ]),
    ),
    const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Align(alignment: Alignment.centerLeft, child: Text(
        'Kitchen station setup: add a station here, then assign products, employees and its printer/POS device using the Kitchen tabs above.')),
    ),
    if(error!=null) Text(error!),
    if(loading) const LinearProgressIndicator(),
    Expanded(child:ListView.builder(itemCount:stations.length,itemBuilder:(context,i){final s=stations[i];return ListTile(
      title:Text(s['display_name']?.toString()??''),subtitle:Text('${s['station_key']} · ${s['product_count']} products'),
      trailing:Row(mainAxisSize:MainAxisSize.min,children:[Text(s['enabled']==true?'Active':'Inactive'),IconButton(icon:const Icon(Icons.edit),onPressed:()=>edit(s))]));}))
  ]);
}
