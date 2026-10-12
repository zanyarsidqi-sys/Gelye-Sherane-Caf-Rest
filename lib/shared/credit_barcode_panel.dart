import 'package:flutter/material.dart';
import 'credit_draft_validation.dart';
import 'credit_submission_gate.dart';

/// Local review only. No customer lookup, withdrawal request or debit occurs.
class CreditBarcodePanel extends StatefulWidget {
  const CreditBarcodePanel({super.key});

  @override
  State<CreditBarcodePanel> createState() => _CreditBarcodePanelState();
}

class _CreditBarcodePanelState extends State<CreditBarcodePanel> {
  final _formKey = GlobalKey<FormState>();
  final _barcode = TextEditingController();
  final _order = TextEditingController();
  final _amount = TextEditingController();
  String _source = 'Table Order';
  String _tableMode = 'Normal';
  bool _reviewReady = false;

  @override
  void dispose() {
    _barcode.dispose();
    _order.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _invalidate() {
    if (_reviewReady) setState(() => _reviewReady = false);
  }

  void _review() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _reviewReady = true);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Credit by customer barcode',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('Prepare and review a credit payment. This screen never charges a customer or creates a withdrawal request.'),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          onChanged: _invalidate,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Table Order', label: Text('Table Order')),
                  ButtonSegment(value: 'Motel Order', label: Text('Motel Order')),
                ],
                selected: {_source},
                onSelectionChanged: (value) => setState(() {
                  _source = value.first;
                  _reviewReady = false;
                }),
              ),
              const SizedBox(height: 12),
              if (_source == 'Table Order')
                DropdownButtonFormField<String>(
                  initialValue: _tableMode,
                  decoration: const InputDecoration(labelText: 'Table pricing mode', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'Tourism', child: Text('Tourism')),
                  ],
                  onChanged: (value) => setState(() {
                    _tableMode = value ?? 'Normal';
                    _reviewReady = false;
                  }),
                ),
              if (_source == 'Motel Order')
                const ListTile(
                  leading: Icon(Icons.hotel_outlined),
                  title: Text('Tourism pricing required'),
                  subtitle: Text('Motel Orders cannot use Normal prices.'),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _order,
                validator: CreditDraftValidation.requiredText,
                decoration: const InputDecoration(labelText: 'Order ID', border: OutlineInputBorder(), prefixIcon: Icon(Icons.receipt_long_outlined)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _barcode,
                validator: CreditDraftValidation.requiredText,
                decoration: const InputDecoration(labelText: 'Customer barcode', helperText: 'Scan or type barcode; account lookup is not connected', border: OutlineInputBorder(), prefixIcon: Icon(Icons.qr_code_scanner)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                validator: CreditDraftValidation.amountIqd,
                decoration: const InputDecoration(labelText: 'Order amount (IQD)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.payments_outlined)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _review,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Review local draft'),
              ),
            ],
          ),
        ),
        if (_reviewReady) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Draft only — NOT submitted', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Source: $_source'),
                  Text('Pricing mode: ${CreditDraftValidation.effectiveMode(_source, _tableMode)}'),
                  Text('Order ID: ${_order.text.trim()}'),
                  Text('Barcode: ${CreditDraftValidation.maskedBarcode(_barcode.text)}'),
                  Text('Requested amount: ${_amount.text.trim()} IQD'),
                  const SizedBox(height: 12),
                  const Text('Customer name, credit type, available balance and account status: NOT VERIFIED.'),
                  const SizedBox(height: 8),
                  const Text('Before withdrawal submission can be enabled:'),
                  const SizedBox(height: 6),
                  ...CreditSubmissionGate.requiredChecks.map(
                    (check) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lock_outline, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(check)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: null,
          icon: Icon(Icons.lock_outline),
          label: Text('Submit withdrawal — secure backend required'),
        ),
      ],
    );
  }
}
