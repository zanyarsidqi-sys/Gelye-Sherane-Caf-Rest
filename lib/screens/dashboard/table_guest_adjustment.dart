import 'package:flutter/material.dart';

/// Draft request only. A caller must validate capacity, authorization and
/// persist the change transactionally on the server before updating totals.
@immutable
class TableGuestAdjustmentRequest {
  const TableGuestAdjustmentRequest({
    required this.additionalGuests,
    required this.additionalChairs,
    required this.optionalNames,
  });
  final int additionalGuests;
  final int additionalChairs;
  final List<String?> optionalNames;
}

class TableGuestAdjustment extends StatefulWidget {
  const TableGuestAdjustment({super.key, required this.onSubmit,
    this.maximumAdditionalGuests = 30, this.maximumAdditionalChairs = 30});
  final ValueChanged<TableGuestAdjustmentRequest> onSubmit;
  final int maximumAdditionalGuests;
  final int maximumAdditionalChairs;

  @override
  State<TableGuestAdjustment> createState() => _TableGuestAdjustmentState();
}

class _TableGuestAdjustmentState extends State<TableGuestAdjustment> {
  int _guests = 0;
  int _chairs = 0;
  final List<TextEditingController> _names = [];

  void _changeGuests(int value) {
    final next = value.clamp(0, widget.maximumAdditionalGuests);
    setState(() {
      while (_names.length < next) { _names.add(TextEditingController()); }
      while (_names.length > next) { _names.removeLast().dispose(); }
      _guests = next;
    });
  }

  @override
  void dispose() {
    for (final c in _names) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Customers joining later', style: Theme.of(context).textTheme.titleMedium),
      Row(children: [
        IconButton(onPressed: _guests > 0 ? () => _changeGuests(_guests - 1) : null,
          icon: const Icon(Icons.remove_circle_outline)),
        Text('$_guests additional customers'),
        IconButton(onPressed: _guests < widget.maximumAdditionalGuests
          ? () => _changeGuests(_guests + 1) : null,
          icon: const Icon(Icons.add_circle_outline)),
      ]),
      for (var i = 0; i < _guests; i++)
        TextField(controller: _names[i], maxLength: 100,
          decoration: InputDecoration(labelText: 'New customer ${i + 1} name (optional)')),
      const SizedBox(height: 8),
      Text('Extra chairs (separate from customer count)',
        style: Theme.of(context).textTheme.titleMedium),
      Row(children: [
        IconButton(onPressed: _chairs > 0 ? () => setState(() => _chairs--) : null,
          icon: const Icon(Icons.remove_circle_outline)),
        Text('$_chairs extra chairs'),
        IconButton(onPressed: _chairs < widget.maximumAdditionalChairs
          ? () => setState(() => _chairs++) : null,
          icon: const Icon(Icons.add_circle_outline)),
      ]),
      const Text('Existing orders, paid amounts and guest identities must remain unchanged.'),
      FilledButton(
        onPressed: _guests == 0 && _chairs == 0 ? null : () {
          widget.onSubmit(TableGuestAdjustmentRequest(
            additionalGuests: _guests,
            additionalChairs: _chairs,
            optionalNames: [for (final c in _names)
              c.text.trim().isEmpty ? null : c.text.trim()],
          ));
        },
        child: const Text('Request table update'),
      ),
    ],
  );
}
