# Upgrade 346 — Staff-managed scheduled meal fulfillment

Added permission-checked, serialized status transitions confirmed → scheduled → preparing → ready → on_way → delivered, audited using the existing meal audit table. The employee screen shows the next permitted action. Rejected/cancelled/delivered requests cannot advance. This is **manual staff status tracking**, not kitchen dispatch, delivery verification, or financial settlement. Live Supabase and Flutter testing are pending. Section 04 estimate: 43% (unverified).
