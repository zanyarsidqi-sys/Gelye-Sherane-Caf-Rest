import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffTableOrderRequestsScreen extends StatefulWidget {
  const StaffTableOrderRequestsScreen({super.key});

  @override
  State<StaffTableOrderRequestsScreen> createState() =>
      _StaffTableOrderRequestsScreenState();
}

class _StaffTableOrderRequestsScreenState
    extends State<StaffTableOrderRequestsScreen> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _requests = [];
  final Set<String> _busyRequests = {};

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_staff_list_customer_table_order_requests',
      );
      if (!mounted) return;
      setState(() => _requests = (result as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList());
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not load guest requests. Check Table Orders access and try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept(Map<String, dynamic> request) async {
    final id = request['request_id'].toString();
    final items = (request['items'] as List? ?? const []);
    final itemSummary = items.map((item) {
      final line = Map<String, dynamic>.from(item as Map);
      final instructions = line['instructions']?.toString().trim() ?? '';
      return '${line['quantity']} × ${line['product_name']}'
          '${instructions.isEmpty ? '' : '\n  Note: $instructions'}';
    }).join('\n');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Accept table order request?'),
        content: Text(
          '$itemSummary\n\nAcceptance creates a live table order with current '
          'server prices. The request does not become an order or kitchen ticket '
          'until you accept it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Accept and create order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyRequests.add(id));
    try {
      final orderId = await Supabase.instance.client.rpc(
        'gs_staff_accept_customer_table_order_request',
        params: {'p_request_id': id},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Accepted as table order #$orderId')),
        );
      }
      await refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not accept request. It may have changed or the table visit may have ended.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyRequests.remove(id));
    }
  }

  Future<void> _reject(Map<String, dynamic> request) async {
    final id = request['request_id'].toString();
    final controller = TextEditingController();
    String? validationError;
    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Decline table order request'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: controller,
                maxLength: 300,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Reason (required)',
                  errorText: validationError,
                ),
              ),
            ]),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.length < 3) {
                    setDialogState(() => validationError =
                        'Enter a reason of at least 3 characters.');
                    return;
                  }
                  Navigator.pop(dialogContext, text);
                },
                child: const Text('Decline request'),
              ),
            ],
          ),
        ),
      );
      if (reason == null || !mounted) return;
      setState(() => _busyRequests.add(id));
      await Supabase.instance.client.rpc(
        'gs_staff_reject_customer_table_order_request',
        params: {'p_request_id': id, 'p_reason': reason},
      );
      await refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not decline request. Refresh and check its current status.'),
          ),
        );
      }
    } finally {
      controller.dispose();
      if (mounted) setState(() => _busyRequests.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        ListTile(
          title: const Text('Customer table-order requests'),
          subtitle: const Text(
            'Review before creating a live order. Prices are recalculated by the server on acceptance.',
          ),
          trailing: IconButton(
            onPressed: _loading ? null : refresh,
            tooltip: 'Refresh requests',
            icon: const Icon(Icons.refresh),
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: _requests.isEmpty
              ? const Center(child: Text('No customer table-order requests'))
              : ListView.builder(
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    final id = request['request_id'].toString();
                    final items = (request['items'] as List? ?? const []);
                    final visitOpen = request['visit_open'] == true;
                    final busy = _busyRequests.contains(id);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${request['floor_name']} · Table ${request['table_number']}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'Visit #${request['visit_id']} · '
                              '${request['submitted_at']}',
                            ),
                            for (final item in items)
                              Builder(builder: (context) {
                                final line = Map<String, dynamic>.from(item as Map);
                                final instructions =
                                    line['instructions']?.toString().trim() ?? '';
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    '${line['quantity']} × ${line['product_name']}',
                                  ),
                                  subtitle: instructions.isEmpty
                                      ? null
                                      : Text('Preparation note: $instructions'),
                                );
                              }),
                            if (!visitOpen)
                              const Text(
                                'This visit has ended. The request cannot be accepted.',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            Wrap(spacing: 8, children: [
                              FilledButton.icon(
                                onPressed: busy || !visitOpen
                                    ? null
                                    : () => _accept(request),
                                icon: busy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.check),
                                label: const Text('Accept'),
                              ),
                              OutlinedButton.icon(
                                onPressed: busy ? null : () => _reject(request),
                                icon: const Icon(Icons.close),
                                label: const Text('Decline'),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]);
}
