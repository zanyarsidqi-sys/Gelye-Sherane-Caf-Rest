# Upgrade 350 — Kitchen preparation controls

- Kitchen screen now supports approved motel meals: confirmed/scheduled → preparing → ready.
- Supabase RPC enforces Kitchen `can_edit`, row-locks the request, validates transitions, and writes the existing audit log.
- Delivery and room charges remain separate; these scheduled requests are not gs_orders tickets.
- Pending: live migration tests, Flutter build, automatic kitchen ticket dispatch, customer order tracking for ordinary meals.
- Section 04 progress: 47% estimated (not production-verified).
