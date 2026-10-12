# Dashboard Coding Upgrade 29 — KPI Detail Clarity

- Added per-metric descriptions in the Dashboard's existing iPhone full-screen / Windows right-side detail viewer.
- Clearly distinguishes urgent guest feedback from the full Action Center; the top-selling-product metric is a **single-product maximum**, not a total.
- Documents the provisional 30-minute overdue threshold and table occupancy denominator.
- Explicitly flags unavailable metrics rather than silently treating them as zero.
- Flags the four draft operational calculations as requiring Supabase migration and permission verification.
- Retains permission-checked navigation to the related management section and prohibits unsupported financial actions.

**Scope:** This is a concrete detail-view improvement, not completion of every record-level drill-down or all management actions. No new backend writes were added. Flutter compilation and Supabase tests remain deferred. Overall Phase 3 remains ~54% historical estimate.
