import 'package:flutter/material.dart';

/// Shared presentation only; capabilities and financial operations stay with
/// their existing workspaces and server endpoints.
class CafeFinanceSurface extends StatelessWidget {
  const CafeFinanceSurface({super.key, required this.builder});
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFF14243A);
    const ink = Color(0xFFF6F2E9);
    const border = Color(0xFF30435A);
    const gold = Color(0xFFD6AA57);
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: gold, surface: surface, onSurface: ink,
        error: Color(0xFFFFB4AB),
      ),
      textTheme: Theme.of(context).textTheme.apply(
        bodyColor: ink, displayColor: ink,
      ),
      cardTheme: CardThemeData(
        color: surface, elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
    return Theme(data: theme, child: Builder(builder: builder));
  }
}

String cafeFinanceTimestamp(dynamic value) {
  final parsed = DateTime.tryParse('$value');
  if (parsed == null) return '—';
  return parsed.toUtc().add(const Duration(hours: 3))
      .toIso8601String().substring(0, 19).replaceFirst('T', ' ');
}

/// Restricts journal presentation, not permissions or the server balance.
String? cafeCashEntryKind(String card) => switch (card) {
  'cash_in' => 'cash_in',
  'cash_out_owner' || 'owner_cash_out' => 'cash_out',
  'expenses' || 'expenses_management' || 'costs_expenses' ||
  'pending_expenses' => 'expense',
  _ => null,
};
