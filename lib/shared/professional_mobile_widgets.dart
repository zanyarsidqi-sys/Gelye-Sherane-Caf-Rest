import 'package:flutter/material.dart';

/// Reusable responsive presentation. No network access or permission bypass.
abstract final class ProfessionalMobileWidgets {
  static const navy = Color(0xFF071D31);
  static const gold = Color(0xFFD9A744);

  static Widget heading(BuildContext context, {required String title,
      required String subtitle, IconData icon = Icons.restaurant_menu,
      Widget? trailing}) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    return Container(
      margin: EdgeInsets.only(bottom: mobile ? 12 : 18),
      padding: EdgeInsets.symmetric(horizontal: mobile ? 18 : 24, vertical: mobile ? 20 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [navy, Color(0xFF123A54)]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: gold.withOpacity(.14), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: gold, size: 26)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
            fontSize: mobile ? 19 : 24)),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: Color(0xFFD3E0EA), fontSize: 12)),
        ])),
        if (trailing != null) trailing,
      ]),
    );
  }

  /// Compact status strip: informational only; never represents an invented live value.
  static Widget operationalNotice(BuildContext context, {required String message,
      IconData icon = Icons.verified_user_outlined}) {
    return Semantics(
      label: message,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F8),
          border: Border.all(color: const Color(0xFFD5E1E9)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(icon, color: navy, size: 19),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(
            color: navy, fontSize: 12, fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }

  /// Responsive navigation to existing actions; never fetches or changes data itself.
  static Widget mobileActions(BuildContext context, {
    required List<(String, IconData, VoidCallback)> actions,
  }) {
    return Semantics(
      container: true,
      label: 'Quick actions',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final action in actions)
            OutlinedButton.icon(
              onPressed: action.$3,
              icon: Icon(action.$2, size: 18, color: gold),
              label: Text(action.$1, maxLines: 2, overflow: TextOverflow.ellipsis),
              style: OutlinedButton.styleFrom(
                foregroundColor: navy,
                minimumSize: const Size(112, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                side: const BorderSide(color: Color(0xFFB8C9D5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Presentation-only mobile workspace strip; no business values are inferred.
  static Widget workspaceIntro(BuildContext context, {
    required String eyebrow,
    required String title,
    required String description,
    IconData icon = Icons.dashboard_customize_outlined,
  }) {
    final narrow = MediaQuery.sizeOf(context).width < 390;
    return Semantics(
      container: true,
      label: '$eyebrow. $title. $description',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(narrow ? 14 : 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F8FA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE0E8EF)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: gold.withOpacity(.16), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: navy, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(eyebrow.toUpperCase(), style: const TextStyle(fontSize: 10, letterSpacing: 1.2,
              fontWeight: FontWeight.w800, color: Color(0xFF8A6B2B))),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: narrow ? 16 : 18,
              fontWeight: FontWeight.w800, color: navy)),
            const SizedBox(height: 5),
            Text(description, style: const TextStyle(fontSize: 12, height: 1.35,
              color: Color(0xFF536779))),
          ])),
        ]),
      ),
    );
  }

  /// Descriptive guide only; counts and order statuses come from existing RPCs.
  static Widget workspaceGuide(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    const items = <(String, IconData)>[
      ('Review orders', Icons.receipt_long_outlined),
      ('Update status', Icons.task_alt_outlined),
      ('Check bill', Icons.payments_outlined),
    ];
    return Semantics(
      container: true,
      label: 'Table Orders workflow: review orders, update status, check bill. Access depends on staff permissions.',
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: navy, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gold.withOpacity(.55)),
        ),
        child: Wrap(spacing: compact ? 8 : 16, runSpacing: 10, children: [
          for (final item in items)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(item.$2, size: 17, color: gold),
              const SizedBox(width: 5),
              Text(item.$1, style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
        ]),
      ),
    );
  }

  static Widget sectionLabel(String title, {String? caption}) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
    child: Row(children: [
      Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
      if (caption != null) Text(caption, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
    ]),
  );
}
