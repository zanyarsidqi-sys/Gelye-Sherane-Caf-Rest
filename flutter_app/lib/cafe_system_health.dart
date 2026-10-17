import 'dart:async';

import 'package:flutter/material.dart';

import 'cafe_finance_surface.dart';
import 'cafe_language.dart';
import 'cafe_operations_workspace.dart';

/// Observes authorized reads only. A successful read is not an uptime,
/// backup, security, printer, or offline-sync guarantee.
class CafeSystemHealth extends StatefulWidget {
  const CafeSystemHealth({
    super.key,
    required this.tables,
    required this.inventory,
    required this.account,
    this.rpc,
  });
  final bool tables, inventory;
  final String account;
  final CafeRpc? rpc;

  @override
  State<CafeSystemHealth> createState() => _CafeSystemHealthState();
}

class _CafeSystemHealthState extends State<CafeSystemHealth> {
  int _generation = 0;
  bool _running = false;
  Map<String, String> _results = {};
  String? _checkedAt;

  @override
  void didUpdateWidget(CafeSystemHealth oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account != widget.account ||
        oldWidget.tables != widget.tables ||
        oldWidget.inventory != widget.inventory ||
        oldWidget.rpc != widget.rpc) {
      _generation++;
      _running = false;
      _results = {};
      _checkedAt = null;
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _check() async {
    if (_running) return;
    final generation = ++_generation;
    final rpc = widget.rpc;
    final tables = widget.tables, inventory = widget.inventory;
    setState(() {
      _running = true;
      _results = {};
      _checkedAt = null;
    });
    Future<void> probe(String label, String name,
        Map<String, dynamic> params, String requiredList) async {
      final watch = Stopwatch()..start();
      String result;
      try {
        if (rpc == null) {
          result = 'Unavailable — connection is not configured.';
        } else {
          final data = await rpc(name, params).timeout(const Duration(seconds: 10));
          if (data is! Map || data[requiredList] is! List ||
              DateTime.tryParse('${data['server_time']}') == null) {
            result = 'Unexpected response — service could not be verified.';
          } else {
            result = 'Read succeeded · ${watch.elapsedMilliseconds} ms';
          }
        }
      } on TimeoutException {
        result = 'Timed out after 10 seconds — service state is unknown.';
      } catch (_) {
        result = 'Read failed — check connection, session, or assigned access.';
      }
      watch.stop();
      if (!mounted || generation != _generation) return;
      setState(() => _results[label] = result);
    }

    await Future.wait([
      if (tables) probe('Table service', 'get_cafe_table_overview', {}, 'tables'),
      if (inventory) probe('Inventory service', 'get_cafe_inventory_workspace',
          {'p_card': 'low_stock_alerts', 'p_query': ''}, 'items'),
    ]);
    if (!mounted || generation != _generation) return;
    setState(() {
      _running = false;
      _checkedAt = DateTime.now().toUtc().toIso8601String();
    });
  }

  Widget _service(String label, bool allowed) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CafeText(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        CafeText(!allowed ? 'Not checked — access has not been assigned.' :
            _results[label] ?? (_running ? 'Checking…' : 'Not checked yet.')),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) => CafeFinanceSurface(builder: (context) =>
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const CafeText('System Health', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const CafeText('Run a read-only check of the services you can access. Results describe this device at the time of the check.'),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 8, children: [
        FilledButton.icon(
          onPressed: _running || (!widget.tables && !widget.inventory) ? null : _check,
          icon: const Icon(Icons.refresh),
          label: CafeText(_running ? 'Checking services…' : 'Check services'),
        ),
        if (_checkedAt != null) CafeText('Checked ${cafeFinanceTimestamp(_checkedAt)} Baghdad · device clock'),
      ]),
      if (_running) const LinearProgressIndicator(),
      _service('Table service', widget.tables),
      _service('Inventory service', widget.inventory),
      const SizedBox(height: 12),
      const CafeText('A failed read does not prove an outage or that this device is offline. Results can change after this check.'),
      const SizedBox(height: 12),
      const CafeText('Not monitored here: CPU, memory, disk, printers, backup completion, restore tests, offline queues, or security audit status. Backup and sync status are unverified.'),
    ]),
  );
}
