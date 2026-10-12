# Upgrade 1276 — Dashboard business-day request consistency

- Pin both overview and weekly Supabase RPCs to the business day captured when refresh starts.
- Preserve queued follow-up refresh when the selected day changes while a request is running.
- Preserve permissions, existing UI, retry and error states.
- Verification: static assertions and ZIP integrity. Flutter compile and live Supabase tests not run.
