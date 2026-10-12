# Upgrade 236 — Flutter preparation-instructions editor

- Adds a working Flutter dialog to the live Table/Motel Orders panel for editing an existing saved order-item instruction by its ID.
- Validates positive numeric item ID, caps notes at 500 characters, supports clearing notes, shows server errors, disables duplicate submission.
- Calls the protected `gs_set_order_item_preparation_instructions` RPC introduced in migration 235. Backend enforces edit permission, order `new` status and no previously created station ticket.
- **Limitation:** This is a post-creation order-item editor. The current cart creation RPC does not accept notes atomically; the employee must supply the saved order-item ID before acceptance. A future upgrade should expose order-line IDs and integrate note entry directly into cart checkout in one transaction.
- Physical printing, live Flutter compilation and Supabase deployment tests are not included.
