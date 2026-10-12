# Upgrade 313 — Customer cancellation

Customers with a valid active visit session can cancel their own **waiting** assistance request. The RPC verifies session ownership, locks session and call rows, and refuses cancellation once staff accept the request. The customer Flutter screen provides a cancel button, handles race conditions, and refreshes status after rejection. Existing staff workflow and 10 request types are retained.

**Verification:** ZIP integrity and source checks only. Flutter compilation, live Supabase migrations, and concurrency tests have not been run. The audit table created in Upgrade 311 records staff transitions; customer cancellations are not yet recorded in that staff-only audit table. Background push notifications remain pending.
