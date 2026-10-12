# Upgrade 229 — Preparation stations and deterministic order ticket routing

Added preparation stations, menu-product station mappings, one active online target (POS OR printer) per station, an offline-local-printer configuration field, and station-specific order ticket/item records.

`gs_route_confirmed_order(order_id)` is a protected, explicit, idempotent staging RPC for accepted orders. It rejects unmapped items and disabled destinations and creates one ticket per station, with only that station's items. It does NOT automatically run on order confirmation yet; connecting the correct authoritative acceptance transaction is the next step. No SUNMI driver, print gateway, offline storage or physical delivery is present.

**Migration caution:** apply in chronological order, test with a real Supabase database. This is not a live-tested deployment. Product mappings and stations must be configured before dispatch. Existing routing policy's `both` mode is legacy and is not used for these new station tickets.
