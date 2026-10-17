import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cafe_finance_surface.dart';
import 'cafe_language.dart';
import 'cafe_operations_workspace.dart';
import 'cafe_request_id.dart';

const maintenanceStates = ['open','in_progress','review','resolved','cancelled'];
String maintenanceLabel(String state) => switch(state) {
  'open'=>'Reported','in_progress'=>'In progress','review'=>'Awaiting review',
  'resolved'=>'Resolved','cancelled'=>'Cancelled',_=>'Unknown',
};
bool maintenanceActive(Map<String,dynamic> row) => ['open','in_progress','review'].contains(row['status']);
List<String> maintenanceActions(String status,bool canApprove) => switch(status) {
  'open'=>['in_progress',if(canApprove)'cancelled'],
  'in_progress'=>['review',if(canApprove)'cancelled'],
  'review'=>[if(canApprove)'resolved',if(canApprove)'cancelled'],
  _=>[],
};
String maintenanceActionLabel(String action)=>switch(action) {
  'in_progress'=>'Start work','review'=>'Request review','resolved'=>'Approve repair',
  'cancelled'=>'Cancel request',_=>action,
};

class CafeTableMaintenance extends StatefulWidget {
  const CafeTableMaintenance({super.key, this.rpc});
  final CafeRpc? rpc;
  @override
  State<CafeTableMaintenance> createState() => _CafeTableMaintenanceState();
}
class _CafeTableMaintenanceState extends State<CafeTableMaintenance> {
  List<Map<String,dynamic>> _tasks = [], _tables = [];
  bool _loading = true, _busy = false, _canApprove = false, _history = false;
  String _query = '';
  String? _error, _commandError;
  Map<String,dynamic>? _pending;
  int _request = 0;
  DateTime? _loaded;
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _request++; super.dispose(); }

  Future<void> _load() async {
    final request = ++_request;
    setState(() { _loading = true; _error = null; _tasks = []; _tables = []; _canApprove = false; _loaded = null; });
    try {
      if (widget.rpc == null) throw StateError('Unavailable');
      final data = Map<String,dynamic>.from(await widget.rpc!('get_cafe_table_task_workspace', {'p_kind':'maintenance'}));
      final tasks = cafeRows(data['tasks']), tables = cafeRows(data['tables']);
      for (final task in tasks) {
        if (task['id'] is! String || task['title'] is! String ||
            task['quantity'] is! int || task['version'] is! int ||
            !maintenanceStates.contains(task['status']) ||
            DateTime.tryParse('${task['created_at']}') == null) {
          throw const FormatException('Invalid maintenance request');
        }
      }
      tasks.sort((a,b) => DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at'])));
      if (!mounted || request != _request) return;
      setState(() { _tasks = tasks; _tables = tables; _canApprove = data['can_approve'] == true; _loaded = DateTime.now().toUtc(); });
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => _error = 'Could not load maintenance requests. Check Table Maintenance access and refresh.');
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_pending == null || _busy) return;
    setState(() { _busy = true; _commandError = null; });
    try {
      if (widget.rpc == null) throw StateError('Unavailable');
      await widget.rpc!('perform_cafe_table_task_command', _pending!);
      if (!mounted) return;
      setState(() { _pending = null; });
      await _load();
    } catch (error) {
      if (!mounted) return;
      final rejected = error is PostgrestException &&
          ['22023','42501','40001','23505','23514','23503','23502','P0001','P0002'].contains(error.code);
      setState(() {
        if (rejected) _pending = null;
        _commandError = rejected
          ? 'Change rejected. The request or table may have changed, or access is missing. Refresh and review before trying again.'
          : 'Result not confirmed. Retry the same request to avoid creating a duplicate. New changes are blocked until this request is confirmed.';
      });
      if (rejected) await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final data = await showDialog<Map<String,dynamic>>(context: context,
      builder: (_) => _MaintenanceEditor(tables:_tables));
    if (data == null || !mounted) return;
    _pending = {'p_request_id':newCafeRequestId(),'p_kind':'maintenance','p_action':'create',
      'p_id':null,'p_version':null,'p_data':data};
    await _send();
  }

  Future<void> _action(Map<String,dynamic> row, String action) async {
    final confirmed = await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:CafeText(maintenanceActionLabel(action)),
      content:Text('${row['title']}\n${action=='resolved' ? 'Confirm that the repair has been verified. Resolving this request does not seat guests or settle bills.' : 'Confirm this maintenance status change. The record remains in history.'}'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const CafeText('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const CafeText('Confirm')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    _pending = {'p_request_id':newCafeRequestId(),'p_kind':'maintenance','p_action':action,
      'p_id':row['id'],'p_version':row['version'],
      'p_data':<String,dynamic>{}};
    await _send();
  }

  @override
  Widget build(BuildContext context) => CafeFinanceSurface(builder:(context) {
    final visible = _tasks.where((r) => (_history || maintenanceActive(r)) &&
      '${r['title']} ${r['details'] ?? ''} ${r['table_name'] ?? ''}'.toLowerCase().contains(_query.trim().toLowerCase())).toList();
    final disabled = _loading || _busy || _error != null || _pending != null;
    return Padding(padding:const EdgeInsets.all(16),child:Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const CafeText('Table Maintenance',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
        const CafeText('Table repairs: Reported → In progress → Awaiting review → Resolved. An administrator verifies completion. Other equipment maintenance is not included here.'),
        Wrap(spacing:8,runSpacing:8,children:[
          FilledButton(onPressed:disabled?null:_create,child:const CafeText('Report problem')),
          OutlinedButton(onPressed:_loading||_busy?null:_load,child:const CafeText('Refresh')),
          ChoiceChip(label:const CafeText('Active'),selected:!_history,
            onSelected:(_)=>setState(()=>_history=false)),
          ChoiceChip(label:const CafeText('History'),selected:_history,
            onSelected:(_)=>setState(()=>_history=true)),
        ]),
        if (_pending != null && !_busy)
          OutlinedButton(onPressed:_send,child:const CafeText('Retry same request')),
        if (_commandError != null) CafeText(_commandError!),
        if (_error != null) CafeText(_error!),
        if (_loading || _busy) const LinearProgressIndicator(),
        TextField(decoration:const InputDecoration(label:CafeText('Search request, notes or table')),
          onChanged:(value)=>setState(()=>_query=value)),
        if (!_loading && _error == null) ...[
          CafeText('Last updated: ${cafeFinanceTimestamp(_loaded?.toIso8601String())} · Baghdad'),
          CafeText('${_tasks.where(maintenanceActive).length} open requests · ${visible.length} matching records'),
          if (visible.isEmpty) const CafeText('No matching maintenance requests.'),
          for (final row in visible) Card(child:Padding(padding:const EdgeInsets.all(16),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('${row['title']}',style:const TextStyle(fontWeight:FontWeight.bold)),
              CafeText(maintenanceLabel(row['status'])),
              CafeText('Reported: ${cafeFinanceTimestamp(row['created_at'])} · Baghdad'),
              CafeText('Updated: ${cafeFinanceTimestamp(row['updated_at'])} · Baghdad'),
              if (row['table_name'] != null) Text('Table: ${row['table_name']}'),
              if ('${row['details'] ?? ''}'.isNotEmpty) Text('${row['details']}'),
              if (row['status']=='review' && !_canApprove)
                const CafeText('Administrator approval is required to resolve this repair.'),
              Wrap(spacing:8,runSpacing:8,children:[
                for (final action in maintenanceActions(row['status'],_canApprove))
                  OutlinedButton(onPressed:disabled?null:()=>_action(row,action),
                    child:CafeText(maintenanceActionLabel(action))),
              ]),
            ]))),
        ],
      ]));
  });
}

