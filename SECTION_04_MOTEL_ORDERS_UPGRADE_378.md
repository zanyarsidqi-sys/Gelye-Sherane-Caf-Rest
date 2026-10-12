# Upgrade 378 — Food invoice readiness check

Adds `gs_staff_motel_food_invoice_readiness` for a read-only, permission-checked per-register reconciliation. Compares header line count and IQD total to the registered lines, and checks every source through the existing Upgrade 377 source audit. Employee finance handoff screen adds a Check Invoice Readiness action. `source_verified` means source integrity only; it does NOT mean a unified invoice has been created or a payment made.

## Validation limitations
ZIP archive integrity can be checked offline. Flutter compilation, SQL migration execution, database permission testing, and live payment integration have not been performed. Unified invoicing and payment posting remain disabled.
