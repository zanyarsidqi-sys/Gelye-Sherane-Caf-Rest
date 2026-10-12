# Upgrade 541 — Kitchen revision audit visibility

Section 03 Table Orders. Adds a permission-gated read-only RPC projection of human kitchen acknowledgment identity and failed-dispatch retry audit metadata, surfaced in the Flutter revision dispatch dialog. The server returns only the most recent retry reason and count; raw audit tables remain inaccessible to clients. Does not claim delivery or printing; a trusted dispatch worker remains necessary. Existing payment and price-confirmation behavior is unchanged.

Deployment: apply migration 541 after 540, regenerate PostgREST schema cache if needed. No database migration was executed against a live Supabase instance.
Verification: ZIP and source assertions only; Flutter compile and Supabase integration tests not run.
