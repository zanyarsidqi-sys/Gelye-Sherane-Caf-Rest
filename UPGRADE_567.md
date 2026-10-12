# Upgrade 567 — Durable client recovery for product replacement

- Save a user-scoped pending replacement request ID and expected receipt fields in SharedPreferences **before** sending the replacement RPC.
- Prevent submission of a second replacement while an unresolved local request exists.
- Restore the pending identity after reopening Table Orders and offer a manual server-receipt check.
- Clear the pending identity only after validating a successful response or matching committed server receipt.
- Never treat a missing receipt as proof that retry is safe; a request may still be in flight.

## Limitations
Device-local persistence is not shared between employee devices. SharedPreferences is not a secure vault; only opaque request IDs and non-secret order metadata are saved. Live Supabase and Flutter build verification are still required.
