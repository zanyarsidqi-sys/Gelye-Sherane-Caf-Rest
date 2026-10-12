import 'package:flutter/material.dart';

/// Read-only dashboard map. The server must return only tables visible to the
/// authenticated employee. No guest names or balances are invented locally.
class LiveTableMap extends StatelessWidget {
  const LiveTableMap({super.key, required this.rows, required this.onTableTap});
  final List<Map<String, dynamic>> rows;
  final ValueChanged<Map<String, dynamic>> onTableTap;

  Color _statusColor(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'occupied': return Colors.orange;
      case 'reserved': return Colors.blue;
      case 'cleaning':
      case 'cleaning_needed':
      case 'needs_cleaning': return Colors.purple;
      case 'available': return Colors.green;
      default: return Theme.of(context).colorScheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Live Table Map', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text('Select a table for guest count, orders and payment details.'),
        const SizedBox(height: 12),
        if (rows.isEmpty) const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text('No authorized table-map data available. Configure the table map endpoint to display live tables.'),
        ) else LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 700 ? 6 : constraints.maxWidth >= 420 ? 4 : 2;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns, mainAxisSpacing: 8, crossAxisSpacing: 8,
              childAspectRatio: 1.25,
            ),
            itemBuilder: (context, index) {
              final table = rows[index];
              final status = (table['status'] ?? 'unknown').toString();
              final label = (table['label'] ?? table['number'] ?? 'Table').toString();
              final guests = table['guest_count'];
              return Material(
                color: _statusColor(context, status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onTableTap(table),
                  child: Padding(padding: const EdgeInsets.all(8), child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.table_restaurant_outlined),
                      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall),
                      Text(status, style: Theme.of(context).textTheme.labelSmall),
                      if (status.toLowerCase().contains('clean'))
                        const Icon(Icons.cleaning_services_outlined, size: 17),
                      if (guests is num) Text('${guests.toInt()} guests',
                        style: Theme.of(context).textTheme.labelSmall),
                    ],
                  )),
                ),
              );
            },
          );
        }),
      ],
    )),
  );
}
