
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cafe_finance_surface.dart';
import 'cafe_language.dart';
import 'cafe_operations_workspace.dart';
import 'cafe_request_id.dart';

const cafeTaskSources = {
  'maintenance': 'Table Maintenance', 'chairs': 'Extra Chairs Requests',
  'waiting': 'Reservation Waiting List', 'group': 'Join / Split Tables',
};
const _states = {
  'maintenance': {'open','in_progress','review','resolved','cancelled'},
  'chairs': {'open','approved','delivered','cancelled'},
  'waiting': {'open','offered','accepted','arrived','seated','cancelled'},
  'group': {'open','separated'},
};
bool cafeTaskPending(Map<String,dynamic> row) =>
  const {'open','in_progress','review','approved','offered','accepted','arrived'}.contains(row['status']);

List<Map<String,dynamic>> cafeTaskRows(dynamic data,String kind) {
  if(data is! Map || data['tasks'] is! List || data['staff'] is! List) {
    throw const FormatException('Invalid task source');
  }
  final rows=<Map<String,dynamic>>[];
  for(final value in data['tasks']) {
    if(value is! Map || value['id'] is! String || value['title'] is! String ||
      value['kind']!=kind || !(_states[kind]?.contains(value['status'])??false) ||
      value['version'] is! int || DateTime.tryParse('${value['created_at']}')==null) {
      throw const FormatException('Invalid task');
    }
    rows.add(Map<String,dynamic>.from(value));
  }
  return rows;
}
class CafeStaffTasks extends StatefulWidget {
  const CafeStaffTasks({super.key,required this.kinds,this.rpc,this.pendingOnly=false});
  final Set<String> kinds;
  final CafeRpc? rpc;
  final bool pendingOnly;
  @override
  State<CafeStaffTasks> createState()=>_CafeStaffTasksState();
}
class _CafeStaffTasksState extends State<CafeStaffTasks> {
  final _data=<String,Map<String,dynamic>>{};
  final _failed=<String>{};
  final _search=TextEditingController();
  String _source='All',_scope='Pending',_assignment='All';
  bool _loading=false,_busy=false;
  int _request=0;
  String? _commandError;
  Map<String,dynamic>? _pending;
  @override
  void initState(){super.initState();_scope=widget.pendingOnly?'Pending':'All';_load();}
  @override
  void didUpdateWidget(CafeStaffTasks oldWidget){
    super.didUpdateWidget(oldWidget);
    if(!setEquals(oldWidget.kinds,widget.kinds)||oldWidget.pendingOnly!=widget.pendingOnly){
      _source='All';_scope=widget.pendingOnly?'Pending':'All';_assignment='All';_search.clear();_load();
    }
  }
  @override
  void dispose(){_request++;_search.dispose();super.dispose();}
  Set<String> get _kinds=>widget.kinds.intersection(cafeTaskSources.keys.toSet());
  Future<void> _load() async {
    final request=++_request;
    setState((){_loading=true;_data.clear();_failed.clear();});
    final results=await Future.wait(_kinds.map((kind)async{
      try{
        if(widget.rpc==null)throw StateError('Unavailable');
        final raw=await widget.rpc!('get_cafe_table_task_workspace',{'p_kind':kind});
        cafeTaskRows(raw,kind);
        return (kind:kind,data:Map<String,dynamic>.from(raw as Map));
      }catch(_){return (kind:kind,data:null);}
    }));
    if(!mounted||request!=_request)return;
    setState((){
      for(final result in results){
        if(result.data==null){_failed.add(result.kind);}
        else{_data[result.kind]=result.data!;}
      }
      _loading=false;
    });
  }
  Future<void> _assign(Map<String,dynamic> row) async {
    final kind=row['kind'] as String;
    final staff=cafeRows(_data[kind]?['staff']).where((s)=>s['id'] is String && s['name'] is String).toList();
    String? selected=staff.any((s)=>s['id']==row['assigned_to'])?row['assigned_to'] as String?:null;
    final choice=await showDialog<String>(context:context,builder:(ctx)=>
      StatefulBuilder(builder:(ctx,change)=>AlertDialog(
        title:const CafeText('Assign employee'),
        content:SizedBox(width:360,child:Column(mainAxisSize:MainAxisSize.min,children:[
          Text(row['title'] as String),
          DropdownButtonFormField<String>(initialValue:selected,isExpanded:true,
            decoration:const InputDecoration(labelText:'Employee'),
            items:staff.map((s)=>DropdownMenuItem(value:s['id'] as String,
              child:Text(s['name'] as String,overflow:TextOverflow.ellipsis))).toList(),
            onChanged:(value)=>change(()=>selected=value)),
          if(staff.isEmpty)const CafeText('No staff available for assignment.'),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx),child:const CafeText('Cancel')),
          FilledButton(onPressed:selected==null?null:()=>Navigator.pop(ctx,selected),
            child:const CafeText('Confirm assignment')),
        ])));
    if(choice==null||!mounted)return;
    if(!_kinds.contains(kind)||_data[kind]?['can_approve']!=true)return;
    _pending={'p_request_id':newCafeRequestId(),'p_kind':kind,'p_action':'assign',
      'p_id':row['id'],'p_version':row['version'],'p_data':{'assigned_to':choice}};
    await _send();
  }
  Future<void> _send() async {
    if(_pending==null||_busy||!_kinds.contains(_pending!['p_kind']))return;
    setState((){_busy=true;_commandError=null;});
    try{
      if(widget.rpc==null)throw StateError('Unavailable');
      await widget.rpc!('perform_cafe_table_task_command',_pending!);
      if(!mounted)return;
      _pending=null;await _load();
    }catch(error){
      if(!mounted)return;
      final rejected=error is PostgrestException &&
        const {'22023','42501','40001','23505','23514','23503','23502','P0001','P0002'}.contains(error.code);
      setState((){
        if(rejected)_pending=null;
        _commandError=rejected
          ?'Assignment rejected. Refresh and review the current task and permissions.'
          :'Assignment result not confirmed. Retry the same request before making another assignment.';
      });
      if(rejected)await _load();
    }finally{if(mounted)setState(()=>_busy=false);}
  }
  @override
  Widget build(BuildContext context)=>CafeFinanceSurface(builder:(context){
    final rows=_data.entries.expand((e)=>cafeTaskRows(e.value,e.key)).toList()
      ..sort((a,b){
        final date=DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at']));
        return date!=0?date:'${a['id']}'.compareTo('${b['id']}');
      });
    final visible=rows.where((r)=>
      (_source=='All'||r['kind']==_source)&&
      (_scope=='All'||(_scope=='Pending'?cafeTaskPending(r):!cafeTaskPending(r)))&&
      (_assignment=='All'||(_assignment=='Unassigned'?r['assigned_to']==null:r['assigned_to']!=null))&&
      '${r['title']} ${r['details']??''} ${r['table_name']??''} ${r['other_name']??''} ${r['assignee']??''}'
        .toLowerCase().contains(_search.text.trim().toLowerCase())).toList();
    final disabled=_loading||_busy||_pending!=null;
    return Padding(padding:const EdgeInsets.all(16),child:Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        CafeText(widget.pendingOnly?'Pending Staff Tasks':'Tasks',
          style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
        const CafeText('Table-service tasks from your authorized workflows. Oldest first. General staff tasks and shifts are not included. Manage task status in the original workflow.'),
        const SizedBox(height:12),
        Wrap(spacing:8,runSpacing:8,children:[
          OutlinedButton(onPressed:_loading||_busy?null:_load,child:const CafeText('Refresh')),
          if(!_loading&&_kinds.isNotEmpty)Chip(label:Text('${_data.length}/${_kinds.length} sources loaded')),
        ]),
        if(_kinds.isEmpty)const CafeText('No table-task source access has been assigned.'),
        if(_loading)const LinearProgressIndicator(),
        for(final kind in _failed)Text('${cafeTaskSources[kind]} unavailable. Refresh to retry; its tasks are excluded.'),
        if(_commandError!=null)Text(_commandError!),
        if(_pending!=null&&_kinds.contains(_pending!['p_kind']))
          OutlinedButton(onPressed:_busy?null:_send,child:const CafeText('Retry same assignment')),
        TextField(controller:_search,onChanged:(_)=>setState((){}),
          decoration:const InputDecoration(labelText:'Search task, table or employee',prefixIcon:Icon(Icons.search))),
        Wrap(spacing:8,children:[
          ChoiceChip(label:const CafeText('All sources'),selected:_source=='All',onSelected:(_)=>setState(()=>_source='All')),
          for(final kind in _kinds)ChoiceChip(label:CafeText(cafeTaskSources[kind]!),
            selected:_source==kind,onSelected:(_)=>setState(()=>_source=kind)),
        ]),
        if(!widget.pendingOnly)Wrap(spacing:8,children:[
          for(final scope in ['All','Pending','History'])
            ChoiceChip(label:CafeText(scope),selected:_scope==scope,onSelected:(_)=>setState(()=>_scope=scope)),
        ]),
        Wrap(spacing:8,children:[
          for(final assignment in ['All','Assigned','Unassigned'])
            ChoiceChip(label:CafeText(assignment=='All'?'Any assignment':assignment),
              selected:_assignment==assignment,onSelected:(_)=>setState(()=>_assignment=assignment)),
        ]),
        if(!_loading&&_data.isNotEmpty)...[
          Text('${visible.length} matching tasks${_failed.isEmpty?'':' • Incomplete sources'}'),
          if(visible.isEmpty)const CafeText('No matching tasks in loaded sources.'),
        ],
        for(final row in visible)Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Text(row['title'] as String,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
            Text('${cafeTaskSources[row['kind']]} • ${row['status'].toString().replaceAll('_',' ')}'),
            Text('Table: ${row['table_name']??'Not assigned'}${row['other_name']==null?'':' → ${row['other_name']}'}'),
            Text('Employee: ${row['assignee']??(row['assigned_to']==null?'Unassigned':'Name unavailable')}'),
            Text('Created (Baghdad): ${DateTime.parse(row['created_at']).toUtc().add(const Duration(hours:3)).toIso8601String().substring(0,16).replaceAll('T',' ')}'),
            if('${row['details']??''}'.isNotEmpty)Text('${row['details']}'),
            if(cafeTaskPending(row)&&_data[row['kind']]?['can_approve']==true)
              Align(alignment:AlignmentDirectional.centerStart,child:TextButton(
                onPressed:disabled?null:()=>_assign(row),child:const CafeText('Assign employee'))),
          ]))),
      ]));
  });
}
