# Upgrade 215 — Manager service duration reporting

Section 02 — Tables: added a manager-only read-only service-duration report with 7/30/90-day periods. It shows completed jobs grouped by employee, elapsed creation-to-claim response minutes, claim-to-completion service minutes, and whether a due date was missed. Missing timestamps produce N/A, not fabricated measurements. Query is restricted to `tables.can_edit`, capped at 500 recent completed jobs, and does not change any job/payment state.

Tables progress: 89% estimated. Customers: 45%, paused. ZIP integrity checked; Flutter compilation and live Supabase migration testing not performed.
