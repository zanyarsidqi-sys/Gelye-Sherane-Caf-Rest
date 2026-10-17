import 'package:flutter/material.dart';
import 'cafe_operations_workspace.dart';
import 'cafe_request_id.dart';
const cashWorkspaceCards = <String, Set<String>>{
'dashboard':{'Standing Cash','Cash Out — Owner','Expenses','Remaining Cash','Cash In','Pending Expenses','Expected vs Actual Cash','Financial Alerts','Cash Reconciliation'},
'payment_management':{'Standing Cash','Available Cash','Owner Cash Out','Expenses Management','Expenses','Costs & Expenses','Cash Over / Short','Cash Reconciliation','Approvals'},
};
class CafeCashWorkspace extends StatefulWidget {
 const CafeCashWorkspace({super.key,required this.section,required this.card,required this.title,this.rpc});
 final String section,card,title;
 final CafeRpc? rpc;
 @override State<CafeCashWorkspace> createState()=>_CafeCashWorkspaceState();
}
class _CafeCashWorkspaceState extends State<CafeCashWorkspace>{
 Map<String,dynamic>? _data;
 bool _busy=false,_loading=true;
 String? _error;
 String _filter='All';
 Future<dynamic> _rpc(String name,Map<String,dynamic> p) async {if(widget.rpc==null)throw StateError('Connection unavailable');return widget.rpc!(name,p);}
 @override void initState(){super.initState(); if(widget.card=='pending_expenses'||widget.card=='approvals')_filter='pending';_load();}
 Future<void> _load() async{
  setState(()=>_loading=true);
  try{final data=Map<String,dynamic>.from(await _rpc('get_cafe_cash_workspace',{'p_section':widget.section,'p_card':widget.card}));if(mounted)setState((){_data=data;_error=null;});}
  catch(_){if(mounted)setState(()=>_error='Could not load the cash journal. Check connection and assigned permission.');}
  finally{if(mounted)setState(()=>_loading=false);}
 }
 Future<void> _entry(String kind) async {
  final result=await showDialog<bool>(context:context,barrierDismissible:false,builder:(_)=>_CashEntry(kind:kind,rpc:_rpc));
  if(result==true&&mounted)await _load();
 }
 Future<void> _review(Map<String,dynamic> row,bool approve) async {
  final reason=TextEditingController();
  final form=GlobalKey<FormState>();
  final text=await showDialog<String>(context:context,builder:(context)=>AlertDialog(title:Text('${approve?'Approve':'Reject'} ${row['amount_iqd']} IQD'),content:Form(key:form,child:TextFormField(controller:reason,maxLength:500,decoration:const InputDecoration(labelText:'Review reason'),validator:(v)=>(v?.trim().length??0)<3?'Enter a reason':null)),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:(){if(form.currentState!.validate())Navigator.pop(context,reason.text.trim());},child:const Text('Confirm'))]));
  if(text==null||!mounted)return;
  setState(()=>_busy=true);
  try{await _rpc('review_cafe_cash_entry',{'p_id':row['id'],'p_approve':approve,'p_reason':text});await _load();}
  catch(_){if(mounted)setState(()=>_error='Review was not confirmed. Refresh to check its status. Approval requires sufficient recorded cash; owner withdrawals and approving your own request require an administrator.');}
  finally{if(mounted)setState(()=>_busy=false);}
 }
 String _time(dynamic value)=>DateTime.parse('$value').toUtc().add(const Duration(hours:3)).toString().substring(0,19);
 @override Widget build(BuildContext context){
  final caps=_data?['capabilities'] as Map? ?? {};
  final entries=cafeRows(_data?['entries']??[]).where((e)=>(_filter=='All'||e['status']==_filter)&&(!widget.card.contains('expense')||e['kind']=='expense')).toList();
  return Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text(widget.title,style:Theme.of(context).textTheme.headlineSmall),
   const Text('IQD · Baghdad time · Recorded cash is not a physical cash count. Record opening cash once through Cash in, with a clear reason.'),
   if(_data!=null)Text('Recorded cash balance: ${_data!['balance_iqd']} IQD',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:20)),
   if((_data?['balance_iqd'] as num? ??0)<0)const Text('Recorded cash is negative. Review refunds, opening cash and missing receipts.',style:TextStyle(color:Colors.red)),
   Wrap(spacing:8,children:[
    OutlinedButton.icon(onPressed:_busy||_loading?null:_load,icon:const Icon(Icons.refresh),label:const Text('Refresh')),
    for(final action in {'cash_in':'Cash in','cash_out':'Request owner withdrawal','expense':'Submit expense','count':'Reconcile cash'}.entries)
     if(caps[action.key]==true)FilledButton(onPressed:_busy||_loading||_error!=null?null:()=>_entry(action.key),child:Text(action.value)),
   ]),
   if(_loading)const LinearProgressIndicator(),
   if(_error!=null)Text(_error!,style:const TextStyle(color:Colors.red)),
   if(_data!=null)...[
    const SizedBox(height:12),
    const Text('Journal · Latest 500 entries',style:TextStyle(fontWeight:FontWeight.bold)),
    Wrap(spacing:8,children:[for(final f in ['All','pending','posted','rejected'])ChoiceChip(label:Text(f),selected:_filter==f,onSelected:(_)=>setState(()=>_filter=f))]),
    if(entries.isEmpty)const Text('No matching journal entries.'),
    for(final e in entries)Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Text('${e['kind']} · ${e['amount_iqd']} IQD · ${e['method']}',style:const TextStyle(fontWeight:FontWeight.bold)),
     Text('${e['reason']}'),Text('${e['status']} · ${_time(e['created_at'])}'),
     if(e['review_reason']!=null)Text('Review: ${e['review_reason']}'),
     if(caps['approve']==true&&e['status']=='pending')Wrap(spacing:8,children:[TextButton(onPressed:_busy?null:()=>_review(e,true),child:const Text('Approve')),TextButton(onPressed:_busy?null:()=>_review(e,false),child:const Text('Reject'))]),
    ]))),
    const SizedBox(height:20),
    const Text('Cash reconciliation · Latest 100 counts',style:TextStyle(fontWeight:FontWeight.bold)),
    const Text('A count preserves the expected balance and difference at that time. It never silently adjusts the ledger.'),
    for(final c in cafeRows(_data!['counts']))ListTile(title:Text('Counted ${c['counted_iqd']} · Expected ${c['expected_iqd']} IQD'),subtitle:Text('Difference: ${(c['counted_iqd'] as num)-(c['expected_iqd'] as num)} IQD · ${_time(c['created_at'])}\n${c['reason']}')),
   ],
  ])));
 }
}
class _CashEntry extends StatefulWidget{
 const _CashEntry({required this.kind,required this.rpc});
 final String kind;final CafeRpc rpc;
 @override State<_CashEntry> createState()=>_CashEntryState();
}
class _CashEntryState extends State<_CashEntry>{
 final _amount=TextEditingController(),_reason=TextEditingController();
 final _form=GlobalKey<FormState>();
 String _method='cash';bool _busy=false;String? _error;
 Map<String,dynamic>? _request;
 @override void dispose(){_amount.dispose();_reason.dispose();super.dispose();}
 Future<void> _save()async{
  if(_request==null){if(!_form.currentState!.validate())return;_request={'p_request_id':newCafeRequestId(),'p_kind':widget.kind,'p_amount':int.parse(_amount.text),'p_method':_method,'p_reason':_reason.text.trim()};}
  setState(()=>_busy=true);
  try{await widget.rpc('submit_cafe_cash_entry',_request!);if(mounted)Navigator.pop(context,true);}
  catch(_){if(mounted)setState(()=>_error='Could not confirm this entry. Retry preserves its identifier. Check the journal before creating a replacement.');}
  finally{if(mounted)setState(()=>_busy=false);}
 }
 @override Widget build(BuildContext context)=>PopScope(canPop:!_busy,child:AlertDialog(title:Text(widget.kind=='count'?'Physical cash count':widget.kind.replaceAll('_',' ')),content:SizedBox(width:420,child:Form(key:_form,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
  TextFormField(controller:_amount,enabled:_request==null,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Amount IQD'),validator:(v){final n=int.tryParse(v??'');return n==null||n<(widget.kind=='count'?0:1)||n>999999999999?'Enter a valid whole IQD amount':null;}),
  if(widget.kind=='expense')DropdownButtonFormField<String>(initialValue:_method,items:['cash','manual_card'].map((m)=>DropdownMenuItem(value:m,child:Text(m))).toList(),onChanged:_request!=null?null:(v)=>setState(()=>_method=v!),decoration:const InputDecoration(labelText:'Payment method')),
  TextFormField(controller:_reason,enabled:_request==null,maxLength:500,maxLines:3,decoration:const InputDecoration(labelText:'Reason / receipt reference'),validator:(v)=>(v?.trim().length??0)<3?'Enter a reason':null),
  Text(widget.kind=='cash_in'?'Only record cash actually received. Do not enter order payments here.':widget.kind=='count'?'Enter the cash physically counted. This does not change the recorded balance.':'This request remains pending until an authorized review posts it.'),
  if(_error!=null)Text(_error!,style:const TextStyle(color:Colors.red)),
 ])))),actions:[TextButton(onPressed:_busy?null:()=>Navigator.pop(context),child:const Text('Close')),FilledButton(onPressed:_busy?null:_save,child:Text(_request==null?'Save':'Retry same entry'))]));
}
