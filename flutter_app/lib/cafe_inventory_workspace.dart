
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cafe_finance_surface.dart';
import 'cafe_language.dart';
import 'cafe_operations_workspace.dart';
import 'cafe_request_id.dart';

const cafeInventoryCards={
 'Inventory Overview':'inventory_overview','Low Stock':'low_stock','Low Stock Alerts':'low_stock_alerts',
 'Purchase Requests':'purchase_requests','Pending Approvals':'pending_approvals',
 'Supplier Deliveries':'supplier_deliveries','Inventory Waste':'inventory_waste',
};
const _purchaseStates={'requested','approved','rejected','part_received','received','cancelled'};
String inventoryAmount(dynamic value){
 final number=num.tryParse('$value');
 if(number==null||!number.isFinite){return 'Not recorded';}
 return number.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'),'').replaceFirst(RegExp(r'[.]$'),'');
}
String? inventoryQuantityError(String? value,{bool allowZero=false,num? maximum}){
 final text=(value??'').trim();final number=num.tryParse(text);
 if(!RegExp(r'^[0-9]+([.][0-9]{1,3})?$').hasMatch(text)||number==null||!number.isFinite||
  number>999999999.999||number<0||(!allowZero&&number==0)){return 'Enter a valid quantity with up to 3 decimals';}
 if(maximum!=null&&number>maximum){return 'Quantity exceeds the available amount';}
 return null;
}
num _number(dynamic value)=>value is num?value:num.parse('$value');
String _when(dynamic value){
 final time=DateTime.tryParse('$value');
 return time==null?'Not recorded':time.toUtc().add(const Duration(hours:3)).toIso8601String().substring(0,16).replaceAll('T',' ');
}
Map<String,dynamic> cafeInventoryData(dynamic raw){
 if(raw is! Map||raw['items'] is! List||raw['purchases'] is! List||raw['movements'] is! List||
  raw['counts'] is! Map||DateTime.tryParse('${raw['server_time']}')==null){throw const FormatException('Invalid inventory workspace');}
 for(final key in ['items','purchases','movements']){
  if(raw['counts'][key] is! int||raw['counts'][key]<0){throw const FormatException('Invalid coverage');}
  for(final row in raw[key]){
   if(row is! Map||row['id'] is! String){throw const FormatException('Invalid inventory row');}
   final fields=key=='items'?['on_hand','reorder_level']:key=='purchases'?['quantity','received']:['quantity','balance_after'];
   for(final field in fields){
    final value=num.tryParse('${row[field]}');
    if(value==null||!value.isFinite||value.abs()>999999999.999||(field!='quantity'&&value<0)){
     throw const FormatException('Invalid quantity');
    }
   }
   if(key=='items'&&(row['name'] is! String||row['unit'] is! String||row['version'] is! int)){
    throw const FormatException('Invalid stock item');
   }
   if(key=='purchases'&&(!_purchaseStates.contains(row['status'])||row['version'] is! int||
    row['item_name'] is! String||row['unit'] is! String||_number(row['quantity'])<=0||
    _number(row['received'])>_number(row['quantity']))){throw const FormatException('Invalid purchase');}
   if(key=='movements'&&(!const {'opening','receipt','waste'}.contains(row['kind'])||
    row['item_name'] is! String||row['unit'] is! String||DateTime.tryParse('${row['created_at']}')==null)){
    throw const FormatException('Invalid movement');
   }
  }
 }
 return Map<String,dynamic>.from(raw);
}
class CafeInventoryWorkspace extends StatefulWidget{
 const CafeInventoryWorkspace({super.key,required this.title,this.rpc});
 final String title;final CafeRpc? rpc;
 @override State<CafeInventoryWorkspace> createState()=>_CafeInventoryWorkspaceState();
}
class _CafeInventoryWorkspaceState extends State<CafeInventoryWorkspace>{
 final _search=TextEditingController();
 Map<String,dynamic>? _data,_pending;
 bool _loading=true,_busy=false;
 String? _error,_commandError;
 String _status='All';
 int _request=0;
 String get _card=>cafeInventoryCards[widget.title]!;
 bool get _purchases=>const {'purchase_requests','pending_approvals','supplier_deliveries'}.contains(_card);
 @override void initState(){super.initState();_status=_card=='supplier_deliveries'?'Awaiting delivery':'All';_load();}
 @override void dispose(){_request++;_search.dispose();super.dispose();}
 Future<void> _load()async{
  final request=++_request;
  setState((){_loading=true;_error=null;_data=null;});
  try{
   if(widget.rpc==null){throw StateError('Unavailable');}
   final data=cafeInventoryData(await widget.rpc!('get_cafe_inventory_workspace',{'p_card':_card,'p_query':_search.text.trim()}));
   if(mounted&&request==_request){setState(()=>_data=data);}
  }catch(_){
   if(mounted&&request==_request){setState(()=>_error='Could not load inventory. Check access, connection and the database update, then refresh.');}
  }finally{if(mounted&&request==_request){setState(()=>_loading=false);}}
 }
 Future<void> _send()async{
  if(_pending==null||_busy){return;}
  setState((){_busy=true;_commandError=null;});
  try{
   if(widget.rpc==null){throw StateError('Unavailable');}
   await widget.rpc!('perform_cafe_inventory_command',_pending!);
   if(!mounted){return;}_pending=null;await _load();
  }catch(error){
   if(!mounted){return;}
   final rejected=error is PostgrestException&&
    const {'22023','22P02','42501','40001','23505','23514','23503','23502','P0001','P0002'}.contains(error.code);
   setState((){
    if(rejected){_pending=null;}
    _commandError=rejected?'Change rejected. Review refreshed stock, approval and quantity before trying again.':
      'Result not confirmed. Retry the same request before making another stock change.';
   });
   if(rejected){await _load();}
  }finally{if(mounted){setState(()=>_busy=false);}}
 }
 Future<void> _edit(String action,[Map<String,dynamic>? row])async{
  final values=await showDialog<Map<String,dynamic>>(context:context,builder:(_)=>
   _InventoryEditor(action:action,row:row,items:cafeRows(_data?['items']??const [])));
  if(values==null||!mounted){return;}
  _pending={'p_request_id':newCafeRequestId(),'p_action':action,'p_id':row?['id'],
    'p_version':row?['version'],'p_data':values};
  await _send();
 }
 Widget _coverage(String key,int shown){
  final count=_data!['counts'][key] as int;
  return Text('$shown loaded · $count matching $key${count>shown?' · Limit 500: narrow the search':''}');
 }
 @override Widget build(BuildContext context)=>CafeFinanceSurface(builder:(context){
  final items=cafeRows(_data?['items']??const []);
  final purchases=cafeRows(_data?['purchases']??const []);
  final movements=cafeRows(_data?['movements']??const []);
  final visible=purchases.where((p)=>_status=='All'||(_status=='Awaiting delivery'
   ?const {'approved','part_received'}.contains(p['status']):p['status']==_status)).toList();
  final disabled=_loading||_busy||_error!=null||_pending!=null;
  return Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   CafeText(widget.title,style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
   const CafeText('Recorded stock only. Menu orders do not automatically consume inventory. Quantity approvals and deliveries do not create supplier payments or invoices.'),
   if(_card=='low_stock')const CafeText('Kitchen, café drinks and Nargile stock at or below its reorder level.'),
   Wrap(spacing:8,runSpacing:8,children:[
    if(_card=='inventory_overview'&&_data?['can_manage']==true)
     FilledButton(onPressed:disabled?null:()=>_edit('create_item'),child:const CafeText('Add stock item')),
    if(_card=='purchase_requests'&&_data?['can_request']==true)
     FilledButton(onPressed:disabled?null:()=>_edit('request'),child:const CafeText('New purchase request')),
    OutlinedButton(onPressed:_loading||_busy?null:_load,child:const CafeText('Refresh')),
   ]),
   TextField(controller:_search,enabled:!_busy,maxLength:120,onSubmitted:(_)=>_load(),
    decoration:InputDecoration(labelText:'Search items, suppliers or movement notes',prefixIcon:const Icon(Icons.search),
     suffixIcon:IconButton(onPressed:_busy?null:_load,icon:const Icon(Icons.arrow_forward),tooltip:'Search'))),
   if(_loading)const LinearProgressIndicator(),
   if(_error!=null)Text(_error!),
   if(_commandError!=null)Text(_commandError!),
   if(_pending!=null)OutlinedButton(onPressed:_busy?null:_send,child:const CafeText('Retry same request')),
   if(_data!=null)...[
    Text('Snapshot: ${_when(_data!['server_time'])} (Baghdad)'),
    if(!_purchases)...[
     _coverage('items',items.length),
     if(items.isEmpty)const CafeText('No matching stock items.'),
     for(final item in items)Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       Text(item['name'] as String,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
       Text('${item['department']} · ${inventoryAmount(item['on_hand'])} ${item['unit']} available'),
       Text('Reorder level: ${inventoryAmount(item['reorder_level'])} ${item['unit']}'),
       if(_number(item['on_hand'])<=_number(item['reorder_level']))const CafeText('Low stock'),
       Wrap(spacing:8,children:[
        if(_card=='inventory_overview'&&_data!['can_manage']==true)...[
         TextButton(onPressed:disabled?null:()=>_edit('update_item',item),child:const CafeText('Edit item')),
         if(item['has_movements']==false)TextButton(onPressed:disabled?null:()=>_edit('opening',item),child:const CafeText('Opening stock')),
        ],
        if(_card=='inventory_waste'&&_data!['can_waste']==true)
         OutlinedButton(onPressed:disabled?null:()=>_edit('waste',item),child:const CafeText('Record waste')),
       ]),
      ]))),
    ]else...[
     _coverage('purchases',purchases.length),
     if(_card!='pending_approvals')Wrap(spacing:8,children:[
      for(final status in ['All','Awaiting delivery',..._purchaseStates])
       ChoiceChip(label:CafeText(status.replaceAll('_',' ')),selected:_status==status,onSelected:(_)=>setState(()=>_status=status)),
     ]),
     Text('${visible.length} requests match the status filter'),
     if(visible.isEmpty)const CafeText('No matching purchase requests.'),
     for(final p in visible)Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       Text('${p['item_name']} · ${p['supplier']}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
       Text('Status: ${p['status'].toString().replaceAll('_',' ')}'),
       Text('Requested: ${inventoryAmount(p['quantity'])} ${p['unit']} · Received: ${inventoryAmount(p['received'])} ${p['unit']}'),
       Text('${p['status']=='cancelled'?'Undelivered quantity cancelled':'Remaining'}: ${inventoryAmount(_number(p['quantity'])-_number(p['received']))} ${p['unit']}'),
       Text('Requested: ${_when(p['created_at'])} (Baghdad)'),
       if('${p['note']??''}'.isNotEmpty)Text('${p['note']}'),
       if('${p['review_note']??''}'.isNotEmpty)Text('Review: ${p['review_note']}'),
       Wrap(spacing:8,children:[
        if(_data!['can_approve']==true&&p['status']=='requested')...[
         FilledButton(onPressed:disabled?null:()=>_edit('approve',p),child:const CafeText('Approve quantity')),
         TextButton(onPressed:disabled?null:()=>_edit('reject',p),child:const CafeText('Reject')),
        ],
        if(_data!['can_receive']==true&&const {'approved','part_received'}.contains(p['status']))
         FilledButton(onPressed:disabled?null:()=>_edit('receive',p),child:const CafeText('Receive delivery')),
        if(_data!['can_approve']==true&&const {'requested','approved','part_received'}.contains(p['status']))
         TextButton(onPressed:disabled?null:()=>_edit('cancel',p),child:const CafeText('Cancel remaining')),
       ]),
      ]))),
    ],
    if(const {'inventory_overview','supplier_deliveries','inventory_waste'}.contains(_card))
     ExpansionTile(title:const CafeText('Stock movement history'),children:[
      _coverage('movements',movements.length),
      if(movements.isEmpty)const CafeText('No matching recorded movements.'),
      for(final move in movements)ListTile(
       title:Text('${move['item_name']} · ${move['kind']} · ${inventoryAmount(move['quantity'])} ${move['unit']}'),
       subtitle:Text('${_when(move['created_at'])} (Baghdad)\n${move['note']}\nBalance after: ${inventoryAmount(move['balance_after'])} ${move['unit']}'),
      ),
     ]),
   ],
  ]));
 });
}
class _InventoryEditor extends StatefulWidget{
 const _InventoryEditor({required this.action,required this.items,this.row});
 final String action;final List<Map<String,dynamic>> items;final Map<String,dynamic>? row;
 @override State<_InventoryEditor> createState()=>_InventoryEditorState();
}
class _InventoryEditorState extends State<_InventoryEditor>{
 final _form=GlobalKey<FormState>();
 final _name=TextEditingController(),_unit=TextEditingController(),_quantity=TextEditingController(),
  _note=TextEditingController(),_supplier=TextEditingController();
 String _department='kitchen';String? _item;
 bool get _itemEdit=>const {'create_item','update_item'}.contains(widget.action);
 @override void initState(){
  super.initState();
  if(_itemEdit){
   _name.text='${widget.row?['name']??''}';_unit.text='${widget.row?['unit']??''}';
   _quantity.text=inventoryAmount(widget.row?['reorder_level']??0);_department='${widget.row?['department']??'kitchen'}';
  }
 }
 @override void dispose(){_name.dispose();_unit.dispose();_quantity.dispose();_note.dispose();_supplier.dispose();super.dispose();}
 String get _title=>switch(widget.action){
  'create_item'=>'Add stock item','update_item'=>'Edit stock item','opening'=>'Record opening stock',
  'request'=>'New purchase request','approve'=>'Approve quantity','reject'=>'Reject purchase request',
  'cancel'=>'Cancel remaining quantity','receive'=>'Receive delivery','waste'=>'Record waste',_=>'Inventory change',
 };
 void _save(){
  if(!_form.currentState!.validate()){return;}
  Map<String,dynamic> result;
  if(_itemEdit){result={'name':_name.text.trim(),'unit':_unit.text.trim(),'department':_department,'reorder_level':_quantity.text.trim()};}
  else if(widget.action=='request'){result={'item_id':_item,'supplier':_supplier.text.trim(),'quantity':_quantity.text.trim(),'note':_note.text.trim()};}
  else{result={'note':_note.text.trim(),if(const {'opening','receive','waste'}.contains(widget.action))'quantity':_quantity.text.trim()};}
  Navigator.pop(context,result);
 }
 @override Widget build(BuildContext context){
  final quantityAction=_itemEdit||const {'request','opening','receive','waste'}.contains(widget.action);
  final maximum=widget.action=='waste'?_number(widget.row!['on_hand']):widget.action=='receive'
   ?_number(widget.row!['quantity'])-_number(widget.row!['received']):null;
  return AlertDialog(title:CafeText(_title),
   content:SizedBox(width:480,child:SingleChildScrollView(child:Form(key:_form,child:Column(
    mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     if(widget.row!=null)Text('${widget.row!['name']??widget.row!['item_name']}'),
     if(_itemEdit)...[
      TextFormField(controller:_name,maxLength:120,decoration:const InputDecoration(labelText:'Item name'),
       validator:(v)=>(v??'').trim().isEmpty?'Enter an item name':null),
      TextFormField(controller:_unit,maxLength:16,enabled:widget.row?['unit_locked']!=true,
       decoration:const InputDecoration(labelText:'Unit (kg, litre, piece...)'),
       validator:(v)=>(v??'').trim().isEmpty?'Enter a unit':null),
      if(widget.row?['unit_locked']==true)const CafeText('Unit is locked because requests or stock movements already exist.'),
      DropdownButtonFormField<String>(initialValue:_department,decoration:const InputDecoration(labelText:'Department'),
       items:const ['kitchen','drinks','nargile','general'].map((v)=>DropdownMenuItem(value:v,child:CafeText(v))).toList(),
       onChanged:(v)=>setState(()=>_department=v!)),
     ],
     if(widget.action=='request')...[
      const CafeText('One item per request. Quantity approval does not create a supplier invoice or payment.'),
      DropdownButtonFormField<String>(initialValue:_item,isExpanded:true,decoration:const InputDecoration(labelText:'Stock item'),
       items:widget.items.map((i)=>DropdownMenuItem(value:i['id'] as String,child:Text('${i['name']} (${i['unit']})',overflow:TextOverflow.ellipsis))).toList(),
       onChanged:(v)=>setState(()=>_item=v),validator:(v)=>v==null?'Choose a stock item':null),
      if(widget.items.isEmpty)const CafeText('No items loaded. Clear or narrow the search, or ask an administrator to add the item.'),
      TextFormField(controller:_supplier,maxLength:120,decoration:const InputDecoration(labelText:'Supplier name'),
       validator:(v)=>(v??'').trim().isEmpty?'Enter a supplier':null),
     ],
     if(widget.action=='opening')const CafeText('Confirm physically counted opening stock. Allowed only before the first movement.'),
     if(widget.action=='approve')const CafeText('Approve this requested quantity? This does not record delivery or pay the supplier.'),
     if(widget.action=='cancel')const CafeText('Cancel the undelivered quantity. Stock already received stays in the ledger.'),
     if(widget.action=='receive')const CafeText('Confirm the quantity physically received and record its delivery reference.'),
     if(widget.action=='waste')const CafeText('This reduces recorded stock. Confirm the quantity and reason.'),
     if(quantityAction)TextFormField(controller:_quantity,keyboardType:const TextInputType.numberWithOptions(decimal:true),
      decoration:InputDecoration(labelText:_itemEdit?'Reorder level':'Quantity'),
      validator:(v)=>inventoryQuantityError(v,allowZero:_itemEdit,maximum:maximum)),
     if(!_itemEdit)TextFormField(controller:_note,maxLength:1000,maxLines:3,
      decoration:const InputDecoration(labelText:'Note / reason / delivery reference'),
      validator:(v)=>!const {'request','approve'}.contains(widget.action)&&(v??'').trim().runes.length<3?'Enter at least 3 characters':null),
    ])))),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(context),child:const CafeText('Cancel')),
    FilledButton(onPressed:_save,child:const CafeText('Confirm')),
   ]);
 }
}
