# Upgrade 1137 — Kitchen live order queue session isolation

- Subscribe to Supabase authentication changes, comparing the actual current employee ID.
- Invalidate queue and item caches, in-flight generation and busy state on employee switches.
- Hide cached order data if it belongs to a different or signed-out employee.
- Stop exposing raw Supabase error details in the live queue.
- Cancel the authentication subscription on disposal.

Verification: 3 static regression tests; no Flutter SDK or live Supabase credentials available.
