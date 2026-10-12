import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'public_order_tracking_screen.dart';

/// Public request checkout. No card collection and no direct order table writes.
class PublicOnlineOrderScreen extends StatefulWidget {
  const PublicOnlineOrderScreen({super.key});
  @override
  State<PublicOnlineOrderScreen> createState() => _PublicOnlineOrderScreenState();
}
class _PublicOnlineOrderScreenState extends State<PublicOnlineOrderScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  final Map<int,int> _cart = {};
  late final Future<List<Map<String,dynamic>>> _products = _load();
  bool _sending = false;
  Future<List<Map<String,dynamic>>> _load() async {
    final data = await Supabase.instance.client.rpc('gs_public_order_menu');
    return (data as List).map((e) => Map<String,dynamic>.from(e as Map)).toList();
  }
  @override
  void dispose() { _name.dispose(); _phone.dispose(); _notes.dispose(); super.dispose(); }
  Future<void> _submit() async {
    if (_sending || _cart.isEmpty || _name.text.trim().length < 2 || _phone.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your name, phone, and select items.'))); return;
    }
    setState(() => _sending = true);
    try {
      final result = await Supabase.instance.client.rpc('gs_submit_public_order', params: {
        'p_name': _name.text.trim(), 'p_phone': _phone.text.trim(), 'p_notes': _notes.text.trim(),
        'p_items': _cart.entries.map((e) => {'product_id':e.key,'quantity':e.value}).toList(),
      });
      if (!mounted) return;
      final receipt = Map<String, dynamic>.from(result as Map);
      final token = receipt['tracking_token']?.toString() ?? '';
      setState(() => _cart.clear());
      if (!mounted) return;
      await showDialog<void>(context: context, barrierDismissible: false, builder: (dialogContext) => AlertDialog(
        title: const Text('Order request received'),
        content: SelectableText('Save this private tracking code now. It will not be displayed again.\n\n$token'),
        actions: [
          TextButton(onPressed: () => Clipboard.setData(ClipboardData(text: token)), child: const Text('Copy code')),
          FilledButton(onPressed: () { Navigator.pop(dialogContext); Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PublicOrderTrackingScreen(initialToken: token))); }, child: const Text('Track order')),
        ],
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to submit. Please retry or contact staff.')));
    } finally { if (mounted) setState(() => _sending = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Online order request')),
    body: FutureBuilder<List<Map<String,dynamic>>>(future:_products,builder:(context,snapshot) {
      if (!snapshot.hasData) return Center(child: snapshot.hasError ? const Text('Ordering is unavailable.') : const CircularProgressIndicator());
      final products=snapshot.data!;
      int total=0;
      for (final p in products) { final id=(p['id'] as num).toInt(); total+=((p['price_iqd'] as num).toInt())*(_cart[id]??0); }
      return ListView(padding: const EdgeInsets.all(16),children:[
        const Text('Prices are estimates until the server accepts your request.'),
        ...products.map((p) { final id=(p['id'] as num).toInt(); final count=_cart[id]??0; return Card(child:ListTile(
          title:Text(p['name'].toString()),subtitle:Text('${p['price_iqd']} IQD'),
          trailing:Row(mainAxisSize:MainAxisSize.min,children:[
            IconButton(icon:const Icon(Icons.remove),onPressed:count==0?null:()=>setState(() {if(count==1){_cart.remove(id);}else{_cart[id]=count-1;}})),
            Text('$count'),IconButton(icon:const Icon(Icons.add),onPressed:count>=20?null:()=>setState(()=>_cart[id]=count+1)),
          ]))); }),
        Text('Estimated total: $total IQD',style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:12),
        TextField(controller:_name,maxLength:100,decoration:const InputDecoration(labelText:'Customer name')),
        TextField(controller:_phone,maxLength:30,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Phone number')),
        TextField(controller:_notes,maxLength:500,maxLines:2,decoration:const InputDecoration(labelText:'Notes (optional)')),
        FilledButton(onPressed:_sending?null:_submit,child:Text(_sending?'Submitting...':'Send order request')),
        const Text('No payment is collected. Staff must accept your request.'),
      ]);
    }),
  );
}
