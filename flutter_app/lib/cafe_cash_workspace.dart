import 'cafe_language.dart';
import 'cafe_finance_surface.dart';
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
 String _filter='All',_query='';
 DateTime? _loadedAt;
 int _loadRevision=0;
 Future<dynamic> _rpc(String name,Map<String,dynamic> p) async {if(widget.rpc==null)throw StateError('Connection unavailable');return widget.rpc!(name,p);}
 @override void initState(){super.initState(); if(widget.card=='pending_expenses'||widget.card=='approvals')_filter='pending';_load();}
 @override void didUpdateWidget(CafeCashWorkspace oldWidget){
  super.didUpdateWidget(oldWidget);
  if(oldWidget.section!=widget.section||oldWidget.card!=widget.card){
   _filter=widget.card=='pending_expenses'||widget.card=='approvals'?'pending':'All';
   _query='';_load();
  }
 }
 @override void dispose(){_loadRevision++;super.dispose();}
 Future<void> _load() async{
  final revision=++_loadRevision;
  setState((){_loading=true;_data=null;_loadedAt=null;_error=null;});
  try{
   final data=Map<String,dynamic>.from(await _rpc('get_cafe_cash_workspace',{'p_section':widget.section,'p_card':widget.card}));
   if(mounted&&revision==_loadRevision)setState((){_data=data;_loadedAt=DateTime.now().toUtc();});
  }catch(_){if(mounted&&revision==_loadRevision)setState(()=>_error='Could not load the cash journal. Check connection and assigned permission.');}
  finally{if(mounted&&revision==_loadRevision)setState(()=>_loading=false);}
 }
 Future<void> _entry(String kind) async {
  final result=await showDialog<bool>(context:context,barrierDismissible:false,builder:(_)=>_CashEntry(kind:kind,rpc:_rpc));
  if(result==true&&mounted)await _load();
 }
 Future<void> _review(Map<String,dynamic> row,bool approve) async {
  final reason=TextEditingController();
  final form=GlobalKey<FormState>();
  final text=await showDialog<String>(context:context,builder:(context)=>AlertDialog(title:CafeText('${approve?'Approve':'Reject'} ${row['amount_iqd']} IQD'),content:Form(key:form,child:TextFormField(controller:reason,maxLength:500,decoration:const InputDecoration(label: CafeText('Review reason')),validator:(v)=>(v?.trim().length??0)<3?'Enter a reason':null)),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const CafeText('Cancel')),FilledButton(onPressed:(){if(form.currentState!.validate())Navigator.pop(context,reason.text.trim());},child:const CafeText('Confirm'))]));
  if(text==null||!mounted)return;
  setState(()=>_busy=true);
  try{await _rpc('review_cafe_cash_entry',{'p_id':row['id'],'p_approve':approve,'p_reason':text});await _load();}
  catch(_){if(mounted)setState(()=>_error='Review was not confirmed. Refresh to check its status. Approval requires sufficient recorded cash; owner withdrawals and approving your own request require an administrator.');}
  finally{if(mounted)setState(()=>_busy=false);}
 }
 String _time(dynamic value)=>cafeFinanceTimestamp(value);
 @override Widget build(BuildContext context){
  final caps=_data?['capabilities'] as Map? ?? {};
  final kind=cafeCashEntryKind(widget.card);
  final entries=cafeRows(_data?['entries']??[]).where((e)=>
   (_filter=='All'||e['status']==_filter)&&(kind==null||e['kind']==kind)&&
   '${e['reason']} ${e['review_reason']??''} ${e['amount_iqd']} ${e['method']}'
     .toLowerCase().contains(_query.trim().toLowerCase())).toList();
  return CafeFinanceSurface(builder:(context)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   CafeText(widget.title,style:Theme.of(context).textTheme.headlineSmall),
   const CafeText('IQD · Baghdad time · Recorded cash is not a physical cash count. Record opening cash once through Cash in, with a clear reason.'),
   if(_data!=null&&!_loading&&_error==null)CafeText('Recorded cash balance: ${_data!['balance_iqd']} IQD',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:20)),
   if(!_loading&&_error==null&&(_data?['balance_iqd'] as num? ??0)<0)const CafeText('Recorded cash is negative. Review refunds, opening cash and missing receipts.',style:TextStyle(color:Colors.red)),
   Wrap(spacing:8,children:[
    OutlinedButton.icon(onPressed:_busy||_loading?null:_load,icon:const Icon(Icons.refresh),label:const CafeText('Refresh')),
    for(final action in {'cash_in':'Cash in','cash_out':'Request owner withdrawal','expense':'Submit expense','count':'Reconcile cash'}.entries)
     if(caps[action.key]==true)FilledButton(onPressed:_busy||_loading||_error!=null?null:()=>_entry(action.key),child:Text(action.value)),
   ]),
   if(_loading)const LinearProgressIndicator(),
   if(_error!=null)Text(_error!,style:const TextStyle(color:Colors.red)),
   if(_data!=null&&!_loading&&_error==null)...[
    if(_loadedAt!=null)CafeText('Last updated: ${_time(_loadedAt)} · Baghdad'),
    const SizedBox(height:12),
    const CafeText('Journal · Latest 500 entries',style:TextStyle(fontWeight:FontWeight.bold)),
    if(kind!=null)CafeText(kind=='cash_out'?'Owner withdrawals only':kind=='cash_in'?'Cash in entries only':'Expense entries only'),
    TextField(key:ValueKey('cash-search-${widget.section}-${widget.card}'),
     decoration:const InputDecoration(label: CafeText('Search reason, amount or method'),prefixIcon:Icon(Icons.search)),
     onChanged:(value)=>setState(()=>_query=value)),
    CafeText('${entries.length} matching journal entries'),
    const CafeText('Filters apply to the loaded journal entries. The recorded cash balance is not recalculated from this list.'),
    Wrap(spacing:8,children:[for(final f in ['All','pending','posted','rejected'])ChoiceChip(label:Text(f),selected:_filter==f,onSelected:(_)=>setState(()=>_filter=f))]),
    if(entries.isEmpty)const CafeText('No matching journal entries.'),
    for(final e in entries)Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     CafeText('${e['kind']} · ${e['amount_iqd']} IQD · ${e['method']}',style:const TextStyle(fontWeight:FontWeight.bold)),
     CafeText('${e['reason']}'),CafeText('${e['status']} · ${_time(e['created_at'])}'),
     if(e['review_reason']!=null)CafeText('Review: ${e['review_reason']}'),
     if(caps['approve']==true&&e['status']=='pending'&&!_loading&&_error==null)Wrap(spacing:8,children:[TextButton(onPressed:_busy?null:()=>_review(e,true),child:const CafeText('Approve')),TextButton(onPressed:_busy?null:()=>_review(e,false),child:const CafeText('Reject'))]),
    ]))),
    const SizedBox(height:20),
    const CafeText('Cash reconciliation · Latest 100 counts',style:TextStyle(fontWeight:FontWeight.bold)),
    const CafeText('A count preserves the expected balance and difference at that time. It never silently adjusts the ledger.'),
    for(final c in cafeRows(_data!['counts']))ListTile(title:CafeText('Counted ${c['counted_iqd']} · Expected ${c['expected_iqd']} IQD'),subtitle:CafeText('Difference: ${(c['counted_iqd'] as num)-(c['expected_iqd'] as num)} IQD · ${_time(c['created_at'])}\n${c['reason']}')),
   ],
  ]))));
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
  TextFormField(controller:_amount,enabled:_request==null,keyboardType:TextInputType.number,decoration:const InputDecoration(label: CafeText('Amount IQD')),validator:(v){final n=int.tryParse(v??'');return n==null||n<(widget.kind=='count'?0:1)||n>999999999999?'Enter a valid whole IQD amount':null;}),
  if(widget.kind=='expense')DropdownButtonFormField<String>(initialValue:_method,items:['cash','manual_card'].map((m)=>DropdownMenuItem(value:m,child:Text(m))).toList(),onChanged:_request!=null?null:(v)=>setState(()=>_method=v!),decoration:const InputDecoration(label: CafeText('Payment method'))),
  TextFormField(controller:_reason,enabled:_request==null,maxLength:500,maxLines:3,decoration:const InputDecoration(label: CafeText('Reason / receipt reference')),validator:(v)=>(v?.trim().length??0)<3?'Enter a reason':null),
  Text(widget.kind=='cash_in'?'Only record cash actually received. Do not enter order payments here.':widget.kind=='count'?'Enter the cash physically counted. This does not change the recorded balance.':'This request remains pending until an authorized review posts it.'),
  if(_error!=null)Text(_error!,style:const TextStyle(color:Colors.red)),
 ])))),actions:[TextButton(onPressed:_busy?null:()=>Navigator.pop(context),child:const CafeText('Close')),FilledButton(onPressed:_busy?null:_save,child:Text(_request==null?'Save':'Retry same entry'))]));
}
