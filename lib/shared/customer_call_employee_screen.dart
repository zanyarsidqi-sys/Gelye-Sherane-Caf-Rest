import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerCallEmployeeScreen extends StatefulWidget {
  const CustomerCallEmployeeScreen({super.key, this.visitSessionToken, this.initialType = 'waiter', this.initialNote});
  final String initialType;
  final String? initialNote;
  final String? visitSessionToken;
  @override
  State<CustomerCallEmployeeScreen> createState() => _CustomerCallEmployeeScreenState();
}

class _CustomerCallEmployeeScreenState extends State<CustomerCallEmployeeScreen> {
  String type = 'waiter';

  @override
  void initState() {
    super.initState();
    const types = {'waiter', 'cashier', 'shisha', 'supervisor', 'any', 'specific_order', 'pricing_request', 'extra_chairs', 'long_wait', 'pick_dishes', 'clean_table'};
    type = types.contains(widget.initialType) ? widget.initialType : 'waiter';
    note.text = widget.initialNote ?? '';
  }
  int chairCount = 1;
  final note = TextEditingController();
  String? callId;
  String? status;
  String? error;
  bool busy = false;
  Timer? _statusPoll;
  bool _checkingStatus = false;
  bool employeeAssigned = false;

  void _startTracking() {
    _statusPoll?.cancel();
    _statusPoll = Timer.periodic(const Duration(seconds: 8), (_) => refresh());
  }

