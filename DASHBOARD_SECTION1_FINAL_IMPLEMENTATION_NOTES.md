# Dashboard Section 1 — final implementation pass (source)

This package builds on migrations 031–033 and adds 034.

## Added
- 30-second automatic polling with pause/resume and manual refresh.
- Permission-scoped low-stock and out-of-stock counters in action center.
- Seven-day cash receipt totals alongside order counts, scoped to authorized order types.
- Distinct order-value, cash-received, and outstanding-balance explanations.
- Responsive cards, date picker, navigation shortcuts, and no fabricated values.

## Important limitations and verification
- Auto-refresh is polling, not Supabase Realtime push; data can be up to 30 seconds old.
- Cash trend is not all-channel revenue and does not include credit/card settlement.
- Low stock uses active menu products with no stock row treated as zero; configure stock tracking for all relevant products.
- Section 1 cannot be called production verified until migrations are deployed, Flutter analyzer/build passes, and permission, accounting, mobile and Windows checks pass.
- Apply migration 034 only after 026 and 031–033.
- Run flutter pub get, flutter analyze, flutter run -d chrome; also test iPhone/Windows.
