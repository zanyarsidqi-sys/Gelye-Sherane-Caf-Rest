# Dashboard Upgrade 1308

Section 01 only. Constrain the weekly cash breakdown's date and order-count label using Expanded > FittedBox(BoxFit.scaleDown) and maxLines: 1; add an 8px gap between date and amount. This prevents long order counts and large accessibility text from wrapping into tall rows on narrow iPhones. The enclosing Semantics label continues to expose full text. No changes to RPCs, permissions, accounting, or other sections.

Validation: ZIP integrity, unchanged-entry byte comparison, source assertions. Flutter/Dart SDK and live Supabase were not available for execution tests.
