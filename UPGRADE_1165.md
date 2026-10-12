# Upgrade 1165 — Recheck Kitchen order and items

Added a per-order **Recheck order and items** action to the live Kitchen queue.
It refreshes the authoritative queue and invalidates cached item previews
instead of trusting an old expansion-tile snapshot after another employee
changes an order. It is disabled during an active confirmation or RPC.

Visual Studio/Flutter and Supabase live tests are deferred. This does not
constitute Section 05 production acceptance.
