import 'cafe_language.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cafe_operations_workspace.dart' show CafeRpc, cafeRows;
import 'cafe_request_id.dart';

abstract class GuestPendingStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}
class LocalGuestPendingStore implements GuestPendingStore {
  final _prefs = SharedPreferencesAsync();
  @override
  Future<String?> read(String key) => _prefs.getString(key);
  @override
  Future<void> write(String key, String? value) async {
    if (value == null) { await _prefs.remove(key); } else { await _prefs.setString(key, value); }
  }
}
class CafeGuestPage extends StatefulWidget {
  const CafeGuestPage({required this.qrToken, this.supabaseConfigured = true, this.rpc, this.pendingStore, super.key});
  final String qrToken;
  final bool supabaseConfigured;
  final CafeRpc? rpc;
  final GuestPendingStore? pendingStore;
  @override
  State<CafeGuestPage> createState() => _CafeGuestPageState();
}
class _CafeGuestPageState extends State<CafeGuestPage> {
  late final _storage = widget.pendingStore ?? LocalGuestPendingStore();
  Map<String,dynamic>? _data, _pending;
  final _cart = <String,int>{};
  final _notes = TextEditingController();
  String _query = '', _category = 'All';
  String? _error, _notice;
  bool _loading = true, _busy = false;
  bool _restored = false;
  Timer? _timer;
  String get _key => 'cafe.guest.pending.v1.${widget.qrToken}';
  Future<dynamic> _rpc(String name, Map<String,dynamic> params) {
    if (!widget.supabaseConfigured) throw StateError('Table QR verification is not configured for this site.');
    return widget.rpc?.call(name,params) ?? Supabase.instance.client.rpc(name,params:params);
  }
  @override
  void initState() { super.initState(); _init(); _timer=Timer.periodic(const Duration(seconds:20), (_) { if(!_busy && _restored) _load(); }); }
  Future<void> _init() async {
    if (!widget.supabaseConfigured) { setState(() {_error='Table QR verification is not configured for this site.';_loading=false;});return; }
    try {
      final saved=await _storage.read(_key);
      if(saved!=null) _pending=Map<String,dynamic>.from(jsonDecode(saved) as Map);
      _restored = true;
    } catch (_) { if(mounted) setState(() {_error='Could not restore a pending order. Enable browser storage and reload before ordering.';_loading=false;});return; }
    await _load();
  }
  Future<void> _load() async {
    if(_busy || !_restored)return;
    try {
      final value=Map<String,dynamic>.from(await _rpc('get_cafe_guest_portal',{'p_qr_token':widget.qrToken}) as Map);
      if(mounted)setState(() {_data=value;_error=null;_loading=false;});
    } catch (_) {if(mounted)setState(() {_error='This table could not be loaded. Check your connection or ask staff for help.';_loading=false;});}
  }
  @override
  void dispose(){_timer?.cancel();_notes.dispose();super.dispose();}
  Future<void> _submit() async {
    if(_busy)return;
    if(_pending==null) {
      if(_cart.isEmpty)return;
      final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
        title:const CafeText('Confirm your order'),content:CafeText('Place ${_cart.values.fold<int>(0,(a,b)=>a+b)} items for this table? The table’s current menu prices apply.'),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const CafeText('Keep editing')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const CafeText('Confirm order'))]));
      if(ok!=true)return;
      final total = cafeRows(_data!['menu']).fold<int>(0, (sum,p) => sum + (_cart[p['id']] ?? 0) * (p['price_iqd'] as num).toInt());
      _pending={'method':'submit_cafe_guest_quoted_order','params':{'p_qr_token':widget.qrToken,'p_request_id':newCafeRequestId(),'p_items':_cart.entries.map((e)=>{'item_id':e.key,'quantity':e.value}).toList(),'p_notes':_notes.text.trim(),'p_visit_id':_data!['visit_id'],'p_expected_total':total,'p_expected_mode':(_data!['table'] as Map)['pricing_mode']}};
    }
    await _sendPending();
  }
  Future<void> _sendPending() async {
    if(_busy||_pending==null)return;
    setState((){_busy=true;_error=null;_notice=null;});
    try {
      // Persist before transmission; a reload retries the same logical request.
      await _storage.write(_key,jsonEncode(_pending));
      await _rpc(_pending!['method'] as String,Map<String,dynamic>.from(_pending!['params'] as Map));
      await _storage.write(_key,null);
      if(mounted)setState((){_pending=null;_cart.clear();_notes.clear();_notice='Sent successfully. Staff can see your request.';});
    } on PostgrestException catch (e) {
      if (e.code == '22023') {
        await _storage.write(_key,null);
        if (mounted) setState(() { _pending=null; _error='The request was rejected. Refresh the menu and review your order or ask staff for help.'; });
      } else { if(mounted)setState(()=>_error='Could not confirm the request. Retry sends the same request safely. Ask staff before placing a different order.'); }
    } catch (_) {if(mounted)setState(()=>_error='Could not confirm the request. Retry sends the same request safely. Ask staff before placing a different order.');}
    finally {if(mounted)setState(()=>_busy=false);}
    if(_pending==null)await _load();
  }
  Future<void> _request(String kind) async {
    if(_busy||_pending!=null)return;
    final controller=TextEditingController();
    final title=switch(kind){'call_staff'=>'Call staff','bill'=>'Request bill',_=>'Special request'};
    final message=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      title:CafeText(title),content:TextField(controller:controller,maxLength:1000,maxLines:3,decoration:InputDecoration(label:CafeText(kind=='special_request'?'Tell us what you need':'Message (optional)'))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const CafeText('Cancel')),FilledButton(onPressed:(){
        if(kind=='special_request'&&controller.text.trim().isEmpty)return;
        Navigator.pop(ctx,controller.text.trim());},child:const CafeText('Send request'))]));
    controller.dispose();
    if(message==null)return;
    _pending={'method':'submit_cafe_guest_service','params':{'p_qr_token':widget.qrToken,'p_request_id':newCafeRequestId(),'p_kind':kind,'p_message':message}};
    await _sendPending();
  }
  Future<void> _namedRequest({required bool individualBill}) async {
    if(_busy || _pending!=null || _data?['visit_id']==null)return;
    final name=TextEditingController();
    final notes=TextEditingController();
    final form=GlobalKey<FormState>();
    final message=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      title:CafeText(individualBill?'Request individual bill':'Add my name to this table'),
      content:SingleChildScrollView(child:Form(key:form,child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextFormField(controller:name,maxLength:80,autofocus:true,
          decoration:const InputDecoration(label: CafeText('Your name')),
          validator:(value)=>(value?.trim().isEmpty ?? true)?'Enter your name':null),
        if(individualBill)...[
          const CafeText('Tell staff which items are yours. Staff will confirm your separate bill; this does not split or pay the table bill automatically.'),
          TextFormField(controller:notes,maxLength:500,maxLines:3,
            decoration:const InputDecoration(label: CafeText('Your items / notes (optional)'))),
        ] else const CafeText('Your name will be sent to staff as a request for this table.'),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const CafeText('Cancel')),
        FilledButton(onPressed:(){
          if(!form.currentState!.validate())return;
          Navigator.pop(ctx,individualBill
            ?'Individual bill requested — Guest: ${name.text.trim()}\nItems / notes: ${notes.text.trim()}'
            :'Guest name for table: ${name.text.trim()}');
        },child:const CafeText('Send request'))]));
    // Wait for the dialog route to finish before disposing its controllers.
    await Future<void>.delayed(const Duration(milliseconds:300));
    name.dispose();notes.dispose();
    if(message==null || !mounted)return;
    _pending={'method':'submit_cafe_guest_service','params':{
      'p_qr_token':widget.qrToken,'p_request_id':newCafeRequestId(),
      'p_kind':'special_request','p_message':message}};
    await _sendPending();
  }
  void _bill() {
    final bill=Map<String,dynamic>.from(_data!['bill'] as Map);
    showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const CafeText('Your table bill'),
      content:SizedBox(width:520,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
        for(final order in cafeRows(bill['orders']))...[
          CafeText('Order ${(order['id'] as String).substring(0,8)} · ${order['status']}',style:const TextStyle(fontWeight:FontWeight.bold)),
          for(final item in cafeRows(order['items']))CafeText('${item['quantity']} × ${item['name']} — ${(item['quantity'] as num)*(item['unit_price_iqd'] as num)} IQD'),
          const Divider(),
        ],
        CafeText('Total: ${bill['total_iqd']} IQD'),CafeText('Paid: ${bill['paid_iqd']} IQD'),
        CafeText('Remaining: ${bill['balance_iqd']} IQD',style:const TextStyle(fontWeight:FontWeight.bold)),
        const CafeText('Payments are confirmed by staff. Requesting a bill does not make a payment.'),
      ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const CafeText('Close'))]));
  }
  @override
  Widget build(BuildContext context) {
    final menu=cafeRows(_data?['menu'] ?? []);
    final filtered=menu.where((p)=>(_category=='All'||p['category']==_category)&&'${p['name']} ${p['description']}'.toLowerCase().contains(_query.toLowerCase())).toList();
    final table=_data?['table'] as Map?;
    final locked=_busy||_pending!=null||_error!=null;
    final total=menu.fold<int>(0,(sum,p)=>sum+(_cart[p['id']]??0)*(p['price_iqd'] as num).toInt());
    return Scaffold(backgroundColor:const Color(0xFFF5F7FB),appBar:AppBar(actions:const [CafeLanguageButton()],title:const CafeText('Gelye Sherane Café'),backgroundColor:const Color(0xFF09243A),foregroundColor:Colors.white),
      body:_loading?const Center(child:CircularProgressIndicator()):Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:760),child:ListView(padding:const EdgeInsets.all(18),children:[
        if(_error!=null)...[CafeText(_error!,style:const TextStyle(color:Colors.red)),TextButton(onPressed:_busy?null:(_data==null?_init:_load),child:const CafeText('Try again'))],
        if(_pending!=null)FilledButton(onPressed:_busy?null:_sendPending,child:CafeText(_busy?'Sending…':'Retry pending request')),
        if(_notice!=null)CafeText(_notice!,style:const TextStyle(color:Colors.green)),
        if(table!=null)...[
          CafeText('${table['name']} · ${table['area']}',style:Theme.of(context).textTheme.headlineSmall),
          CafeText('Menu prices: ${table['pricing_mode'] ?? 'normal'} mode'),
          const SizedBox(height:12),
          Wrap(spacing:8,runSpacing:8,children:[
            OutlinedButton.icon(onPressed:locked?null:()=>_request('call_staff'),icon:const Icon(Icons.room_service_outlined),label:const CafeText('Call staff')),
            OutlinedButton(onPressed:locked?null:()=>_request('special_request'),child:const CafeText('Special request')),
            OutlinedButton(onPressed:locked||_data!['visit_id']==null?null:()=>_request('bill'),child:const CafeText('Request bill')),
            OutlinedButton(onPressed:_busy?null:_bill,child:const CafeText('View bill')),
            OutlinedButton(onPressed:locked||_data!['visit_id']==null?null:()=>_namedRequest(individualBill:true),child:const CafeText('Individual bill')),
            OutlinedButton(onPressed:locked||_data!['visit_id']==null?null:()=>_namedRequest(individualBill:false),child:const CafeText('Add my name')),
            IconButton(tooltip:'Refresh menu and bill',onPressed:_busy?null:_load,icon:const Icon(Icons.refresh)),
          ]),
          if(_data!['visit_id']==null)const Padding(padding:EdgeInsets.symmetric(vertical:12),child:CafeText('Browse the menu below. Ask staff to start your table visit before ordering.')),
          const SizedBox(height:12),
          TextField(decoration:const InputDecoration(label: CafeText('Search menu'),prefixIcon:Icon(Icons.search)),onChanged:(v)=>setState(()=>_query=v)),
          const SizedBox(height:8),
          Wrap(spacing:8,children:[for(final category in {'All',...menu.map((p)=>p['category'] as String)})ChoiceChip(label:Text(category),selected:_category==category,onSelected:(_)=>setState(()=>_category=category))]),
          for(final product in filtered)Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            if(product['image_path'] != null) Image.network(Supabase.instance.client.storage.from('cafe-product-images').getPublicUrl(product['image_path'] as String),height:140,fit:BoxFit.cover,errorBuilder:(_,e,s)=>const SizedBox.shrink()),
            Text(product['name'] as String,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
            if((product['description'] as String? ?? '').isNotEmpty)Text(product['description'] as String),
            Row(children:[Expanded(child:CafeText('${product['price_iqd']} IQD')),
              IconButton(tooltip:'Remove ${product['name']}',onPressed:locked?null:()=>setState((){final q=(_cart[product['id']]??0)-1;if(q<=0){_cart.remove(product['id']);}else{_cart[product['id'] as String]=q;}}),icon:const Icon(Icons.remove)),
              CafeText('${_cart[product['id']]??0}'),
              IconButton(tooltip:'Add ${product['name']}',onPressed:locked||_data!['visit_id']==null||(_cart[product['id']]??0)>=20||(!_cart.containsKey(product['id'])&&_cart.length>=20)?null:()=>setState(()=>_cart[product['id'] as String]=(_cart[product['id']]??0)+1),icon:const Icon(Icons.add)),
            ]),
          ]))),
          if(filtered.isEmpty)const CafeText('No available products match this search.'),
          TextField(controller:_notes,enabled:!locked,maxLength:500,maxLines:2,decoration:const InputDecoration(label: CafeText('Order notes / special preparation'))),
          CafeText('Order total: $total IQD',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
          FilledButton(onPressed:locked||_cart.isEmpty||_data!['visit_id']==null?null:_submit,child:const CafeText('Review and place order')),
          const SizedBox(height:20),
          const CafeText('Orders for this table',style:TextStyle(fontWeight:FontWeight.bold,fontSize:20)),
          const CafeText('Status refreshes every 20 seconds. Only this table’s current visit is shown.'),
          if(cafeRows(_data!['orders'] ?? []).isEmpty)const CafeText('No orders placed for this visit yet.'),
          for(final order in cafeRows(_data!['orders'] ?? []))Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            CafeText('Order ${(order['id'] as String).substring(0,8)}',style:const TextStyle(fontWeight:FontWeight.bold)),
            Semantics(liveRegion:true,child:Chip(avatar:Icon(switch(order['status']){'preparing'=>Icons.soup_kitchen,'ready'=>Icons.room_service,'served'=>Icons.check_circle,'cancelled'=>Icons.cancel_outlined,_=>Icons.receipt_long}),label:CafeText(switch(order['status']){'preparing'=>'Preparing','ready'=>'Ready','served'=>'Served','cancelled'=>'Cancelled',_=>'Received'}))),
            for(final item in cafeRows(order['items']))CafeText('${item['quantity']} × ${item['name']}'),
            if(order['status']!='cancelled')CafeText('${order['total_iqd']} IQD'),
            if(['preparing','ready','served'].contains(order['status']))const CafeText('Accepted by staff. Contact staff for any changes or cancellation.'),
            if(order['status']=='cancelled')const CafeText('This order is cancelled and excluded from your bill.'),
          ]))),
          const SizedBox(height:20),
          const CafeText('Requests',style:TextStyle(fontWeight:FontWeight.bold)),
          for(final request in cafeRows(_data!['requests']))ListTile(title:Text((request['kind'] as String).replaceAll('_',' ')),subtitle:Text(request['status'] as String)),
        ],
      ]))));
  }
}
