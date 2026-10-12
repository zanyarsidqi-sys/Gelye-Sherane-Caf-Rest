import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/station_print_review_service.dart';

/// Employee-authenticated, server-authorized review of uncertain print jobs.
/// Never embed this panel in station-device-only authentication.
class StationPrintReviewPanel extends StatefulWidget {
  const StationPrintReviewPanel({super.key});
  @override
  State<StationPrintReviewPanel> createState() => _StationPrintReviewPanelState();
}

class _StationPrintReviewPanelState extends State<StationPrintReviewPanel> {
  late final StationPrintReviewService _service =
      StationPrintReviewService(Supabase.instance.client);
  List<Map<String, dynamic>> _pending = [];
  bool _loading = false;
  String? _error;
  int _reviewGeneration = 0;
  String? _reviewEmployeeId;
  StreamSubscription<AuthState>? _authSubscription;
  bool _submitting = false;
  bool _sameEmployee(String id) =>
      Supabase.instance.client.auth.currentUser?.id == id &&
      _reviewEmployeeId == id;
  @override void dispose() {
    _reviewGeneration++;
    _authSubscription?.cancel();
    super.dispose();
  }
  @override
  void initState() {
    super.initState();
    _reviewEmployeeId = Supabase.instance.client.auth.currentUser?.id;
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      final current = Supabase.instance.client.auth.currentUser?.id;
      if (!mounted || current == _reviewEmployeeId) return;
      // Never show the previous employee's station-scoped review records.
      _reviewGeneration++;
      setState(() {
        _reviewEmployeeId = current;
        _pending = [];
        _error = null;
        _loading = false;
      });
      if (current != null) _refresh();
    });
    _refresh();
  }

  Future<void> _refresh() async {
    if (_loading || _submitting) return;
    final employeeId = Supabase.instance.client.auth.currentUser?.id;
    final generation = ++_reviewGeneration;
    _reviewEmployeeId = employeeId;
    setState(() { _loading = true; _error = null; _pending = []; });
    try {
      if (employeeId == null) throw StateError('Employee login required');
      final rows = await _service.pendingReviews();
      if (!mounted || generation != _reviewGeneration ||
          employeeId != Supabase.instance.client.auth.currentUser?.id) return;
      setState(() => _pending = rows);
    } catch (_) {
      if (mounted && generation == _reviewGeneration &&
          employeeId == Supabase.instance.client.auth.currentUser?.id) {
        setState(() { _pending = []; _error =
          'Unable to load authorized print reviews. Check supervisor permissions.'; });
      }
    } finally {
      if (mounted && generation == _reviewGeneration) setState(() => _loading = false);
    }
  }

  Future<void> _review(Map<String, dynamic> ticket) async {
    final employeeId = Supabase.instance.client.auth.currentUser?.id;
    if (employeeId == null || _loading || _submitting || !_sameEmployee(employeeId)) return;
    final lease = DateTime.tryParse(ticket['lease_expires_at']?.toString() ?? '');
    // Fail closed when the lease expiry is absent or malformed.
    if (lease == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Print lease information unavailable. Refresh before reviewing.')));
      return;
    }
    if (lease.isAfter(DateTime.now().toUtc())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Printing lease is still active. Review after it expires.')));
      return;
    }
    final explanation = TextEditingController();
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(context: context, builder: (ctx) =>
        AlertDialog(
          title: const Text('Verify physical print outcome'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Station: ${ticket['station_key']}'),
              Text('Queue: ${ticket['queue_kind']}'),
              Text('Ticket: ${ticket['ticket_id']} · Attempt: ${ticket['attempt']}'),
              const SizedBox(height: 12),
              const Text('Check the printer and paper before recording a decision. '
                'This will not automatically reprint or change a customer bill.'),
              TextField(controller: explanation, minLines: 2, maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(labelText: 'Verification explanation (10+ characters)')),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(onPressed: () {
              if (explanation.text.trim().length < 10) return;
              Navigator.pop(ctx, false);
            }, child: const Text('Confirmed NOT printed')),
            FilledButton(onPressed: () {
              if (explanation.text.trim().length < 10) return;
              Navigator.pop(ctx, true);
            }, child: const Text('Confirmed printed')),
          ],
        ));
      if (confirmed == null || !mounted || !_sameEmployee(employeeId)) return;
      // A decision is bound to the current employee and current queue generation.
      final decisionGeneration = _reviewGeneration;
      setState(() { _loading = true; _submitting = true; });
      // New key for a new user decision; server rejects contradictory duplicates.
      final key = _newUuidV4();
      try {
        await _service.submitReview(
          queueKind: ticket['queue_kind'].toString(),
          ticketId: (ticket['ticket_id'] as num).toInt(),
          attempt: (ticket['attempt'] as num).toInt(),
          physicallyConfirmedPrinted: confirmed,
          explanation: explanation.text.trim(),
          uniqueRequestKey: key,
        );
        if (mounted && _sameEmployee(employeeId) &&
            decisionGeneration == _reviewGeneration) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Review saved. No automatic reprint requested.')));
        }
      } catch (_) {
        if (mounted && _sameEmployee(employeeId) &&
            decisionGeneration == _reviewGeneration) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Review not confirmed. Refresh status before trying again.')));
        }
      } finally {
        _submitting = false;
        if (mounted && decisionGeneration == _reviewGeneration &&
            _sameEmployee(employeeId)) setState(() => _loading = false);
      }
      if (mounted && _sameEmployee(employeeId) &&
          decisionGeneration == _reviewGeneration) await _refresh();
    } finally { explanation.dispose(); }
  }

  // UUIDv4 from a cryptographically secure RNG, not timestamps or ticket IDs.
  String _newUuidV4() {
    final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final s = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${s.substring(0,8)}-${s.substring(8,12)}-${s.substring(12,16)}-${s.substring(16,20)}-${s.substring(20)}';
  }
  static final _secureRandom = Random.secure();

  @override Widget build(BuildContext context) => Column(children: [
    ListTile(title: const Text('Uncertain printer outcomes'),
      subtitle: const Text('Supervisor-only · station-scoped · no automatic reprints'),
      trailing: IconButton(onPressed: _loading ? null : _refresh,
        icon: const Icon(Icons.refresh), tooltip: 'Refresh')),
    if (_loading) const LinearProgressIndicator(),
    if (_error != null) Padding(padding: const EdgeInsets.all(12),
      child: Text(_error!, style: const TextStyle(color: Colors.red))),
    Expanded(child: _pending.isEmpty
      ? const Center(child: Text('No authorized uncertain print tickets to review.'))
      : ListView.builder(itemCount: _pending.length, itemBuilder: (context, i) {
        final t = _pending[i];
        final lease = DateTime.tryParse(t['lease_expires_at']?.toString() ?? '');
        final active = lease != null && lease.isAfter(DateTime.now().toUtc());
        return Card(child: ListTile(
          leading: Icon(t['queue_kind'] == 'revision'
            ? Icons.edit_note : Icons.receipt_long),
          title: Text('${t['station_key']} · ${t['queue_kind']} #${t['ticket_id']}'),
          subtitle: Text('Attempt ${t['attempt']} · '
            '${active ? 'Active lease; wait before review' : 'Ready for physical verification'}'),
          trailing: OutlinedButton(onPressed: (_loading || active) ? null : () => _review(t),
            child: const Text('Review')),
        ));
      })),
  ]);
}
