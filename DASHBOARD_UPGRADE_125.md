# Dashboard Upgrade 125 — Stop unlinked legacy orders bypassing checkout

**Concrete integration fix:** The cash-only release RPC counts visit-linked
orders and flags *existing* unlinked legacy orders, but an older order writer
could insert a new unlinked table order concurrently and escape the visit
checkout count. A new database trigger blocks new unlinked table orders for
canonical numeric table destinations. It locks the same physical table row
that checkout locks, serializing the operations. Existing legacy rows are
unchanged; they still require explicit reconciliation.

This is intentionally a breaking safety change for older order-creation
paths: they must use the visit-aware order RPC (Upgrade 51). Delivery and
motel destinations are not automatically assigned to tables.

**Known limitations:** Order writers with noncanonical destination values,
existing legacy unlinked orders, reservation conflicts, other payment methods,
and direct privileged database writes require separate validation. This is
source code only: ZIP verified, not deployed or tested against Supabase.
