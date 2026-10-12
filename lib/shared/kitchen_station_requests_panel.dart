import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-scoped requests from every station assigned to the signed-in employee.
class KitchenStationRequestsPanel extends StatefulWidget {
  const KitchenStationRequestsPanel({super.key});
  @override
  State<KitchenStationRequestsPanel> createState() => _KitchenStationRequestsPanelState();
}
class _KitchenStationRequestsPanelState extends State<KitchenStationRequestsPanel> {
  bool busy = false;
  String? error;
  String selected = 'All stations';
  List<Map<String, dynamic>> requests = [];
  List<Map<String, dynamic>> alerts = [];
  @override
  void initState() { super.initState(); refresh(); }
  Future<void> refresh() async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      final results = await Future.wait([
        Supabase.instance.client.rpc('gs_my_service_station_requests_1219',params:{'p_limit':200}),
        Supabase.instance.client.rpc('gs_my_service_station_alerts_1219',params:{'p_limit':200}),
      ]);
      if (!mounted) return;
      setState(() {
        requests = (results[0] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
        alerts = (results[1] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
      });
    } catch (_) { if (mounted) setState(()=>error='Could not load authorized station requests.'); }
    finally { if (mounted) setState(()=>busy=false); }
  }
  Future<void> acknowledge(String id) async {
    try {
      await Supabase.instance.client.rpc('gs_seen_service_station_alert_1220',params:{'p_request_id':id});
      await refresh();
    } catch (_) { if (mounted) setState(()=>error='Unable to acknowledge this alert.'); }
  }
  @override
  Widget build(BuildContext context) {
    final stations = <String>{'All stations',...requests.map((r)=>r['station_key']?.toString()??'Supervisor queue')}.toList()..sort();
    final current = stations.contains(selected)?selected:'All stations';
    final visible = requests.where((r)=>current=='All stations'||(r['station_key']?.toString()??'Supervisor queue')==current).toList();
    final unread = alerts.where((a)=>a['seen_at']==null).length;
    return ListView(padding:const EdgeInsets.all(16),children:[
      Text('Station customer requests',style:Theme.of(context).textTheme.titleLarge),
      Text('$unread unread station alerts · ${requests.length} authorized requests'),
      const SizedBox(height:12),
      Wrap(spacing:8,children:[
        DropdownButton<String>(value:current,items:stations.map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),onChanged:(v)=>setState(()=>selected=v??'All stations')),
        OutlinedButton.icon(onPressed:busy?null:refresh,icon:const Icon(Icons.refresh),label:const Text('Refresh')),
      ]),
      if (busy) const LinearProgressIndicator(),
      if (error!=null) Text(error!,style:const TextStyle(color:Colors.red)),
      if (!busy && visible.isEmpty) const ListTile(title:Text('No requests for these stations')),
      for (final r in visible) Card(child:ListTile(
        leading:const Icon(Icons.notifications_active_outlined),
        title:Text('${r['call_type']?.toString().replaceAll('_',' ')??'Request'} · Table ${r['table_id']??'-'}'),
        subtitle:Text('${r['station_key']??'Supervisor queue'} · ${r['status']??'new'}\n${r['note']??''}'),
        isThreeLine:true,
        trailing: alerts.any((a)=>a['request_id'].toString()==r['request_id'].toString() && a['seen_at']==null) ? IconButton(tooltip:'Mark notification seen',icon:const Icon(Icons.done),onPressed:()=>acknowledge(r['request_id'].toString())) : const Icon(Icons.check_circle_outline),
      )),
      const SizedBox(height:8),
      const Text('Price questions route to the Cashier/Pricing station when configured. Pricing requests do not change prices or bills.'),
    ]);
  }
}
