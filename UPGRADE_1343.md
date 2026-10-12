# Upgrade 1343 — Pending Payment source and allocation evidence

- Added permission-gated, read-only `gs_financial_pending_allocation_diagnostics()` using actual UUID motel invoice, bridge, intent, plan and cash settlement tables.
- Added Flutter evidence inspection in Pending Payment, independent refresh and strict response validation.
- Explicitly blocks online source classification and all Pending Payment collection.
- Posted invoice total and confirmed cash settlement evidence are **not** a verified remaining balance; drafts are **not** payments.
- Preserved Standing Cash collection, Dashboard deep links and all previous files.
- Requires migration deployment, Flutter compilation and authorized live Supabase tests before production use.