  Future<void> send() async {
    if (widget.visitSessionToken == null || busy) return;
    if ((type == 'specific_order' || type == 'pricing_request') && note.text.trim().isEmpty) {
      setState(() => error = type == 'pricing_request' ? 'Describe the product or pricing question.' : 'Describe the specific order or item you need.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final details = type == 'extra_chairs'
        ? 'Extra chairs requested: $chairCount. ${note.text.trim()}'.substring(0, ('Extra chairs requested: $chairCount. ${note.text.trim()}').length.clamp(0, 300))
        : type == 'long_wait' ? 'Long wait: ${note.text.trim()}'
        : type == 'pick_dishes' ? 'Please collect dishes: ${note.text.trim()}'
        : type == 'clean_table' ? 'Please clean the table: ${note.text.trim()}'
        : note.text.trim();
      final result = await Supabase.instance.client.rpc('gs_customer_request_employee',params: {
        'p_session_token': widget.visitSessionToken,
        'p_call_type': type, 'p_note': details,
      });
      if (mounted) {
        setState(() { callId = result.toString(); status = 'waiting'; employeeAssigned = false; });
        _startTracking();
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to send. Check your visit or ask staff for help.');
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> cancelWaitingRequest() async {
    if (callId == null || status != 'waiting' || busy) return;
    setState(() { busy = true; error = null; });
    try {
      await Supabase.instance.client.rpc('gs_customer_cancel_call', params: {
        'p_session_token': widget.visitSessionToken,
        'p_call_id': callId,
      });
      if (!mounted) return;
      _statusPoll?.cancel();
      setState(() { status = 'cancelled'; employeeAssigned = false; });
    } catch (_) {
      if (mounted) {
        setState(() => error =
          'Unable to cancel. An employee may already have accepted this request.');
        await refresh();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> refresh() async {
    if (callId == null || _checkingStatus || !mounted) return;
    _checkingStatus = true;
    try {
      final rows = await Supabase.instance.client.rpc('gs_customer_call_status',params: {
        'p_session_token': widget.visitSessionToken, 'p_call_id': callId,
      });
      if (mounted) {
        final nextStatus = (rows as List).isEmpty
          ? 'unavailable' : (rows.first as Map)['status'].toString();
        setState(() { status = nextStatus; error = null;
          employeeAssigned = rows.isNotEmpty && (rows.first as Map)['employee_assigned'] == true; });
        if (nextStatus == 'completed' || nextStatus == 'cancelled' ||
            nextStatus == 'unavailable') _statusPoll?.cancel();
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Status unavailable. Try again.');
    } finally { _checkingStatus = false; }
  }

  @override
  void dispose() { _statusPoll?.cancel(); note.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Call an employee')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      if (widget.visitSessionToken == null)
        const Card(child: ListTile(leading: Icon(Icons.lock_outline),
          title: Text('Staff-authorized table visit required'),
          subtitle: Text('Ask staff to activate your visit before calling.'))),
      if (callId == null) ...[
        const Text('Who can help you?'),
        DropdownButtonFormField<String>(value: type,
          items: const [
            DropdownMenuItem(value:'waiter',child:Text('Waiter')),
            DropdownMenuItem(value:'cashier',child:Text('Cashier / Bill')),
            DropdownMenuItem(value:'shisha',child:Text('Shisha staff')),
            DropdownMenuItem(value:'supervisor',child:Text('Supervisor')),
            DropdownMenuItem(value:'any',child:Text('Any available employee')),
            DropdownMenuItem(value:'specific_order',child:Text('Specific order / item request')),
            DropdownMenuItem(value:'pricing_request',child:Text('Pricing question / incorrect price')),
            DropdownMenuItem(value:'extra_chairs',child:Text('Extra chairs')),
            DropdownMenuItem(value:'long_wait',child:Text('Long wait / delayed order')),
            DropdownMenuItem(value:'pick_dishes',child:Text('Pick up used dishes')),
            DropdownMenuItem(value:'clean_table',child:Text('Clean our table')),
          ], onChanged:(v) => setState(() => type=v ?? 'waiter')),
        if (type == 'extra_chairs') Row(children: [
          const Expanded(child: Text('Number of extra chairs')),
          IconButton(onPressed: chairCount > 1 ? () => setState(() => chairCount--) : null,
            icon: const Icon(Icons.remove_circle_outline)),
          Text('$chairCount'),
          IconButton(onPressed: chairCount < 10 ? () => setState(() => chairCount++) : null,
            icon: const Icon(Icons.add_circle_outline)),
        ]),
        TextField(controller:note,maxLength:300,maxLines:3,
          decoration:InputDecoration(labelText: type == 'pricing_request' ? 'Product and pricing question (required)' : type == 'specific_order' ? 'Describe your order / item (required)' : type == 'long_wait' ? 'Which order is delayed? (optional)' : type == 'pick_dishes' ? 'Which dishes should we collect? (optional)' : 'Additional details (optional)')),
        FilledButton.icon(onPressed:widget.visitSessionToken == null || busy ? null : send,
          icon:const Icon(Icons.notifications_active),label:const Text('Call employee')),
      ] else ...[
        ListTile(leading:const Icon(Icons.check_circle_outline),
          title:Text('Request: $status'),
          subtitle:const Text('Your request is linked to this table visit. Status refreshes automatically every 8 seconds.')),
        if (employeeAssigned) const Text('An employee has been assigned to your request.'),
        if (status == 'accepted') const Text('An employee accepted your request.'),
        if (status == 'on_way') const Text('An employee is on the way to your table.'),
        if (status == 'completed') const Text('Your request was marked complete.'),
        if (status == 'waiting')
          OutlinedButton.icon(
            onPressed: busy ? null : cancelWaitingRequest,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel request'),
          ),
        OutlinedButton.icon(onPressed:busy ? null : refresh,
          icon:const Icon(Icons.refresh),label:const Text('Refresh status')),
        if (status == 'completed' || status == 'cancelled' || status == 'unavailable')
          FilledButton.icon(
            onPressed: () => setState(() {
              _statusPoll?.cancel(); callId = null; status = null; error = null; note.clear();
            }),
            icon: const Icon(Icons.add_alert_outlined),
            label: const Text('Make another request'),
          ),
      ],
      if (error != null) Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
    ]),
  );
}
