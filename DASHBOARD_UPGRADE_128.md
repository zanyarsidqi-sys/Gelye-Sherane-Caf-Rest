# Dashboard Upgrade 128 — Prevent bill-transfer changes after finance approval

**Concrete gap fixed:** The existing attested-order guard blocked changes to
order items and payment rows, but the transfer request item table could still
reference an already-attested order item without modifying it. This would
allow a *new conflicting transfer request* after finance settlement approval.

The new trigger guards INSERT, UPDATE and DELETE on
`gs_table_bill_transfer_request_items`. It locks the affected order row and
rejects any change touching an order with a cash-only settlement attestation.
This preserves the existing transfer-request RPC, audit and checkout behavior;
it does **not** execute transfers or permit mixed-payment settlement.

**Testing required:** Verify trigger ordering and concurrent transfer request
vs attestation behavior in a real Supabase staging database. Static ZIP
integrity passed; SQL has not been executed and Flutter has not been compiled.
