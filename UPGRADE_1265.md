# Upgrade 1265 — Dashboard accessible loading and failure announcements

- Added a labeled live-region loading state to the existing Dashboard overview FutureBuilder, retaining its live RPC source and no-fabricated-values policy.
- Added live-region semantics to the existing Dashboard error headline so screen-reader users are informed when a live request fails.
- Kept existing retry action, permission checks, cards, responsive columns, and backend logic unchanged.
- Verification: source replacement assertions and ZIP integrity; Flutter compilation and real-device accessibility tests not run.
