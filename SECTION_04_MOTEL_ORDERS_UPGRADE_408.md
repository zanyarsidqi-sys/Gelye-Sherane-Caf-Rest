# Upgrade 408 — Credit Evidence Review History Viewer

Adds a read-only Review History action for both pending and cancelled credit verification requests in the employee finance screen. Uses the existing permission-protected `gs_staff_list_motel_credit_review_events` RPC from Upgrade 407 and displays review type, note, employee identifier and timestamp. Preserves request cancellation and evidence review.

No new database migration is required. No authoritative ownership, balance, consent or debit verification is implemented. Credit settlement remains blocked. Flutter compilation and live Supabase testing were not performed.
