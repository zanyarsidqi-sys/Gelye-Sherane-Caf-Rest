import 'package:flutter/material.dart';

/// Local-only preview. Never applies discounts or modifies order totals.
class DiscountPlannerPanel extends StatefulWidget {
  const DiscountPlannerPanel({super.key});

  @override
  State<DiscountPlannerPanel> createState() => _DiscountPlannerPanelState();
}

class _DiscountPlannerPanelState extends State<DiscountPlannerPanel> {
  final _price = TextEditingController();
  final _percent = TextEditingController();
  final _minimum = TextEditingController();
  String _mode = 'Normal';

  @override
  void dispose() {
    _price.dispose();
    _percent.dispose();
    _minimum.dispose();
    super.dispose();
  }

  double? _number(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', ''));

  @override
  Widget build(BuildContext context) {
    final price = _number(_price);
    final percent = _number(_percent);
    final minimum = _minimum.text.trim().isEmpty ? 0.0 : _number(_minimum);
    final valid = price != null && price > 0 && price.isFinite &&
        percent != null && percent >= 0 && percent <= 100 && percent.isFinite &&
        minimum != null && minimum >= 0 && minimum.isFinite && minimum <= price;
    final discount = valid ? price * percent / 100 : 0.0;
    final after = valid ? price - discount : 0.0;
    final allowed = valid && after >= minimum;
    String iq(double value) => '${value.toStringAsFixed(0)} IQD';

    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Discount planning',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Preview only. No discount is saved, approved, or applied to an order.'),
      const SizedBox(height: 16),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'Normal', label: Text('Normal')),
          ButtonSegment(value: 'Tourism', label: Text('Tourism')),
        ],
        selected: {_mode},
        onSelectionChanged: (values) => setState(() => _mode = values.first),
      ),
      const SizedBox(height: 12),
      Text('Enter the $_mode selling price for this calculation. '
          'Motel Orders must always use Tourism prices.'),
      const SizedBox(height: 12),
      TextField(controller: _price, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Selling price (IQD)', border: OutlineInputBorder()),
          onChanged: (_) => setState(() {})),
      const SizedBox(height: 12),
      TextField(controller: _percent, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Proposed discount (%)', border: OutlineInputBorder()),
          onChanged: (_) => setState(() {})),
      const SizedBox(height: 12),
      TextField(controller: _minimum, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Minimum permitted final price (IQD, optional)', border: OutlineInputBorder()),
          onChanged: (_) => setState(() {})),
      const SizedBox(height: 16),
      if (!valid)
        const Text('Enter a positive price, discount from 0–100%, and a valid minimum final price.'),
      if (valid) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Original: ${iq(price)}'),
          Text('Discount: ${iq(discount)}'),
          Text('Final price: ${iq(after)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(allowed ? 'Within entered minimum price' : 'Below entered minimum price — reject',
              style: TextStyle(color: allowed ? Colors.green : Colors.red)),
        ],
      ))),
      const SizedBox(height: 12),
      const Text('This check is not an authorization decision. Production discounts require '
          'server-enforced pricing rules, role checks, approval workflow, and audit history.'),
    ]);
  }
}
