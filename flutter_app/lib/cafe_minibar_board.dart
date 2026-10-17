import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cafe_language.dart';
import 'cafe_finance_surface.dart';
import 'cafe_operations_workspace.dart';
import 'cafe_request_id.dart';

const minibarBoardCards = {'Minibar Live Board':'minibar_live_board','Nargile Orders':'nargile_orders'};
const stationDepartments = ['unclassified','kitchen','drinks','nargile'];

Map<String,dynamic> minibarBoardData(dynamic raw,String card) {
 if(raw is! Map) throw const FormatException('Invalid board');
 final data=Map<String,dynamic>.from(raw);
 if(data['rows'] is! List || data['stations'] is! List || data['total'] is! num ||
  data['total']<0 || data['unclassified_stations'] is! num || data['unclassified_stations']<0 ||
  DateTime.tryParse('${data['server_time']}')==null || data['can_classify'] is! bool) {
  throw const FormatException('Invalid board metadata');
 }
 for(final row in cafeRows(data['rows'])) {
  if(row['id'] is! String || row['order_id'] is! String || row['station_id'] is! String ||
   row['item_name'] is! String || row['quantity'] is! num || row['quantity']<=0 ||
   !const ['received','preparing','ready','served','cancelled'].contains(row['order_status']) ||
   !(row['department']=='nargile'||card=='minibar_live_board'&&row['department']=='drinks') ||
   DateTime.tryParse('${row['ordered_at']}')==null) { throw const FormatException('Invalid routed item'); }
 }
 for(final s in cafeRows(data['stations'])) {
  if(s['id'] is! String || s['name'] is! String || !stationDepartments.contains(s['department']) ||
   s['department_version'] is! num || s['department_version']<1 || s['classification_locked'] is! bool) {
   throw const FormatException('Invalid station');
  }
 }
 if(data['total']<(data['rows'] as List).length) throw const FormatException('Invalid coverage');
 return data;
}

