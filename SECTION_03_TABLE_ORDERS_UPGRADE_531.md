# Upgrade 531 — Financial preview revalidation before quantity mutation

- Immediately before submitting an authorized quantity correction, the Flutter client requests a fresh read-only financial preview.
- Rejects changes to item identity, quantities, stored unit price, old/new line totals or IQD difference during the employee confirmation interval.
- The existing atomic Supabase correction function remains the final authority and independently enforces authorization, row locking, invoice/payment restrictions, and kitchen acceptance checks.
- No new database migration. This is not product replacement; that feature remains outstanding.
- Flutter compilation and live Supabase integration have not been verified.
