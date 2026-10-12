import 'package:flutter/material.dart';

/// Dashboard customer summary. Null means the backend did not supply an
/// authorized value; it must never be displayed as zero.
class CustomerCountCard extends StatelessWidget {
  const CustomerCountCard({super.key, required this.title, required this.count,
    required this.onTap});
  final String title;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: onTap, child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.groups_outlined),
          const SizedBox(height: 12),
          Text(title, maxLines: 2),
          const SizedBox(height: 6),
          Text(count?.toString() ?? '—',
            style: Theme.of(context).textTheme.titleLarge),
          Text(count == null ? 'Awaiting authorized data' : 'View details →',
            style: Theme.of(context).textTheme.labelSmall),
        ]),
    )),
  );
}
