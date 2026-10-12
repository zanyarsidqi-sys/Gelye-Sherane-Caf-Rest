# Upgrade 218 — Partial quantity pickup/delivery interface

- Added assigned-employee My Jobs action to view ordered, picked, delivered and outstanding quantities.
- Added quantity entry and separate pickup / delivery confirmations through Upgrade 217 RPC.
- Added secure per-job read-only snapshot RPC, returning only jobs assigned to current employee.
- Existing database checks reject over-pickup, over-delivery and unauthorized handover.
- **Known limitation:** Existing legacy whole-item pickup records cannot be migrated automatically; the quantity RPC rejects ambiguous legacy states. The legacy item status action is still available elsewhere and should be consolidated in a future upgrade.
- **Verification:** ZIP integrity and source checks only; Flutter compilation and live Supabase migrations not executed.
