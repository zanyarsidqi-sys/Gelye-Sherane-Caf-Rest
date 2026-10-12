import 'package:flutter/material.dart';

/// Responsive presentation component. Does not fetch data or grant permissions.
class GelyeSectionHeader extends StatelessWidget {
  const GelyeSectionHeader({super.key, required this.title, required this.subtitle,
    this.icon = Icons.dashboard_rounded, this.actions = const []});
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Semantics(
      header: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 16 : 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF071D31), Color(0xFF123A54)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: const Color(0xFFD9A744), size: 27),
              const SizedBox(width: 12),
              Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: compact ? 19 : 24,
                      fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Color(0xFFD4DFE8), fontSize: 12)),
                ])),
            ]),
            if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
      ),
    );
  }
}
