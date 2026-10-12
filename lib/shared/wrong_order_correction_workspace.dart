import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Staff-only correction workspace. The server controls approval, pricing,
/// duplicate prevention and payment/settlement restrictions.
class WrongOrderCorrectionWorkspace extends StatefulWidget {
  const WrongOrderCorrectionWorkspace({super.key});
  @override
  State<WrongOrderCorrectionWorkspace> createState() => _WrongOrderCorrectionWorkspaceState();
}

class _WrongOrderCorrectionWorkspaceState extends State<WrongOrderCorrectionWorkspace> {
  final _order = TextEditingController();
  final _details = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _items = [], _products = [], _corrections = [], _bill = [];
  Map<String, dynamic>? _quote;
  int? _selectedItem, _replacement;
  String _reason = 'wrong_order';
  bool _busy = false;
  String? _error;

  int? get _orderId => int.tryParse(_order.text.trim());
  @override
  void dispose() { _order.dispose(); _details.dispose(); _quantity.dispose(); super.dispose(); }

  Future<void> _load() async {
    final id = _orderId;
    if (id == null || id <= 0) { setState(() => _error = 'Enter a valid order number.'); return; }
    setState(() { _busy = true; _error = null; });
    try {
      final orderRows = await _client.from('gs_orders').select('id,is_motel').eq('id', id).limit(1);
      if (orderRows.isEmpty || orderRows.first['is_motel'] == true) {
        throw Exception('Table order not found or unsupported motel order.');
      }
      final items = await _client.from('gs_order_items').select('id,quantity,product_id,unit_price_iqd,gs_menu_products(name)').eq('order_id', id);
      final products = await _client.from('gs_menu_products').select('id,name').eq('is_active',true).order('name').limit(500);
      final corrections = await _client.rpc('gs_staff_correction_waste_list',params:{'p_order_id':id});
      final bill = await _client.rpc('gs_correction_adjusted_order_bill',params:{'p_order_id':id});
      final quote = await _client.rpc('gs_corrected_invoice_quote',params:{'p_order_id':id});
      if (!mounted) return;
      setState(() {
        _items = List<Map<String,dynamic>>.from(items);
        _products = List<Map<String,dynamic>>.from(products);
        _corrections = List<Map<String,dynamic>>.from(corrections);
        _bill = List<Map<String,dynamic>>.from(bill);
        _quote = Map<String,dynamic>.from(quote);
        if (!_items.any((e) => e['id'] == _selectedItem)) _selectedItem = null;
      });
    } catch (_) { if (mounted) setState(() => _error = 'Unable to load authorized order/corrections. Check permissions and migration.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _request() async {
    final qty = int.tryParse(_quantity.text.trim());
    if (_selectedItem == null || qty == null || qty < 1 || _details.text.trim().length < 5) {
      setState(() => _error = 'Select an item, quantity, and a reason of at least 5 characters.'); return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await _client.rpc('gs_request_order_item_correction',params:{
        'p_item_id':_selectedItem, 'p_quantity':qty,'p_reason':_reason,
        'p_details':_details.text.trim(),'p_replacement_product_id':_replacement,
      });
      _details.clear();
      await _load();
    } catch (_) { if (mounted) setState(() => _error = 'Correction request rejected. Check quantities, settlement and permissions.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _decide(int correctionId,bool approve) async {
    setState(() { _busy = true; _error = null; });
    try {
      await _client.rpc('gs_decide_order_item_correction',params:{'p_correction_id':correctionId,'p_approve':approve});
      await _load();
    } catch (_) { if (mounted) setState(() => _error = 'Decision requires authorized finance manager and MFA, with no prior settlement.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _addReplacement(int correctionId) async {
    setState(() { _busy = true; _error = null; });
    try {
      await _client.rpc('gs_add_approved_correction_replacement',params:{'p_correction_id':correctionId});
      await _load();
    } catch (_) { if (mounted) setState(() => _error = 'Replacement could not be created. Manager authorization, MFA, and unsettled order required.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16),children:[
    const Text('Wrong Orders & Waste',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
    const Text('Record incorrect items, request replacement products, and review corrected bill. A manager must approve before the item is excluded from payment.'),
    const SizedBox(height:12),
    Row(children:[Expanded(child:TextField(controller:_order,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Table order ID',border:OutlineInputBorder()))),
      const SizedBox(width:8),FilledButton(onPressed:_busy?null:_load,child:const Text('Load'))]),
    if (_error != null) Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
    const SizedBox(height:14),
    if (_items.isNotEmpty) Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Mark an item wrong / wasted',style:TextStyle(fontWeight:FontWeight.bold)),
      DropdownButtonFormField<int>(value:_selectedItem,decoration:const InputDecoration(labelText:'Original order item'),isExpanded:true,
        items:_items.map((e)=>DropdownMenuItem<int>(value:e['id'] as int,child:Text('#${e['id']} · ${e['gs_menu_products']?['name'] ?? 'Product'} ×${e['quantity']}'))).toList(),onChanged:_busy?null:(v)=>setState(()=>_selectedItem=v)),
      DropdownButtonFormField<String>(value:_reason,decoration:const InputDecoration(labelText:'Reason'),items:const [
        DropdownMenuItem(value:'wrong_order',child:Text('Wrong order / wrong entry')),
        DropdownMenuItem(value:'waste',child:Text('Prepared and wasted')),
        DropdownMenuItem(value:'incorrect_preparation',child:Text('Incorrect preparation'))],onChanged:_busy?null:(v)=>setState(()=>_reason=v!)),
      TextField(controller:_quantity,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Incorrect quantity')),
      TextField(controller:_details,maxLength:500,decoration:const InputDecoration(labelText:'What happened? (required)')),
      DropdownButtonFormField<int?>(value:_replacement,isExpanded:true,decoration:const InputDecoration(labelText:'Correct replacement product (optional)'),
        items:[const DropdownMenuItem<int?>(value:null,child:Text('No replacement')),..._products.map((e)=>DropdownMenuItem<int?>(value:e['id'] as int,child:Text('${e['name']} (#${e['id']})')))],
        onChanged:_busy?null:(v)=>setState(()=>_replacement=v)),
      const SizedBox(height:8),FilledButton.icon(onPressed:_busy?null:_request,icon:const Icon(Icons.report_problem_outlined),label:const Text('Submit correction for approval')),
    ]))),
    if (_quote != null) Card(child:ListTile(title:Text('Corrected amount due: ${_quote!['cash_remaining_iqd']} IQD'),subtitle:Text('Original: ${_quote!['original_total_iqd']} IQD · Approved removed: ${_quote!['approved_removed_iqd']} IQD · Pending corrections: ${_quote!['pending_corrections']}'))),
    if (_bill.isNotEmpty) ...[
      const Padding(padding:EdgeInsets.only(top:12),child:Text('Customer payable items (approved corrections excluded)',style:TextStyle(fontWeight:FontWeight.bold))),
      ..._bill.where((e)=>(e['payable_quantity'] as num? ?? 0)>0).map((e)=>ListTile(dense:true,title:Text('Product #${e['product_id']} · Qty ${e['payable_quantity']}'),trailing:Text('${e['payable_line_iqd']} IQD'))),
    ],
    const Padding(padding:EdgeInsets.only(top:16),child:Text('Correction / Waste History (internal only)',style:TextStyle(fontWeight:FontWeight.bold))),
    ..._corrections.map((e)=>Card(child:Column(children:[ListTile(title:Text('#${e['correction_id']} · ${e['reason']} · ${e['decision']}'),subtitle:Text('Item #${e['item_id']} ×${e['requested_quantity']} · ${e['details']}\nReplacement: ${e['replacement_product_name'] ?? 'None'}')),
      if (e['decision']=='pending') Wrap(spacing:8,children:[TextButton(onPressed:_busy?null:()=>_decide(e['correction_id'] as int,true),child:const Text('Approve (manager)')),TextButton(onPressed:_busy?null:()=>_decide(e['correction_id'] as int,false),child:const Text('Reject'))]),
      if (e['decision']=='approved' && e['replacement_product_id']!=null && e['replacement_item_id']==null)
        TextButton(onPressed:_busy?null:()=>_addReplacement(e['correction_id'] as int),child:const Text('Create correctly priced replacement')),
    ]))),
    const SizedBox(height:8),const Text('Unprepared mistakes are correction records, not physical waste. Inventory deductions, printed invoice integration, and kitchen cancellation/reprint require separate verification.',style:TextStyle(fontSize:12)),
  ]);
}
