import 'cafe_language.dart';
import 'cafe_finance_surface.dart';
import 'package:flutter/material.dart';
import 'cafe_operations_workspace.dart';
import 'cafe_request_id.dart';
import 'expense_evidence.dart';

const expenseWorkspaceCards = <String,Set<String>>{
 'payment_management':{'Unpaid Expenses','Expense Payments','Expenses Management','Expenses','Costs & Expenses'},
 'dashboard':{'Accounts Payable','Pending Expenses','Expenses'},
};
class CafeExpenseWorkspace extends StatefulWidget{
 const CafeExpenseWorkspace({super.key,required this.title,this.rpc,this.evidence});
 final String title;final CafeRpc? rpc;final ExpenseEvidence? evidence;
 @override State<CafeExpenseWorkspace> createState()=>_CafeExpenseWorkspaceState();
}
class _CafeExpenseWorkspaceState extends State<CafeExpenseWorkspace>{
 Map<String,dynamic>? _data;bool _loading=true,_busy=false;String? _error,_notice;
 String _filter='Unpaid',_query='';
 DateTime? _loadedAt;
 int _loadRevision=0;
 Future<dynamic> _rpc(String name,Map<String,dynamic> params)async{if(widget.rpc==null)throw StateError('Connection unavailable');return widget.rpc!(name,params);}
 String get _initialFilter => const {'Expenses','Expenses Management','Costs & Expenses','Expense Payments'}.contains(widget.title)?'All':'Unpaid';
 @override void initState(){super.initState();_filter=_initialFilter;_load();}
 @override void didUpdateWidget(CafeExpenseWorkspace oldWidget){
  super.didUpdateWidget(oldWidget);
  if(oldWidget.title!=widget.title){_filter=_initialFilter;_query='';_load();}
 }
 @override void dispose(){_loadRevision++;super.dispose();}
 Future<void> _load()async{
  final revision=++_loadRevision;
  setState((){_loading=true;_data=null;_loadedAt=null;_error=null;});
  try{
   final data=Map<String,dynamic>.from(await _rpc('get_cafe_expenses',{}));
   if(mounted&&revision==_loadRevision)setState((){_data=data;_loadedAt=DateTime.now().toUtc();});
  }catch(_){if(mounted&&revision==_loadRevision)setState(()=>_error='Could not load expenses. Check connection and assigned permission.');}
  finally{if(mounted&&revision==_loadRevision)setState(()=>_loading=false);}
 }
 Future<void> _edit([Map<String,dynamic>? expense])async{
  final saved=await showDialog<bool>(context:context,barrierDismissible:false,builder:(_)=>_ExpenseForm(rpc:_rpc,expense:expense));
  if(saved==true&&mounted)await _load();
 }
 Future<void> _upload(Map<String,dynamic> row)async{
  setState((){_busy=true;_notice=null;});
  try{
   if(widget.evidence==null)throw StateError('Storage unavailable');
   final uploaded=await widget.evidence!.upload(row['id']);
   if(uploaded){await _load();if(mounted)setState(()=>_notice='Evidence uploaded. Payment status is unchanged.');}
  }catch(_){if(mounted)setState(()=>_error='Evidence upload was not completed. The expense is still saved; use a PDF, JPEG or PNG up to 10 MB and try again.');}
  finally{if(mounted)setState(()=>_busy=false);}
 }
 Future<void> _download(Map<String,dynamic> file)async{
  setState(()=>_busy=true);
  try{if(widget.evidence==null)throw StateError('Storage unavailable');await widget.evidence!.download(file);}
  catch(_){if(mounted)setState(()=>_error='Could not download the evidence. Check your connection and access.');}
  finally{if(mounted)setState(()=>_busy=false);}
 }
 @override Widget build(BuildContext context){
  final all=cafeRows(_data?['expenses']??[]);
  final today=DateTime.now().toUtc().add(const Duration(hours:3)).toIso8601String().substring(0,10);
  final rows=all.where((e){final amount=(e['amount_iqd'] as num).toInt(),paid=(e['paid_iqd'] as num).toInt();return (_filter=='All'||(_filter=='Unpaid'&&paid<amount)||(_filter=='Partially paid'&&paid>0&&paid<amount)||(_filter=='Paid'&&paid==amount)||(_filter=='Overdue'&&paid<amount&&e['due_on']!=null&&'${e['due_on']}'.compareTo(today)<0))&&'${e['supplier']} ${e['description']} ${e['invoice_reference']}'.toLowerCase().contains(_query.toLowerCase());}).toList();
  final outstanding=all.fold<int>(0,(sum,e)=>sum+(e['amount_iqd'] as num).toInt()-(e['paid_iqd'] as num).toInt());
  final matchingOutstanding=rows.fold<int>(0,(sum,e)=>sum+(e['amount_iqd'] as num).toInt()-(e['paid_iqd'] as num).toInt());
  return CafeFinanceSurface(builder:(context)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   CafeText(widget.title,style:Theme.of(context).textTheme.headlineSmall),
   const CafeText('Record a purchase now, attach its evidence, and record payment separately. Uploading a receipt never marks an expense paid.'),
   if(_data!=null&&!_loading&&_error==null)CafeText('Total unpaid: $outstanding IQD',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:20)),
   Wrap(spacing:8,children:[OutlinedButton(onPressed:_busy||_loading?null:_load,child:const CafeText('Refresh')),if(_data?['can_create']==true)FilledButton(onPressed:_busy||_loading||_error!=null?null:()=>_edit(),child:const CafeText('Add unpaid expense'))]),
   if(_loading)const LinearProgressIndicator(),
   if(_error!=null)Text(_error!,style:const TextStyle(color:Colors.red)),
   if(_notice!=null)Text(_notice!),
   if(_data!=null&&!_loading&&_error==null)...[
   if(_loadedAt!=null)CafeText('Last updated: ${cafeFinanceTimestamp(_loadedAt)} · Baghdad'),
   const CafeText('Totals cover loaded expenses. Search and filters only change the matching list.'),
   CafeText('Matching unpaid: $matchingOutstanding IQD'),
   Wrap(spacing:8,children:[for(final f in ['Unpaid','Partially paid','Paid','Overdue','All'])ChoiceChip(label:Text(f),selected:_filter==f,onSelected:(_)=>setState(()=>_filter=f))]),
   TextField(key:ValueKey('expense-search-${widget.title}'),decoration:const InputDecoration(label: CafeText('Search supplier, purchase or invoice')),onChanged:(v)=>setState(()=>_query=v)),
   if(rows.isEmpty)const Padding(padding:EdgeInsets.all(20),child:CafeText('No matching expenses.')),
   for(final e in rows)Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    CafeText('${e['supplier']} · ${e['amount_iqd']} IQD',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
    CafeText('${e['description']}'),CafeText('Invoice: ${e['invoice_reference']} · Purchased: ${e['purchased_on']} · Due: ${e['due_on']??'Not set'}'),
    CafeText('${(e['paid_iqd'] as num)==0?'Unpaid':e['paid_iqd']==e['amount_iqd']?'Paid':'Partially paid'} · Paid ${e['paid_iqd']} · Remaining ${(e['amount_iqd'] as num)-(e['paid_iqd'] as num)} IQD'),
    Wrap(spacing:8,children:[
     if(_data?['can_create']==true)OutlinedButton.icon(onPressed:_busy||_loading||_error!=null?null:()=>_upload(e),icon:const Icon(Icons.upload_file),label:const CafeText('Upload evidence')),
     if(_data?['can_pay']==true&&(e['paid_iqd'] as num)<(e['amount_iqd'] as num))FilledButton(onPressed:_busy||_loading||_error!=null?null:()=>_edit(e),child:const CafeText('Record expense payment')),
    ]),
    if(cafeRows(e['evidence']).isEmpty)const CafeText('No evidence uploaded yet.'),
    for(final file in cafeRows(e['evidence']))TextButton.icon(onPressed:_busy||_loading||_error!=null?null:()=>_download(file),icon:const Icon(Icons.attach_file),label:CafeText('${file['file_name']}')),
    for(final p in cafeRows(e['payments']))CafeText('Paid ${p['amount_iqd']} IQD · ${p['method']} · ${p['reference']} · ${cafeFinanceTimestamp(p['created_at'])} Baghdad'),
   ]))),
   ],
  ]))));
 }
}
class _ExpenseForm extends StatefulWidget{
 const _ExpenseForm({required this.rpc,this.expense});
 final CafeRpc rpc;final Map<String,dynamic>? expense;
 @override State<_ExpenseForm> createState()=>_ExpenseFormState();
}
class _ExpenseFormState extends State<_ExpenseForm>{
 final _supplier=TextEditingController(),_description=TextEditingController(),_reference=TextEditingController(),_amount=TextEditingController(),_purchased=TextEditingController(),_due=TextEditingController();
 final _form=GlobalKey<FormState>();String _method='cash';String? _error;bool _busy=false;Map<String,dynamic>? _request;
 bool get _payment=>widget.expense!=null;
 @override void initState(){super.initState();_purchased.text=DateTime.now().toUtc().add(const Duration(hours:3)).toIso8601String().substring(0,10);if(_payment)_amount.text='${(widget.expense!['amount_iqd'] as num)-(widget.expense!['paid_iqd'] as num)}';}
 @override void dispose(){for(final c in [_supplier,_description,_reference,_amount,_purchased,_due]){c.dispose();}super.dispose();}
 String? _date(String? v,{bool optional=false}){if(optional&&(v??'').isEmpty)return null;final parsed=DateTime.tryParse(v??'');return parsed==null||parsed.toIso8601String().substring(0,10)!=v?'Use YYYY-MM-DD':null;}
 Future<void> _save()async{
  if(_request==null){
   if(!_form.currentState!.validate())return;
   if(!_payment&&_due.text.isNotEmpty&&_due.text.compareTo(_purchased.text)<0){setState(()=>_error='Due date must be on or after the purchase date.');return;}
   _request=_payment?{'p_request_id':newCafeRequestId(),'p_expense_id':widget.expense!['id'],'p_amount':int.parse(_amount.text),'p_method':_method,'p_reference':_reference.text.trim()}:{'p_request_id':newCafeRequestId(),'p_supplier':_supplier.text.trim(),'p_description':_description.text.trim(),'p_reference':_reference.text.trim(),'p_amount':int.parse(_amount.text),'p_purchased':_purchased.text,'p_due':_due.text.isEmpty?null:_due.text};
  }
  setState(()=>_busy=true);
  try{await widget.rpc(_payment?'pay_cafe_expense':'create_cafe_expense',_request!);if(mounted)Navigator.pop(context,true);}
  catch(_){if(mounted)setState(()=>_error='Save was not confirmed. Retry keeps the same request. Cash payments require sufficient recorded cash; payments cannot exceed the unpaid balance.');}
  finally{if(mounted)setState(()=>_busy=false);}
 }
 @override Widget build(BuildContext context)=>PopScope(canPop:!_busy,child:AlertDialog(title:Text(_payment?'Record expense payment':'Add unpaid expense'),content:SizedBox(width:480,child:Form(key:_form,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
  if(!_payment)...[
   TextFormField(controller:_supplier,enabled:_request==null,maxLength:160,decoration:const InputDecoration(label: CafeText('Supplier')),validator:(v)=>(v?.trim().isEmpty??true)?'Enter supplier':null),
   TextFormField(controller:_description,enabled:_request==null,maxLength:1000,maxLines:2,decoration:const InputDecoration(label: CafeText('What did we buy?')),validator:(v)=>(v?.trim().length??0)<3?'Describe the purchase':null),
  ],
  TextFormField(controller:_amount,enabled:_request==null,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:_payment?'Payment amount IQD':'Purchase amount IQD'),validator:(v){final n=int.tryParse(v??'');return n==null||n<1||n>999999999999||(_payment&&n>(widget.expense!['amount_iqd'] as num)-(widget.expense!['paid_iqd'] as num))?'Enter an amount within the unpaid balance':null;}),
  if(_payment)DropdownButtonFormField<String>(initialValue:_method,items:['cash','manual_card'].map((m)=>DropdownMenuItem(value:m,child:Text(m))).toList(),onChanged:_request!=null?null:(v)=>setState(()=>_method=v!),decoration:const InputDecoration(label: CafeText('Method'))),
  TextFormField(controller:_reference,enabled:_request==null,maxLength:_payment?500:160,decoration:InputDecoration(labelText:_payment?'Payment reference':'Invoice reference (optional)'),validator:(v)=>_payment&&_method=='manual_card'&&(v?.trim().length??0)<3?'Enter card payment reference':null),
  if(!_payment)...[
   TextFormField(controller:_purchased,enabled:_request==null,decoration:const InputDecoration(label: CafeText('Purchase date YYYY-MM-DD')),validator:(v)=>_date(v)),
   TextFormField(controller:_due,enabled:_request==null,decoration:const InputDecoration(label: CafeText('Due date YYYY-MM-DD (optional)')),validator:(v)=>_date(v,optional:true)),
  ],
  Text(_payment?'Only confirm money already paid to the supplier. This records the payment; it does not send money.':'This saves an unpaid purchase. Upload invoice or receipt evidence after saving.'),
  if(_error!=null)Text(_error!,style:const TextStyle(color:Colors.red)),
 ])))),actions:[TextButton(onPressed:_busy?null:()=>Navigator.pop(context),child:const CafeText('Close')),FilledButton(onPressed:_busy?null:_save,child:Text(_request!=null?'Retry same request':_payment?'Confirm payment':'Save unpaid expense'))]));
}
