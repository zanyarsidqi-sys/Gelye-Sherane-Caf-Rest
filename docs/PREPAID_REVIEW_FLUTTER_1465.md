# Upgrade 1465: staged verified prepaid allocation UI

- Added authenticated read-only review RPC, and staging-gated Flutter allocation UI.
- Review reads an existing independently provider-verified receipt. It does not attest a new provider transaction.
- Allocation RPC from upgrade 1463 must independently revalidate and serialize.
- Staging: apply migrations, seed **synthetic** provider-verified receipt using a trusted service-only fixture, test valid allocation, retry, incorrect amount, cash/credit collision, role denial, two sessions, rollback, and no certified Dashboard totals.
- Do not enable `GS_ENABLE_VERIFIED_PREPAID_ALLOCATION` in production until verified.
- Provider API/webhook integration, authoritative café order mapping, invoice paid status and unified ledger remain incomplete.
