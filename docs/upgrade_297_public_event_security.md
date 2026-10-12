# Upgrade 297 — Public event security foundation
- Added Supabase Edge Function with Turnstile server verification, request size cap and durable rate-limit RPC (5 verified attempts/hour/IP).
- Uses salted SHA-256 IP hash; rate-limit table is inaccessible to public roles.
- Fails closed if secrets, origin IP, CAPTCHA, or database verification are unavailable.
- Public submission deliberately remains disabled until an atomic, validated, service-role-only intake RPC and scoped conflict checks are added.
- Deploy with Turnstile secret, Supabase service-role secret, and EVENT_RATE_LIMIT_SALT; configure trusted proxy for cf-connecting-ip.
- Not compiled, deployed or tested live. No claim of functioning public reservations.
