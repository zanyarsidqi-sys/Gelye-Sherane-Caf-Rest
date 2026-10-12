import 'package:flutter/material.dart';

@immutable
class TableGuest {
  const TableGuest({required this.position, this.name});
  final int position;
  final String? name;
}

@immutable
class TableGuestEntryResult {
  const TableGuestEntryResult({required this.guests});
  final List<TableGuest> guests;
  int get guestCount => guests.length;
}

/// Reusable UI for table opening. Names are optional, guest count is required.
/// The calling order service must persist this atomically and enforce capacity.
class TableGuestEntry extends StatefulWidget {
  const TableGuestEntry({super.key, required this.onContinue,
    this.initialCount = 1, this.maximumGuests = 100});
  final ValueChanged<TableGuestEntryResult> onContinue;
  final int initialCount;
  final int maximumGuests;
  @override
  State<TableGuestEntry> createState() => _TableGuestEntryState();
}

class _TableGuestEntryState extends State<TableGuestEntry> {
  late int _count = widget.initialCount.clamp(1, widget.maximumGuests);
  final Map<int, TextEditingController> _names = {};

  @override
  void dispose() {
    for (final controller in _names.values) { controller.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Number of customers (required)',
        style: Theme.of(context).textTheme.titleMedium),
      Row(children: [
        IconButton(onPressed: _count > 1 ? () => setState(() => _count--) : null,
          icon: const Icon(Icons.remove_circle_outline)),
        Text('$_count'),
        IconButton(onPressed: _count < widget.maximumGuests
          ? () => setState(() => _count++) : null,
          icon: const Icon(Icons.add_circle_outline)),
      ]),
      for (var i = 1; i <= _count; i++)
        Padding(padding: const EdgeInsets.symmetric(vertical: 4),
          child: TextField(
            controller: _names.putIfAbsent(i, () => TextEditingController()),
            maxLength: 100,
            decoration: InputDecoration(
              labelText: 'Customer $i name (optional)',
              border: const OutlineInputBorder(),
            ),
          )),
      FilledButton(onPressed: () {
        widget.onContinue(TableGuestEntryResult(guests: [
          for (var i = 1; i <= _count; i++)
            TableGuest(position: i,
              name: (_names[i]?.text.trim().isEmpty ?? true)
                ? null : _names[i]!.text.trim()),
        ]));
      }, child: const Text('Continue to order')),
    ],
  );
}
