# Dashboard coding upgrade 25 — Drag-and-drop KPI personalization

## Implemented
- Added `ReorderableListView.builder` for authorized, visible KPI cards in Dashboard edit mode.
- Drag handle for touch/mouse; arrow buttons remain available for accessible reordering.
- Per-card color palette accessible from the editor list as well as each KPI card.
- Persisted card ordering/colors using existing employee-specific local SharedPreferences.
- No new financial data or permissions are fabricated; this changes presentation only.

## Limitations / next
- Only KPI cards with stable metric keys are draggable; special cards and Live Table Map are not yet in the unified editor.
- Card resizing, cloud preference sync, full eight operational areas, audit persistence and AI are pending.
- Flutter analyzer, device rendering and Supabase testing deferred until PC is available.
