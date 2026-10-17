
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cafe_finance_surface.dart';
import 'cafe_language.dart';
import 'cafe_operations_workspace.dart';
import 'cafe_request_id.dart';
import 'workspace_reporting.dart';

List<String> cafeFeedbackActions(String state,bool admin)=>switch(state){
 'open'=>['in_review',if(admin)'dismissed'],
 'in_review'=>['resolved',if(admin)'dismissed'],
 'resolved'||'dismissed'=>[if(admin)'open'],
 _=>[],
};
String cafePeopleAction(String action)=>switch(action){
 'in_review'=>'Start review','resolved'=>'Resolve feedback','dismissed'=>'Dismiss feedback',
 'open'=>'Reopen feedback','clock_in'=>'Clock in','clock_out'=>'Clock out',_=>action,
};
String _date(DateTime value)=>value.toIso8601String().substring(0,10);
String _time(dynamic value){
 final parsed=DateTime.tryParse('$value');
 return parsed==null?'Not recorded':parsed.toUtc().add(const Duration(hours:3)).toIso8601String().substring(0,16).replaceAll('T',' ');
}
Map<String,dynamic> cafePeopleData(dynamic raw,String kind){
 if(raw is! Map || raw['rows'] is! List || raw['events'] is! List ||
   raw['total_count'] is! int || raw['truncated'] is! bool || DateTime.tryParse('${raw['server_time']}')==null){
  throw const FormatException('Invalid workspace');
 }
 for(final row in raw['rows']){
  if(row is! Map || row['id'] is! String || row['version'] is! int)throw const FormatException('Invalid record');
  if(kind=='feedback'){
   if(row['title'] is! String || !const {'complaint','suggestion','compliment'}.contains(row['category']) ||
     !const {'open','in_review','resolved','dismissed'}.contains(row['status']) ||
     DateTime.tryParse('${row['created_at']}')==null ||
     (row['rating']!=null && (row['rating'] is! int || row['rating']<1 || row['rating']>5))) {
    throw const FormatException('Invalid feedback');
   }
  }else if(DateTime.tryParse('${row['clocked_in_at']}')==null || row['period_seconds'] is! int ||
    row['period_seconds']<0 || (row['clocked_out_at']!=null&&DateTime.tryParse('${row['clocked_out_at']}')==null)){
   throw const FormatException('Invalid attendance');
  }
 }
 final active=raw['active'];
 if(active!=null && (active is! Map || active['id'] is! String || active['version'] is! int ||
   DateTime.tryParse('${active['clocked_in_at']}')==null))throw const FormatException('Invalid current attendance');
 return Map<String,dynamic>.from(raw);
}

