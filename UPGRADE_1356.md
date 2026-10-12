# Upgrade 1356 — Itemized payment details (read-only)

Added permission-scoped Supabase RPCs `gs_finance_itemized_order_detail(bigint)` and `gs_finance_motel_request_detail(uuid)`. Returns itemized quantity, original unit price, line total, order-level timestamp, motel room, delivery assignment and status. Missing requested delivery time, individual customer and online contact/address are returned null rather than guessed. No payment mutations or new UI integration; the functions are backend building blocks for the two financial cards.

Apply migration only after staging schema and authorization review. Flutter integration and live Supabase execution remain unverified.
