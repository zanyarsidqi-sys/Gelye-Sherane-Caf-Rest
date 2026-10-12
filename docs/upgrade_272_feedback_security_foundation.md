# Upgrade 272 - Customer feedback intake foundation

- Adds a structured customer feedback table for surveys, item ratings,
  suggestions and new-product requests with input checks and visit references.
- Adds a read-only, permission-checked staff RPC to retrieve submissions.
- Does not grant anonymous database writes or claim a verified customer session.
- Customer submission remains disabled until a secure table/visit session
  validation and rate limiting flow is built and tested.
- Flutter compilation and Supabase deployment are untested.
