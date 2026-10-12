# Upgrade 513 — Delivery confirmation guard

- Added an explicit confirmation dialog before the staff order board transitions an item from picked_up to delivered.
- Dialog identifies product, quantity, and table, and explains that fulfillment is not payment.
- Cancelling the dialog performs no mutation.
- Revalidates widget lifecycle, board availability, editing/transition locks, and current item status after confirmation.
- The existing server-side gs_advance_table_item_fulfillment RPC remains authoritative for permissions and concurrency.
- Does not change partial-quantity delivery workflows, inventory, or settlement rules.

Verification: source change and ZIP integrity checked. Flutter compile and live Supabase tests have not been performed.
