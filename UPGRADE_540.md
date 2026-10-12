# Upgrade 540 — Failed kitchen revision recovery

Adds a kitchen-permission-gated RPC to requeue only failed, unacknowledged product-replacement kitchen revision messages, with mandatory reason and immutable retry audit. Staff UI displays acknowledgement timestamp and a reasoned retry action for failed kitchen revisions. Retry is **queue recovery only**, not proof of delivery, printing or kitchen acknowledgement. Existing 539 acknowledgement and payment safeguards remain unchanged.

Deployment: apply migration 540 after all prior migrations; ensure a trusted external worker consumes pending revision messages. No worker is added by this upgrade.

Verification: ZIP and source static checks only. Flutter compilation and live Supabase testing not performed.
