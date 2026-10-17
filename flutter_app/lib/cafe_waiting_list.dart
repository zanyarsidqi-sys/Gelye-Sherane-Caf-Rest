import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cafe_finance_surface.dart';
import 'cafe_language.dart';
import 'cafe_operations_workspace.dart';
import 'cafe_request_id.dart';

const waitingStates = ['open', 'offered', 'accepted', 'arrived', 'seated', 'cancelled'];
String waitingLabel(String state) => switch (state) {
  'open' => 'Waiting', 'offered' => 'Table offered', 'accepted' => 'Offer accepted',
  'arrived' => 'Arrived', 'seated' => 'Seated', 'cancelled' => 'Left / cancelled',
  _ => 'Unknown',
};
bool waitingActive(Map<String,dynamic> row) => ['open','offered','accepted','arrived'].contains(row['status']);
List<String> waitingActions(String status, bool canSeat) => switch(status) {
  'open' => ['offered','cancelled'],
  'offered' => ['accepted','open','cancelled'],
  'accepted' => ['arrived','open','cancelled'],
  'arrived' => [if (canSeat) 'seated','cancelled'],
  _ => [],
};
String waitingActionLabel(String action) => switch(action) {
  'offered'=>'Offer table', 'accepted'=>'Accept offer', 'arrived'=>'Mark arrived',
  'seated'=>'Seat guests', 'open'=>'Return to queue', 'cancelled'=>'Mark left / cancel',
  _=>action,
};

class CafeWaitingList extends StatefulWidget {
  const CafeWaitingList({super.key, this.rpc});
  final CafeRpc? rpc;
  @override
  State<CafeWaitingList> createState() => _CafeWaitingListState();
}
class _CafeWaitingListState extends State<CafeWaitingList> {
  List<Map<String,dynamic>> _tasks = [], _tables = [];
  bool _loading = true, _busy = false, _canSeat = false, _history = false;
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
    setState(() { _loading = true; _error = null; _tasks = []; _tables = []; _canSeat = false; _loaded = null; });
    try {
      if (widget.rpc == null) throw StateError('Unavailable');
      final data = Map<String,dynamic>.from(await widget.rpc!('get_cafe_table_task_workspace', {'p_kind':'waiting'}));
      final tasks = cafeRows(data['tasks']), tables = cafeRows(data['tables']);
      for (final task in tasks) {
        if (task['id'] is! String || task['title'] is! String ||
            task['quantity'] is! int || task['version'] is! int ||
            !waitingStates.contains(task['status']) ||
            DateTime.tryParse('${task['created_at']}') == null) {
          throw const FormatException('Invalid waiting party');
        }
      }
      tasks.sort((a,b) => DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at'])));
      if (!mounted || request != _request) return;
      setState(() { _tasks = tasks; _tables = tables; _canSeat = data['can_seat'] == true; _loaded = DateTime.now().toUtc(); });
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => _error = 'Could not load the waiting list. Check Reservation Waiting List access and refresh.');
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
          ? 'Change rejected. The party or table may have changed, or access is missing. Refresh and review before trying again.'
          : 'Result not confirmed. Retry the same request to avoid creating a duplicate. New changes are blocked until this request is confirmed.';
      });
      if (rejected) await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final data = await showDialog<Map<String,dynamic>>(context: context,
      builder: (_) => const _WaitingPartyEditor());
    if (data == null || !mounted) return;
    _pending = {'p_request_id':newCafeRequestId(),'p_kind':'waiting','p_action':'create',
      'p_id':null,'p_version':null,'p_data':data};
    await _send();
  }

  Future<void> _action(Map<String,dynamic> row, String action) async {
    String? tableId;
    if (action == 'offered') {
      tableId = await showDialog<String>(context:context,builder:(ctx) => SimpleDialog(
        title: const CafeText('Offer table'),
        children: [
          const Padding(padding:EdgeInsets.all(16),child:CafeText('The server checks current availability, capacity, maintenance and upcoming reservations.')),
          for (final table in _tables.where((t) => t['status']=='available' &&
              t['active']!=true && t['blocked']!=true && t['seats'] is num && t['seats'] >= row['quantity']))
            SimpleDialogOption(onPressed:()=>Navigator.pop(ctx,table['id'] as String),
              child:Text('${table['name']} · ${table['area']} · ${table['seats']} seats')),
          TextButton(onPressed:()=>Navigator.pop(ctx),child:const CafeText('Cancel')),
        ],
      ));
      if (tableId == null || !mounted) return;
    }
    final confirmed = await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:CafeText(waitingActionLabel(action)),
      content:Text('${row['title']} · ${row['quantity']} guests\n${action=='seated' ? 'This creates an active table visit. It does not settle a bill.' : action=='cancelled' ? 'The party stays in history.' : 'Confirm this change to the waiting party.'}'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const CafeText('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const CafeText('Confirm')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    _pending = {'p_request_id':newCafeRequestId(),'p_kind':'waiting','p_action':action,
      'p_id':row['id'],'p_version':row['version'],
      'p_data':{if(action=='offered')'table_id':tableId}};
    await _send();
  }

  @override
  Widget build(BuildContext context) => CafeFinanceSurface(builder:(context) {
    final visible = _tasks.where((r) => (_history || waitingActive(r)) &&
      '${r['title']} ${r['details'] ?? ''} ${r['table_name'] ?? ''}'.toLowerCase().contains(_query.trim().toLowerCase())).toList();
    final disabled = _loading || _busy || _error != null || _pending != null;
    return Padding(padding:const EdgeInsets.all(16),child:Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const CafeText('Waiting List',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
        const CafeText('Waiting → Table offered → Offer accepted → Arrived → Seated. Oldest parties appear first.'),
        Wrap(spacing:8,runSpacing:8,children:[
          FilledButton(onPressed:disabled?null:_create,child:const CafeText('Add party')),
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
        TextField(decoration:const InputDecoration(label:CafeText('Search party, notes or table')),
          onChanged:(value)=>setState(()=>_query=value)),
        if (!_loading && _error == null) ...[
          CafeText('Last updated: ${cafeFinanceTimestamp(_loaded?.toIso8601String())} · Baghdad'),
          CafeText('${_tasks.where(waitingActive).length} active parties · ${visible.length} matching records'),
          if (visible.isEmpty) const CafeText('No matching waiting parties.'),
          for (final row in visible) Card(child:Padding(padding:const EdgeInsets.all(16),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('${row['title']} · ${row['quantity']} guests',style:const TextStyle(fontWeight:FontWeight.bold)),
              CafeText(waitingLabel(row['status'])),
              CafeText('Joined: ${cafeFinanceTimestamp(row['created_at'])} · Baghdad'),
              CafeText('Updated: ${cafeFinanceTimestamp(row['updated_at'])} · Baghdad'),
              if (row['table_name'] != null) Text('Table: ${row['table_name']}'),
              if ('${row['details'] ?? ''}'.isNotEmpty) Text('${row['details']}'),
              if (row['status']=='arrived' && !_canSeat)
                const CafeText('Table Session Management access is required to seat guests.'),
              Wrap(spacing:8,runSpacing:8,children:[
                for (final action in waitingActions(row['status'],_canSeat))
                  OutlinedButton(onPressed:disabled?null:()=>_action(row,action),
                    child:CafeText(waitingActionLabel(action))),
              ]),
            ]))),
        ],
      ]));
  });
}

