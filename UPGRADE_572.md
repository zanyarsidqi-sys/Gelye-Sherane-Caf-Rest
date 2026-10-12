# Upgrade 572 — Kitchen receipt evidence for replacement recovery

Added a read-only Supabase RPC that links a committed replacement receipt to its exact kitchen revision and dispatch acknowledgment audit. It uses the existing kitchen revision reconciliation logic and requires both table-orders and kitchen view permissions. Returns `acknowledged_consistent`, `awaiting_kitchen_receipt`, `receipt_investigation`, or missing-evidence states. No automatic retries or financial settlement assertions. Flutter's request-ID lookup displays the result.

Deploy migration 572 after 571. Runtime Flutter compilation, live Supabase integration, and concurrency tests remain required.
