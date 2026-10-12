import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Intake-only counter orders: does not create a charge, kitchen ticket or payment.
class CounterOrdersWorkspace extends StatefulWidget {
  const CounterOrdersWorkspace({super.key});
  @override
  State<CounterOrdersWorkspace> createState() => _CounterOrdersWorkspaceState();
}

class _CounterOrdersWorkspaceState extends State<CounterOrdersWorkspace> {
  final db = Supabase.instance.client;
  final customer = TextEditingController();
  final phone = TextEditingController();
  final items = TextEditingController();
  final instructions = TextEditingController();
  String type = 'pickup';
  final productSearch = TextEditingController();
  List<Map<String,dynamic>> matches = [];
  int? selectedProductId;
  bool searching = false;
  final quantity = TextEditingController(text: '1');
  String mode = 'normal';
  int? selectedRequestId;
  Map<String,dynamic>? draft;
  bool busy = false;
  String? message;
  List<Map<String,dynamic>> queue = [];

  @override
  void initState() { super.initState(); refresh(); }
  @override
  void dispose() {
    customer.dispose();phone.dispose();items.dispose();instructions.dispose();
    productSearch.dispose();quantity.dispose();
    super.dispose();
  }
  Future<void> refresh() async {
    try {
      final result = await db.rpc('gs_list_counter_order_requests');
      if (mounted) setState(() => queue = (result as List)
        .map((e) => Map<String,dynamic>.from(e as Map)).toList());
    } catch(e) {
      if (mounted) setState(() => message = 'Could not load queue: $e');
    }
  }
  Future<void> submit() async {
    if (busy) return;
    setState(() { busy=true;message=null; });
    try {
      final id = await db.rpc('gs_create_counter_order_request',params: {
        'p_type':type,
        'p_customer_name':customer.text.trim(),
        'p_phone':phone.text.trim(),
        'p_items_notes':items.text.trim(),
        'p_delivery_instructions':instructions.text.trim(),
      });
      if (!mounted) return;
      setState(() => message = 'Request #$id recorded (not charged).');
      items.clear();instructions.clear();
      await refresh();
    } catch(e) {
      if (mounted) setState(() => message='Could not create request: $e');
    } finally {
      if (mounted) setState(() => busy=false);
    }
  }
  Future<void> searchProducts() async {
    final term = productSearch.text.trim();
    if (term.isEmpty) {
      setState(() { matches = []; selectedProductId = null; });
      return;
    }
    setState(() { searching = true; message = null; selectedProductId = null; });
    try {
      final result = await db.rpc('gs_search_counter_menu_products',
        params: {'p_query': term});
      if (!mounted) return;
      setState(() => matches = (result as List)
        .map((e) => Map<String,dynamic>.from(e as Map)).toList());
    } catch(e) {
      if (mounted) setState(() => message = 'Menu search failed: $e');
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  Future<void> loadDraft(int id) async {
    setState(() { selectedRequestId = id; draft = null; });
    try {
      final result = await db.rpc('gs_counter_request_item_summary',
        params: {'p_request_id': id});
      if (mounted && selectedRequestId == id) {
        setState(() => draft = Map<String,dynamic>.from(result as Map));
      }
    } catch (e) {
      if (mounted) setState(() => message = 'Could not load draft: $e');
    }
  }

  Future<void> removeDraftItem(int itemId) async {
    final id = selectedRequestId;
    if (busy || id == null) return;
    setState(() { busy = true; message = null; });
    try {
      await db.rpc('gs_remove_counter_request_menu_item', params: {
        'p_request_id': id, 'p_item_id': itemId,
      });
      if (mounted) await loadDraft(id);
    } catch (e) {
      if (mounted) setState(() => message = 'Could not remove draft item: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> addMenuItem() async {
    final id = selectedRequestId;
    final product = selectedProductId;
    final count = int.tryParse(quantity.text);
    if (id == null || product == null || count == null) {
      setState(() => message = 'Select a pending request, a menu product and quantity.');
      return;
    }
    setState(() { busy = true; message = null; });
    try {
      await db.rpc('gs_add_counter_request_menu_item',params: {
        'p_request_id':id,'p_product_id':product,
        'p_quantity':count,'p_price_mode':mode,
      });
      final result = await db.rpc('gs_counter_request_item_summary',
        params:{'p_request_id':id});
      if (mounted) {
        setState(() => message =
          'Draft item saved. ${result['draft_total_iqd']} IQD draft total; NOT charged.');
        await loadDraft(id);
      }
    } catch(e) {
      if (mounted) setState(() => message = 'Item not added: $e');
    } finally {
      if (mounted) setState(() => busy=false);
    }
  }

  Future<void> submitForKitchenReview() async {
    final id = selectedRequestId;
    if (busy || id == null) return;
    setState(() { busy = true; message = null; });
    try {
      await db.rpc('gs_submit_counter_request_for_review',
        params: {'p_request_id': id});
      if (!mounted) return;
      setState(() => message = 'Request #$id locked for kitchen review. '
        'No kitchen ticket or payment has been posted.');
      await loadDraft(id);
      await refresh();
    } catch (e) {
      if (mounted) setState(() => message = 'Submission failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('Takeaway & Delivery · No Table Required',
        style: Theme.of(context).textTheme.titleLarge),
      const Text('Draft requests only. Menu prices are previewed by Supabase; '
        'kitchen submission and payment are not enabled here.'),
      DropdownButtonFormField<String>(
        value:type,
        items:const [
          DropdownMenuItem(value:'pickup',child:Text('Customer pickup')),
          DropdownMenuItem(value:'delivery',child:Text('Delivery')),
        ],
        onChanged:(v) => setState(() => type=v ?? 'pickup'),
        decoration:const InputDecoration(labelText:'Order type')),
      TextField(controller:customer,decoration:
        const InputDecoration(labelText:'Customer name')),
      TextField(controller:phone,keyboardType:TextInputType.phone,
        decoration:const InputDecoration(labelText:'Phone (optional)')),
      TextField(controller:items,maxLines:3,
        decoration:const InputDecoration(labelText:'Requested items / quantities')),
      if(type=='delivery') TextField(controller:instructions,maxLines:2,
        decoration:const InputDecoration(labelText:'Delivery instructions')),
      const SizedBox(height:12),
      FilledButton(onPressed:busy?null:submit,
        child:Text(busy?'Saving...':'Record unpriced request')),
      if(message!=null) SelectableText(message!),
      const Divider(),
      Text('Menu-priced draft items',style:Theme.of(context).textTheme.titleMedium),
      const Text('Select a pending request below, search by product name or exact barcode, '
        'then choose a matching product. Prices are set by Supabase; no payment is posted.'),
      Text('Selected request: ${selectedRequestId ?? 'none'}'),
      TextField(controller:productSearch,
        onSubmitted: (_) => searchProducts(),
        decoration:InputDecoration(labelText:'Search product name or barcode',
          suffixIcon:IconButton(
            onPressed:searching ? null : searchProducts,
            icon:const Icon(Icons.search)))),
      if (searching) const LinearProgressIndicator(),
      if (matches.isNotEmpty) ConstrainedBox(
        constraints:const BoxConstraints(maxHeight:220),
        child:ListView(shrinkWrap:true,children:[
          for(final p in matches) ListTile(
            selected:selectedProductId==p['product_id'],
            title:Text(p['name'].toString()),
            subtitle:Text('Barcode: ${p['barcode']} · '
              'Normal ${p['normal_price_iqd']} IQD · '
              'Tourism ${p['tourism_price_iqd']} IQD'),
            onTap:()=>setState(() => selectedProductId =
              (p['product_id'] as num).toInt()),
          ),
        ])),
      Text('Selected product: ${selectedProductId ?? 'none'}'),
      TextField(controller:quantity,keyboardType:TextInputType.number,
        decoration:const InputDecoration(labelText:'Quantity')),
      DropdownButtonFormField<String>(value:mode,
        items:const [DropdownMenuItem(value:'normal',child:Text('Normal price')),
          DropdownMenuItem(value:'tourism',child:Text('Tourism price'))],
        onChanged:(v)=>setState(()=>mode=v??'normal')),
      FilledButton(onPressed:busy || selectedRequestId==null || selectedProductId==null ? null : addMenuItem,
        child:const Text('Add priced draft item')),
      const Divider(),
      if (draft != null) Card(child:Padding(
        padding:const EdgeInsets.all(12),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Request #$selectedRequestId · Draft items',
            style:Theme.of(context).textTheme.titleMedium),
          for(final item in (draft!['priced_items'] as List? ?? []))
            ListTile(
              title:Text('${item['quantity']} × ${item['product']}'),
              subtitle:Text('${item['mode']} · ${item['line_total_iqd']} IQD'),
              trailing:IconButton(
                tooltip:'Remove draft item',
                onPressed:busy ? null : () => removeDraftItem(
                  (item['id'] as num).toInt()),
                icon:const Icon(Icons.remove_circle_outline)),
            ),
          Text('Draft total: ${draft!['draft_total_iqd']} IQD',
            style:const TextStyle(fontWeight:FontWeight.bold)),
          const Text('Not paid, prepared or delivered.'),
          FilledButton.icon(
            onPressed:busy || (draft!['priced_items'] as List? ?? []).isEmpty
              ? null : submitForKitchenReview,
            icon:const Icon(Icons.assignment_turned_in_outlined),
            label:const Text('Submit for kitchen review (no ticket yet)')),
        ]))),
      const Divider(),
      Row(children:[
        const Expanded(child:Text('Recent counter requests')),
        IconButton(onPressed:refresh,icon:const Icon(Icons.refresh)),
      ]),
      for(final q in queue) Card(child:ListTile(
        selected:selectedRequestId==q['id'],
        onTap:()=>loadDraft((q['id'] as num).toInt()),
        title:Text('#${q['id']} · ${q['order_type']} · ${q['customer_name']}'),
        subtitle:Text('${q['status']} · ${q['items_notes']}'),
      )),
    ]);
}
