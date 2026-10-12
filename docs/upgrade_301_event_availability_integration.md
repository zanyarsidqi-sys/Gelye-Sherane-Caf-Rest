# Upgrade 301 — Customer event availability integration

- Corrected an unclosed collection-if in the public event screen that could prevent Dart compilation.
- Added a whole-venue availability RPC which rejects any overlap with approved ordinary reservations or events and exposes no personal data.
- Customer event preview now displays whole-venue availability and error feedback.
- Added request-generation guard so stale overlapping availability responses cannot overwrite newer selections.
- Existing selected-table capacity display remains intact.
- **Not production verified:** Flutter SDK unavailable here, no live Supabase access, migration untested. Public event submission remains disabled pending Turnstile UI and end-to-end verification.
- Next: cross-section integration audit, visual review on iPhone and Windows, user corrections before Section 04.
