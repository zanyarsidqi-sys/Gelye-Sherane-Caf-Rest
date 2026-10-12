# Upgrade 1207 — Delivery priority and employee names

The Kitchen correction panel now calls `gs_replacement_delivery_priority_inbox(15)` instead of the earlier replacement-delivery listing. The RPC returns the assigned employee's name from `employee_profiles`, permission-filtered by existing station access rules. Results are ordered by overdue, unassigned, awaiting acceptance, awaiting pickup, then out-for-delivery, with oldest ready tickets first. The interface displays status, elapsed minutes, employee name, and an overdue/assignment chip.

No direct table read grants were added. No customer invoices, payments, or waste entries are modified. Polling remains 15 seconds while open. Flutter compilation and live Supabase migration testing are intentionally deferred.
