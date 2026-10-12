import 'package:flutter/material.dart';

/// Presentation-only section summary; never queries or bypasses permissions.
class ProfessionalSectionSummary extends StatelessWidget {
  const ProfessionalSectionSummary({super.key, required this.title,
    required this.subtitle, required this.icon, required this.items});
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> items;
  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF12243C);
    const gold = Color(0xFFD8AB55);
    return Semantics(
      container: true,
      label: "$title. $subtitle. ${items.join(', ')}",
      child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: gold, size: 27), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: Color(0xFFCFD7E4), fontSize: 13)),
            ]))]),
          const SizedBox(height: 12),
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (final item in items) Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(color: const Color(0xFF263C56), borderRadius: BorderRadius.circular(12)),
              child: Text(item, softWrap: true, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ]),
        ]),
      ),
    ));
  }
}
