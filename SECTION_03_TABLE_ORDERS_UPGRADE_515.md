# Upgrade 515 — Staff order snapshot freshness guard

The Table Orders fulfillment board now refuses status transitions and instruction edits from a snapshot older than two minutes. An attempted action against stale data initiates a new permission-scoped board fetch; employees must review refreshed statuses and click again. Delivery confirmation also rechecks freshness after the confirmation dialog. A visible refresh action explains stale data. This is defense in depth alongside server-side permission and optimistic concurrency checks.

No quantity mutation or financial recalculation was introduced: those still require dedicated audited transactional RPCs.

Verification: static source assertions and ZIP integrity only. Flutter compilation and live Supabase checks were not performed.
