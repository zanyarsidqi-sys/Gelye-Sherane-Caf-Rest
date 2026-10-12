# Upgrade 543 — Kitchen revision exception triage

Section 03 Table Orders. Builds on 542 without changing Supabase schema or previously implemented authorization.

The revision dispatch dialog now summarizes kitchen replacement revisions, unresolved kitchen receipts, and failed kitchen dispatches separately from customer and employee notifications. Staff can filter to kitchen-only or awaiting-receipt items and refresh from the permission-protected backend. Failed revisions retain the existing audited retry action; kitchen staff retain the server-enforced acknowledgment flow. Acknowledgment does not mean printing, preparation, or delivery.

No SQL migration required. Counts represent the most recent RPC snapshot (maximum 250 dispatch records), not real-time push updates or a global kitchen queue. Use Refresh to reload.

Verification: ZIP integrity and static source checks only. Flutter compilation and live Supabase integration not performed.
