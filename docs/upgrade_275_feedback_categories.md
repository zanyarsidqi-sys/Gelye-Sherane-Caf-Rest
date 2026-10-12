# Upgrade 275: Customer feedback category validation

Customer feedback draft now separates:
- Survey (1-5 rating)
- Item rating (selected menu product + 1-5 rating)
- Suggestion (required written recommendation)
- New product (required product name)

These types align with the Upgrade 272 Supabase feedback table.
Draft validation is local only; no feedback is submitted or stored.
Secure visit-scoped sessions, rate limiting, database submission and
production testing are still required.