class CafePeopleWorkspace extends StatefulWidget{
 const CafePeopleWorkspace({super.key,required this.kind,this.rpc}):assert(kind=='feedback'||kind=='attendance');
 final String kind;
 final CafeRpc? rpc;
 @override State<CafePeopleWorkspace> createState()=>_CafePeopleWorkspaceState();
}
class _CafePeopleWorkspaceState extends State<CafePeopleWorkspace>{
 Map<String,dynamic>? _data,_pending;
 String? _error,_commandError;
 bool _loading=true,_busy=false;
 String _status='All',_category='All',_query='';
 late DateTime _from,_to;
 int _request=0;
 bool get _feedback=>widget.kind=='feedback';
 @override void initState(){
  super.initState();_to=baghdadCalendarDate(DateTime.now());_from=_feedback?_to.subtract(const Duration(days:29)):_to;_load();
 }
 @override void dispose(){_request++;super.dispose();}
 Future<void> _load()async{
  final request=++_request;
  setState((){_loading=true;_error=null;_data=null;});
  try{
   if(widget.rpc==null)throw StateError('Unavailable');
   final data=cafePeopleData(await widget.rpc!('get_cafe_people_workspace',
     {'p_kind':widget.kind,'p_from':_date(_from),'p_to':_date(_to)}),widget.kind);
   if(mounted&&request==_request)setState(()=>_data=data);
  }catch(_){if(mounted&&request==_request)setState(()=>_error='Could not load this workspace. Check your connection, card access and database update, then refresh.');}
  finally{if(mounted&&request==_request)setState(()=>_loading=false);}
 }
 Future<void> _range()async{
  final choice=await showDateRangePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime(2100),
   initialDateRange:DateTimeRange(start:_from,end:_to));
  if(choice==null||!mounted)return;
  if(choice.end.difference(choice.start).inDays>30){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:CafeText('Choose no more than 31 days.')));return;
  }
  setState((){_from=choice.start;_to=choice.end;});await _load();
 }
 Future<void> _send()async{
  if(_pending==null||_busy)return;
  setState((){_busy=true;_commandError=null;});
  try{
   if(widget.rpc==null)throw StateError('Unavailable');
   await widget.rpc!('perform_cafe_people_command',_pending!);
   if(!mounted)return;
   _pending=null;await _load();
  }catch(error){
   if(!mounted)return;
   final rejected=error is PostgrestException &&
    const {'22023','22P02','42501','40001','23505','23514','23503','23502','P0001','P0002'}.contains(error.code);
   setState((){
    if(rejected)_pending=null;
    _commandError=rejected?'Change rejected. Refresh and review the current record and access.'
     :'Result not confirmed. Retry the same request before making another change.';
   });
   if(rejected)await _load();
  }finally{if(mounted)setState(()=>_busy=false);}
 }
 void _prepare(String action,Map<String,dynamic>? row,Map<String,dynamic> values){
  _pending={'p_request_id':newCafeRequestId(),'p_kind':widget.kind,'p_action':action,
    'p_id':row?['id'],'p_version':row?['version'],'p_data':values};
 }
 Future<void> _create()async{
  final values=await showDialog<Map<String,dynamic>>(context:context,builder:(_)=>const _FeedbackEditor());
  if(values==null||!mounted)return;
  _prepare('create',null,values);await _send();
 }
 Future<void> _action(String action,Map<String,dynamic>? row)async{
  final needNote=const {'resolved','dismissed','open'}.contains(action);
  final values=await showDialog<Map<String,dynamic>>(context:context,
    builder:(_)=>_PeopleConfirmation(action:action,title:row?['title'] as String?,needNote:needNote));
  if(values==null||!mounted)return;
  _prepare(action,row,values);await _send();
 }
 Future<void> _history(Map<String,dynamic> row)async{
  final events=cafeRows(_data?['events']).where((e)=>e['entity_id']==row['id']).toList();
  await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
   title:const CafeText('Record history'),
   content:SizedBox(width:480,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,
    crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     const CafeText('From the latest 100 events for the loaded records. Older events remain in the audit database.'),
     if(events.isEmpty)const CafeText('No events in this loaded window.'),
     for(final event in events)Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Text(
       '${cafePeopleAction('${event['action']}')} · ${_time(event['created_at'])} (Baghdad)\n'
       '${event['current'] is Map ? (event['current']['resolution']??'') : ''}')),
    ]))),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const CafeText('Close'))],
  ));
 }
 @override Widget build(BuildContext context)=>CafeFinanceSurface(builder:(context){
  final rows=cafeRows(_data?['rows']);
  final visible=rows.where((r){
   final state=_feedback?r['status']:(r['clocked_out_at']==null?'Open':'Closed');
   return (_status=='All'||_status==state)&&(!_feedback||_category=='All'||_category==r['category'])&&
    '${r['title']??''} ${r['details']??''} ${r['customer_name']??''} ${r['employee_name']??''}'
      .toLowerCase().contains(_query.trim().toLowerCase());
  }).toList();
  final disabled=_loading||_busy||_error!=null||_pending!=null;
  final active=_data?['active'] is Map?Map<String,dynamic>.from(_data!['active']):null;
  final ratings=visible.map((r)=>r['rating']).whereType<int>().toList();
  final seconds=_feedback?0:visible.fold<int>(0,(sum,r)=>sum+(r['period_seconds'] as int));
  return Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   CafeText(_feedback?'Customer Feedback':'Employee Attendance',style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
   CafeText(_feedback?'Staff-recorded customer feedback. QR surveys and product ratings are not included here.'
    :'Recorded clock sessions, not scheduled shifts, breaks or payroll. Staff see their own records; administrators see all.'),
   Wrap(spacing:8,runSpacing:8,children:[
    if(_feedback)FilledButton(onPressed:disabled?null:_create,child:const CafeText('Record feedback')),
    if(!_feedback)FilledButton(onPressed:disabled?null:()=>_action(active==null?'clock_in':'clock_out',active),
      child:CafeText(active==null?'Clock in':'Clock out')),
    OutlinedButton(onPressed:_loading||_busy?null:_load,child:const CafeText('Refresh')),
    OutlinedButton(onPressed:_busy?null:_range,child:const CafeText('Choose dates')),
   ]),
   Text('${_date(_from)} — ${_date(_to)} · Baghdad dates'),
   if(_loading)const LinearProgressIndicator(),
   if(_error!=null)Text(_error!),
   if(_commandError!=null)Text(_commandError!),
   if(_pending!=null)OutlinedButton(onPressed:_busy?null:_send,child:const CafeText('Retry same request')),
   if(_data!=null)...[
    Text('Snapshot: ${_time(_data!['server_time'])} (Baghdad)'),
    if(!_feedback)Text(active==null?'You are clocked out.':'Your open session started ${_time(active['clocked_in_at'])} (Baghdad).'),
    if(_data!['truncated']==true)const CafeText('Showing the newest 500 records. Narrow the dates for a complete list.'),
    Text('${visible.length} matching loaded records · ${_data!['total_count']} records in selected dates'),
    if(_feedback)Text(ratings.isEmpty?'No ratings in the matching records.':
      'Average of ${ratings.length} recorded ratings: ${(ratings.reduce((a,b)=>a+b)/ratings.length).toStringAsFixed(1)} / 5'),
    if(!_feedback)Text('Matching recorded time within selected dates: ${seconds~/3600}h ${(seconds%3600)~/60}m. Open sessions measured at snapshot.'),
    TextField(onChanged:(v)=>setState(()=>_query=v),decoration:InputDecoration(
      labelText:_feedback?'Search feedback or customer':'Search employee',prefixIcon:const Icon(Icons.search))),
    Wrap(spacing:8,children:[
     for(final state in (_feedback?['All','open','in_review','resolved','dismissed']:['All','Open','Closed']))
      ChoiceChip(label:CafeText(state.replaceAll('_',' ')),selected:_status==state,onSelected:(_)=>setState(()=>_status=state)),
    ]),
    if(_feedback)Wrap(spacing:8,children:[
     for(final category in ['All','complaint','suggestion','compliment'])
      ChoiceChip(label:CafeText(category=='All'?'All categories':category),selected:_category==category,onSelected:(_)=>setState(()=>_category=category)),
    ]),
    if(visible.isEmpty)const CafeText('No matching records.'),
    for(final row in visible)Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     Text(_feedback?row['title'] as String:'${row['employee_name']??'Employee'}',
      style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
     if(_feedback)...[
      Text('${row['category']} · ${row['status'].toString().replaceAll('_',' ')} · ${row['rating']==null?'Unrated':'${row['rating']} / 5'}'),
      if('${row['customer_name']??''}'.isNotEmpty)Text('Customer: ${row['customer_name']}'),
      Text('${row['details']??''}'),
      Text('Recorded: ${_time(row['created_at'])} (Baghdad)'),
      if('${row['resolution']??''}'.isNotEmpty)Text('Review note: ${row['resolution']}'),
      Wrap(spacing:8,children:[
       for(final action in cafeFeedbackActions(row['status'] as String,_data!['can_admin']==true))
        OutlinedButton(onPressed:disabled?null:()=>_action(action,row),child:CafeText(cafePeopleAction(action))),
      ]),
     ]else...[
      Text('In: ${_time(row['clocked_in_at'])} (Baghdad)'),
      Text(row['clocked_out_at']==null?'Open session':'Out: ${_time(row['clocked_out_at'])} (Baghdad)'),
      Text('Selected-period time: ${(row['period_seconds'] as int)~/3600}h ${((row['period_seconds'] as int)%3600)~/60}m'),
     ],
     Align(alignment:AlignmentDirectional.centerStart,child:TextButton(onPressed:()=>_history(row),child:const CafeText('History'))),
    ]))),
   ],
  ]));
 });
}
class _FeedbackEditor extends StatefulWidget{
 const _FeedbackEditor();
 @override State<_FeedbackEditor> createState()=>_FeedbackEditorState();
}
class _FeedbackEditorState extends State<_FeedbackEditor>{
 final _form=GlobalKey<FormState>();
 final _title=TextEditingController(),_details=TextEditingController(),_name=TextEditingController();
 String _category='complaint';int? _rating;
 @override void dispose(){_title.dispose();_details.dispose();_name.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>AlertDialog(
  title:const CafeText('Record feedback'),
  content:SizedBox(width:480,child:SingleChildScrollView(child:Form(key:_form,child:Column(mainAxisSize:MainAxisSize.min,children:[
   TextFormField(controller:_title,decoration:const InputDecoration(labelText:'Subject'),maxLength:120,
    validator:(v)=>(v??'').trim().isEmpty?'Enter a subject':null),
   TextFormField(controller:_details,decoration:const InputDecoration(labelText:'Feedback details'),maxLength:2000,maxLines:3),
   TextFormField(controller:_name,decoration:const InputDecoration(labelText:'Customer name (optional)'),maxLength:120),
   DropdownButtonFormField<String>(initialValue:_category,decoration:const InputDecoration(labelText:'Category'),
    items:const ['complaint','suggestion','compliment'].map((v)=>DropdownMenuItem(value:v,child:CafeText(v))).toList(),
    onChanged:(v)=>setState(()=>_category=v!)),
   DropdownButtonFormField<int>(initialValue:0,decoration:const InputDecoration(labelText:'Customer rating (optional)'),
    items:List.generate(6,(v)=>DropdownMenuItem(value:v,child:Text(v==0?'Not provided':'$v / 5'))),
    onChanged:(v)=>setState(()=>_rating=v==0?null:v)),
  ])))),
  actions:[
   TextButton(onPressed:()=>Navigator.pop(context),child:const CafeText('Cancel')),
   FilledButton(onPressed:(){if(_form.currentState!.validate())Navigator.pop(context,{'title':_title.text.trim(),
    'details':_details.text.trim(),'customer_name':_name.text.trim(),'category':_category,'rating':_rating});},
    child:const CafeText('Save feedback')),
  ]);
}
class _PeopleConfirmation extends StatefulWidget{
 const _PeopleConfirmation({required this.action,this.title,required this.needNote});
 final String action;final String? title;final bool needNote;
 @override State<_PeopleConfirmation> createState()=>_PeopleConfirmationState();
}
class _PeopleConfirmationState extends State<_PeopleConfirmation>{
 final _form=GlobalKey<FormState>();final _note=TextEditingController();
 @override void dispose(){_note.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>AlertDialog(
  title:CafeText(cafePeopleAction(widget.action)),
  content:SizedBox(width:420,child:SingleChildScrollView(child:Form(key:_form,child:Column(mainAxisSize:MainAxisSize.min,children:[
   if(widget.title!=null)Text(widget.title!),
   CafeText(widget.action.startsWith('clock_')?'Record your attendance using the server time?':'Confirm this review change. The previous record remains in the audit history.'),
   if(widget.needNote)TextFormField(controller:_note,decoration:const InputDecoration(labelText:'Review note'),
    maxLength:1000,maxLines:3,validator:(v)=>(v??'').trim().length<3?'Enter at least 3 characters':null),
  ])))),
  actions:[
   TextButton(onPressed:()=>Navigator.pop(context),child:const CafeText('Cancel')),
   FilledButton(onPressed:(){if(_form.currentState!.validate())Navigator.pop(context,
     widget.needNote?{'resolution':_note.text.trim()}:<String,dynamic>{});},child:const CafeText('Confirm')),
  ]);
}
