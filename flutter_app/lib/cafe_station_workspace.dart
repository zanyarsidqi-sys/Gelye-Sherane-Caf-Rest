import 'cafe_language.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cafe_operations_workspace.dart';

class CafeStationWorkspace extends StatefulWidget {
  const CafeStationWorkspace({super.key, this.rpc, this.devicePreferenceKey});
  final CafeRpc? rpc;
  final String? devicePreferenceKey;
  @override
  State<CafeStationWorkspace> createState()=>_CafeStationWorkspaceState();
}
class _CafeStationWorkspaceState extends State<CafeStationWorkspace> {
  List<Map<String,dynamic>> _stations=[], _tickets=[];
  String? _station, _error;
  bool _busy=false, _manage=false;
  int _unrouted=0;
  Timer? _timer;
  @override
  void initState(){super.initState();_load();_timer=Timer.periodic(const Duration(seconds:20),(_){if(!_busy)_load();});}
  @override
  void dispose(){_timer?.cancel();super.dispose();}
  Future<void> _load() async {
    if(_busy)return;
    setState((){_busy=true;_error=null;});
    try {
      if(widget.rpc==null)throw StateError('Connection unavailable');
      final data=await widget.rpc!('get_cafe_print_stations',{});
      final stations=(data['stations'] as List).map((e)=>Map<String,dynamic>.from(e)).toList();
      String? saved=_station;
      if(saved==null && widget.devicePreferenceKey!=null) {
        saved=(await SharedPreferences.getInstance()).getString('cafe.station.${widget.devicePreferenceKey}');
      }
      final selected=stations.any((s)=>s['id']==saved)?saved:(stations.isEmpty?null:stations.first['id'] as String);
      final queue=selected==null?{'tickets':[],'unrouted_products':0}:await widget.rpc!('get_cafe_station_queue',{'p_station_id':selected});
      if(mounted)setState((){_stations=stations;_station=selected;_manage=data['can_manage']==true;_tickets=(queue['tickets'] as List).map((e)=>Map<String,dynamic>.from(e)).toList();_unrouted=(queue['unrouted_products'] as num).toInt();});
    } catch(_){if(mounted)setState(()=>_error='Could not load stations. Check connection and station permissions.');}
    finally {if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _select(String id) async {
    setState(()=>_station=id);
    if(widget.devicePreferenceKey!=null) {
      try { await (await SharedPreferences.getInstance()).setString('cafe.station.${widget.devicePreferenceKey}',id); }
      catch(_) { if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:CafeText('Station selected for this session. Device could not remember the choice.'))); }
    }
    await _load();
  }
  Future<void> _edit([Map<String,dynamic>? station]) async {
    final name=TextEditingController(text:station?['name']);
    bool active=station?['active']??true, saving=false;
    String? error;
    await showDialog<void>(context:context,barrierDismissible:false,builder:(context)=>StatefulBuilder(builder:(context,update)=>PopScope(canPop:!saving,child:AlertDialog(
      title:Text(station==null?'Add print station':'Edit print station'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,enabled:!saving,maxLength:60,decoration:const InputDecoration(label: CafeText('Station name'))),SwitchListTile(title:const CafeText('Active'),value:active,onChanged:saving?null:(v)=>update(()=>active=v)),if(error!=null)Text(error!)]),
      actions:[TextButton(onPressed:saving?null:()=>Navigator.pop(context),child:const CafeText('Close')),FilledButton(onPressed:saving?null:() async {
        if(name.text.trim().isEmpty)return;
        update((){saving=true;error=null;});
        try {await widget.rpc!('save_cafe_print_station',{'p_id':station?['id'],'p_name':name.text.trim(),'p_active':active});if(context.mounted)Navigator.pop(context);}
        catch(_){if(context.mounted)update((){saving=false;error='Save failed. Names must be unique. Remove a station from available products before disabling it.';});}
      },child:const CafeText('Save station'))]))));
    // The closing dialog may still be animating; controller lives with its field.
    await _load();
  }
  String _ticketText(Map<String,dynamic> ticket) => '${ticket['event']=='cancelled'||ticket['status']=='cancelled'?'CANCELLED — DO NOT PREPARE\n':''}${ticket['station']}\n${ticket['destination']}\nOrder ${ticket['order_id']}\n${ticket['created_at']}\n\n${(ticket['items'] as List).map((i)=>"${i['quantity']} x ${i['name']}").join('\n')}\n\n${ticket['notes']}\n';
  Future<void> _print(Map<String,dynamic> ticket) async {
    setState(()=>_busy=true);
    try {
      final text=_ticketText(ticket);
      if(!kIsWeb && defaultTargetPlatform==TargetPlatform.android) {
        await const MethodChannel('cafe.sunmi/printer').invokeMethod<void>('printTicket',{'text':text});
      } else {
        final doc=pw.Document();doc.addPage(pw.MultiPage(pageFormat:PdfPageFormat.roll57,build:(_)=>[pw.Text(text,style:const pw.TextStyle(fontSize:11))]));
        await Printing.layoutPdf(name:'station-ticket.pdf',onLayout:(_)=>doc.save());
      }
    } catch(_) {if(mounted)setState(()=>_error='Printing was not confirmed. Check paper and printer connection. Check for an existing printout before retrying.');}
    finally {if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _confirm(Map<String,dynamic> ticket) async {
    final yes=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const CafeText('Confirm paper ticket'),content:const CafeText('Has this ticket printed correctly and been received by this station?'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const CafeText('Keep in queue')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const CafeText('Yes, received'))]));
    if(yes!=true||!mounted)return;
    setState(()=>_busy=true);
    try {await widget.rpc!('confirm_cafe_station_tickets',{'p_ids':(ticket['items'] as List).map((i)=>i['ticket_id']).toList()});}
    catch(_){if(mounted)setState(()=>_error='Confirmation failed. Refresh before retrying.');return;}
    finally{if(mounted)setState(()=>_busy=false);}
    await _load();
  }
  @override
  Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    CafeText('Print stations',style:Theme.of(context).textTheme.titleLarge),
    const CafeText('Select the station used by this device. Print tickets, then confirm receipt after checking the paper. Refreshes every 20 seconds.'),
    Wrap(spacing:8,children:[if(_manage)TextButton.icon(onPressed:_busy?null:()=>_edit(),icon:const Icon(Icons.add),label:const CafeText('Add station')),TextButton.icon(onPressed:_busy?null:_load,icon:const Icon(Icons.refresh),label:const CafeText('Refresh')),TextButton.icon(onPressed:_busy||_station==null?null:()=>_print({'station':_stations.firstWhere((s)=>s['id']==_station)['name'],'destination':'PRINTER TEST','order_id':'TEST — not an order','created_at':DateTime.now().toUtc().toIso8601String(),'notes':'Printer test only','items':[]}),icon:const Icon(Icons.print_outlined),label:const CafeText('Test printer'))]),
    if(_busy)const LinearProgressIndicator(),
    if(_error!=null)Text(_error!,style:const TextStyle(color:Colors.red)),
    if(_unrouted>0)CafeText('$_unrouted available products have no print station. Edit those products to choose destinations.'),
    Wrap(spacing:8,children:[for(final s in _stations)ChoiceChip(label:CafeText('${s['name']}${s['active']==true?'':' (disabled)'}'),selected:_station==s['id'],onSelected:_busy?null:(_)=>_select(s['id']))]),
    if(_manage && _station!=null)TextButton(onPressed:_busy?null:()=>_edit(_stations.firstWhere((s)=>s['id']==_station)),child:const CafeText('Edit selected station')),
    if(_tickets.isEmpty && !_busy && _error==null)const Padding(padding:EdgeInsets.all(20),child:CafeText('No pending tickets for this station.')),
    for(final ticket in _tickets)Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[SelectableText(_ticketText(ticket)),Wrap(spacing:8,children:[FilledButton.icon(onPressed:_busy?null:()=>_print(ticket),icon:const Icon(Icons.print),label:const CafeText('Print ticket')),OutlinedButton(onPressed:_busy?null:()=>_confirm(ticket),child:const CafeText('Confirm printed'))])]))),
  ])));
}