class _MaintenanceEditor extends StatefulWidget {
  const _MaintenanceEditor({required this.tables});
  final List<Map<String,dynamic>> tables;
  @override
  State<_MaintenanceEditor> createState()=>_MaintenanceEditorState();
}
class _MaintenanceEditorState extends State<_MaintenanceEditor> {
  final _form=GlobalKey<FormState>();
  final _title=TextEditingController(),_notes=TextEditingController();
  String? _table;
  @override
  void dispose(){_title.dispose();_notes.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>AlertDialog(
    title:const CafeText('Report table problem'),
    content:SizedBox(width:420,child:SingleChildScrollView(child:Form(key:_form,child:Column(
      mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<String>(initialValue:_table,isExpanded:true,
          decoration:const InputDecoration(label:CafeText('Table')),
          items:[for(final table in widget.tables)DropdownMenuItem(value:table['id'] as String,
            child:Text('${table['name']} · ${table['area']}'))],
          onChanged:(value)=>setState(()=>_table=value),
          validator:(value)=>value==null?'Select a table':null),
        TextFormField(controller:_title,maxLength:120,
          decoration:const InputDecoration(label:CafeText('Problem')),
          validator:(value)=>value==null||value.trim().isEmpty?'Describe the problem':null),
        TextFormField(controller:_notes,maxLength:1000,maxLines:3,
          decoration:const InputDecoration(label:CafeText('Details'))),
        const CafeText('An open maintenance request blocks new seating and reservations for this table.'),
      ])))),
    actions:[
      TextButton(onPressed:()=>Navigator.pop(context),child:const CafeText('Cancel')),
      FilledButton(onPressed:(){
        if(_form.currentState!.validate()){
          Navigator.pop(context,<String,dynamic>{'title':_title.text.trim(),'details':_notes.text.trim(),
            'table_id':_table,'quantity':1});
        }
      },child:const CafeText('Save request')),
    ]);
}