class _WaitingPartyEditor extends StatefulWidget {
  const _WaitingPartyEditor();
  @override
  State<_WaitingPartyEditor> createState()=>_WaitingPartyEditorState();
}
class _WaitingPartyEditorState extends State<_WaitingPartyEditor> {
  final _form = GlobalKey<FormState>();
  final _name=TextEditingController(), _guests=TextEditingController(text:'2'), _notes=TextEditingController();
  @override
  void dispose() { _name.dispose(); _guests.dispose(); _notes.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context)=>AlertDialog(
    title:const CafeText('Add waiting party'),
    content:SizedBox(width:420,child:SingleChildScrollView(child:Form(key:_form,child:Column(
      mainAxisSize:MainAxisSize.min,children:[
        TextFormField(controller:_name,decoration:const InputDecoration(label:CafeText('Party name')),
          maxLength:120,validator:(v)=>v==null||v.trim().isEmpty?'Enter a party name':null),
        TextFormField(controller:_guests,decoration:const InputDecoration(label:CafeText('Guests')),
          keyboardType:TextInputType.number,validator:(v){
            final count=int.tryParse(v??''); return count==null||count<1||count>100?'Enter 1–100 guests':null;
          }),
        TextFormField(controller:_notes,decoration:const InputDecoration(label:CafeText('Notes / preferred area')),
          maxLength:1000,maxLines:3),
      ])))),
    actions:[
      TextButton(onPressed:()=>Navigator.pop(context),child:const CafeText('Cancel')),
      FilledButton(onPressed:(){
        if (_form.currentState!.validate()) {
          Navigator.pop(context,<String,dynamic>{
            'title':_name.text.trim(),'quantity':int.parse(_guests.text),'details':_notes.text.trim(),
          });
        }
      },child:const CafeText('Save party')),
    ],
  );
}
