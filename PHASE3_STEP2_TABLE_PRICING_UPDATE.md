# Phase 3 Step 2: Table pricing linkage
- Table Orders now select occupied Supabase table records instead of accepting arbitrary table numbers.
- Database RPC locks the selected table, reads its saved tourism_mode, and determines unit price server-side.
- Motel Orders always use tourism prices.
- Legacy order RPC execute privilege revoked for authenticated employees after new RPC deployment.
- Requires migration 017, previously required migrations, and configured occupied tables.
- Not yet compiled or integration tested; other code paths and database grants must be audited before production.
- Historical overall implementation estimate 60%, not independently recalculated.
