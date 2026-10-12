# Upgrade 511 — Serialize instruction editing and order-board refresh

## Implemented
- Lock the staff fulfillment board while an instruction editor fetches the authoritative value, displays the edit dialog, and submits the audited revision.
- Disable conflicting fulfillment transitions, history actions, and manual refresh while the editor is open.
- Queue refreshes requested during editing and reload the authorized board after the editor closes, including cancel and error paths.
- Preserve the existing server-side permission, revision, and optimistic-concurrency checks.

## Still outstanding
- Quantity/product edits require audited backend RPCs and price/invoice/ticket reconciliation; they remain disabled.
- Flutter compilation and live Supabase integration testing have not been performed.
