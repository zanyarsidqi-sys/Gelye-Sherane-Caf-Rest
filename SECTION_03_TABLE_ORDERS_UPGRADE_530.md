# Upgrade 530 — Quantity financial preview identity binding

- Expanded permission-scoped Supabase financial preview to return the order-item ID, original quantity, proposed quantity, and stored IQD unit price alongside financial totals.
- Flutter verifies preview identity and both quantities match the current correction request.
- Flutter verifies the server-reported totals agree with the returned stored unit price before showing confirmation.
- Fail-closed behavior: missing/malformed/contradictory preview fields prevent mutation.
- Existing transaction and payment/kitchen/invoice restrictions remain in place.
- Migration: `supabase/migrations/20261010_530_quantity_preview_identity.sql` (apply after 529).
- No product replacement yet. Flutter compilation and live Supabase migration execution have not been verified.
