# Upgrade 373 — Invoice Reservation Reconciliation

Adds read-only, permission-gated RPC `gs_staff_motel_invoice_reservation_reconciliation` and an employee menu action **Check reserved sources**. It compares verified invoice source manifest records with existing reservations by order ID, ledger ID, room ID, amount, review ID, and fingerprint. Shows matched, missing, unexpected, and mismatched sources. The underlying manifest rejects stale approvals. Does not post official invoices or payments.

Validation: ZIP integrity only; Flutter and live Supabase migrations not tested. Section 04 remains at 75% estimated.
