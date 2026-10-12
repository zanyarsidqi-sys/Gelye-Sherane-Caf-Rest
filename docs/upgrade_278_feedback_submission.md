# Upgrade 278 - Customer feedback submission

- Staff-issued visit-session token required; static QR alone cannot submit.
- Server checks occupied table, open visit, expiration, revocation and rating/length constraints.
- Session row locked to serialize the per-visit rate cap of 5 feedback items/hour.
- Survey, suggestion and new-product requests supported; item ratings fail closed pending server-side product/menu validation.
- Customer feedback UI calls the RPC only with a visit session and displays errors without exposing internals.
- No public read of private feedback. Checkout revocation inherited from upgrade 276.
- Important: session tokens are bearer credentials and must be handed to the actual table guest securely; staff-issued token handoff remains to be built and tested.
- Requires Supabase migration/schema review and Flutter build/live testing before production.