class CafeMinibarBoard extends StatefulWidget {
 const CafeMinibarBoard({super.key,required this.title,this.rpc,this.autoRefresh=true});
 final String title; final CafeRpc? rpc; final bool autoRefresh;
 @override State<CafeMinibarBoard> createState()=>_CafeMinibarBoardState();
}
class _CafeMinibarBoardState extends State<CafeMinibarBoard> {
 Map<String,dynamic>? _data,_pending;
 final _search=TextEditingController();
 String _status='All',_station='All',_query='';
 bool _loading=true,_busy=false,_history=false;
 String? _error;
 Timer? _timer; int _revision=0;
 String get _card=>minibarBoardCards[widget.title]!;
 @override void initState(){super.initState();_load();_startTimer();}
 void _startTimer(){
  _timer?.cancel();
  if(widget.autoRefresh) { _timer=Timer.periodic(const Duration(seconds:20),(_){
   if(!_loading&&!_busy&&_pending==null) _load();
  }); }
 }
 @override void didUpdateWidget(CafeMinibarBoard oldWidget){
  super.didUpdateWidget(oldWidget);
  if(oldWidget.title!=widget.title||oldWidget.rpc!=widget.rpc){
   _pending=null;_busy=false;_history=false;_status='All';_station='All';_query='';_search.clear();_load();
  }
  if(oldWidget.autoRefresh!=widget.autoRefresh) _startTimer();
 }
 @override void dispose(){_revision++;_timer?.cancel();_search.dispose();super.dispose();}
 Future<void> _load()async{
  final revision=++_revision;final rpc=widget.rpc;
  setState((){_loading=true;_data=null;_error=null;});
  try{
   if(rpc==null) throw StateError('Connection unavailable');
   final data=minibarBoardData(await rpc('get_cafe_minibar_board',{'p_card':_card,'p_history':_history,'p_query':_query}),_card);
   if(mounted&&revision==_revision) { setState((){
    _data=data;
    if(!cafeRows(data['stations']).any((s)=>s['id']==_station && (s['department']=='nargile'||_card=='minibar_live_board'&&s['department']=='drinks'))) _station='All';
   }); }
  }catch(_){if(mounted&&revision==_revision) setState(()=>_error='Could not load the board. Check connection, card permission and the station classification migration.');}
  finally{if(mounted&&revision==_revision) setState(()=>_loading=false);}
 }
 Future<void> _classify(Map<String,dynamic> station)async{
  if(_busy||_loading||_pending!=null||_data?['can_classify']!=true) return;
  final revision=_revision;
  setState(()=>_busy=true);
  String selected=station['department'];
  final department=await showDialog<String>(context:context,builder:(context)=>StatefulBuilder(builder:(context,update)=>AlertDialog(
   title:Text('Classify ${station['name']}'),
   content:Column(mainAxisSize:MainAxisSize.min,children:[
    const CafeText('Choose the actual preparation department. Existing routed items will appear under this classification. Once used and classified, the department is locked.'),
    DropdownButtonFormField<String>(initialValue:selected,isExpanded:true,
     items:[for(final value in stationDepartments) DropdownMenuItem(value:value,child:Text(value))],
     onChanged:(value)=>update(()=>selected=value!)),
   ]),
   actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const CafeText('Cancel')),
    FilledButton(onPressed:selected==station['department']?null:()=>Navigator.pop(context,selected),child:const CafeText('Confirm classification'))],
  )));
  if(mounted) setState(()=>_busy=false);
  if(department==null||!mounted||revision!=_revision) return;
  _pending={'p_card':_card,'p_request_id':newCafeRequestId(),'p_station_id':station['id'],
   'p_version':station['department_version'],'p_department':department};
  await _send();
 }
 Future<void> _send()async{
  if(_busy||_pending==null||widget.rpc==null) return;
  final revision=_revision;final pending=Map<String,dynamic>.from(_pending!);
  setState(()=>_busy=true);
  try{
   await widget.rpc!('classify_cafe_station',pending);
   if(mounted&&revision==_revision){_pending=null;await _load();}
  }on PostgrestException catch(e){
   if(mounted&&revision==_revision) {
    if(const ['22023','40001','42501','23505'].contains(e.code)) {
     _pending=null;
     await _load();
     if(mounted) setState(()=>_error='Classification rejected. Refresh and check permissions, current version and whether this station has already been used.');
    }else{setState(()=>_error='Classification response was not confirmed. Retry the same request.');}
   }
  }catch(_){if(mounted&&revision==_revision) setState(()=>_error='Classification response was not confirmed. Retry the same request.');}
  finally{if(mounted) setState(()=>_busy=false);}
 }
 @override Widget build(BuildContext context){
  final all=cafeRows(_data?['rows']??[]);
  final stations=cafeRows(_data?['stations']??[]);
  final rows=all.where((r)=>(_status=='All'||r['order_status']==_status)&&(_station=='All'||r['station_id']==_station)).toList();
  final blocked=_loading||_busy||_pending!=null;
  return CafeFinanceSurface(builder:(context)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(
   crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    CafeText(widget.title,style:Theme.of(context).textTheme.headlineSmall),
    CafeText(widget.title=='Nargile Orders'?'Routed nargile items only.':'Routed drinks and nargile items only.'),
    const CafeText('Status belongs to the whole order, not an individual item. Printed confirmation does not mean prepared. No order changes are made here.'),
    const CafeText('Refreshes every 20 seconds while open. Oldest orders first. Items routed to multiple stations appear once per station.'),
    Wrap(spacing:8,runSpacing:8,children:[
     OutlinedButton.icon(onPressed:_busy||_loading?null:_load,icon:const Icon(Icons.refresh),label:const CafeText('Refresh')),
     ChoiceChip(label:const CafeText('Active'),selected:!_history,onSelected:blocked?null:(_){setState((){_history=false;_status='All';});_load();}),
     ChoiceChip(label:const CafeText('Recent history'),selected:_history,onSelected:blocked?null:(_){setState((){_history=true;_status='All';});_load();}),
    ]),
    if(_history) const CafeText('Served/cancelled orders created in the last 7 days. This is not the complete order history.'),
    TextField(controller:_search,enabled:!blocked,maxLength:120,
     decoration:const InputDecoration(label: CafeText('Search product, destination, station or order')),
     onSubmitted:(value){_query=value.trim();_load();}),
    Align(alignment:AlignmentDirectional.centerStart,child:TextButton(onPressed:blocked?null:(){_query=_search.text.trim();_load();},child:const CafeText('Search'))),
    if(_loading) const LinearProgressIndicator(),
    if(_error!=null) Text(_error!,style:const TextStyle(color:Colors.red)),
    if(_pending!=null) FilledButton(onPressed:_busy?null:_send,child:const CafeText('Retry same classification')),
    if(_data!=null&&!_loading)...[
     CafeText('Updated ${cafeFinanceTimestamp(_data!['server_time'])} · Baghdad'),
     CafeText('${rows.length} shown from ${all.length} loaded routed items; ${_data!['total']} match the server search. Limit 500. Narrow the search if truncated.'),
     if(_data!['unclassified_stations']>0) CafeText('${_data!['unclassified_stations']} station(s) are unclassified and excluded. Ask an administrator to classify stations.'),
     Wrap(spacing:8,runSpacing:8,children:[for(final status in ['All',...(_history?['served','cancelled']:['received','preparing','ready'])])
      ChoiceChip(label:Text(status),selected:_status==status,onSelected:(_)=>setState(()=>_status=status))]),
     DropdownButtonFormField<String>(key:ValueKey('board-station-$_station'),initialValue:_station,isExpanded:true,
      decoration:const InputDecoration(label:CafeText('Station filter')),
      items:[const DropdownMenuItem(value:'All',child:CafeText('All stations')),
       for(final station in stations.where((s)=>s['department']=='nargile'||_card=='minibar_live_board'&&s['department']=='drinks'))
        DropdownMenuItem(value:station['id'] as String,child:Text(station['name']))],
      onChanged:(value)=>setState(()=>_station=value!)),
     if(rows.isEmpty) const Padding(padding:EdgeInsets.all(20),child:CafeText('No matching routed items.')),
     for(final row in rows) Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       CafeText('${row['quantity']} × ${row['item_name']}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
       CafeText('${row['destination']} · ${row['station_name']} · ${row['department']}'),
       CafeText('Order status: ${row['order_status']}'),
       if(row['order_status']=='cancelled') const CafeText('CANCELLED — DO NOT PREPARE',style:TextStyle(color:Colors.red,fontWeight:FontWeight.bold)),
       SelectableText('Order ${row['order_id']}'),
       CafeText('Ordered: ${cafeFinanceTimestamp(row['ordered_at'])} · Baghdad'),
       CafeText(row['printed_at']==null?'Paper ticket not confirmed':'Paper confirmed: ${cafeFinanceTimestamp(row['printed_at'])}'),
       if('${row['notes']??''}'.isNotEmpty) CafeText('Order notes: ${row['notes']}'),
      ]))),
     if(_data!['can_classify']==true) ExpansionTile(title:const CafeText('Station classification'),children:[
      const CafeText('Up to 500 stations. This assigns departments only; product routing and printing stay in their existing workflows.'),
      for(final station in stations) ListTile(
       title:Text(station['name']),subtitle:Text('${station['department']}${station['classification_locked']==true?' · Locked after use':''}'),
       trailing:TextButton(onPressed:blocked||_error!=null||station['classification_locked']==true?null:()=>_classify(station),child:const CafeText('Classify'))),
     ]),
    ],
   ]))));
 }
}
