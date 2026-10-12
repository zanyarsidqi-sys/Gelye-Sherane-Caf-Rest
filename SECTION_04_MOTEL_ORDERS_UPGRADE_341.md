# Upgrade 341 — Temporary guest access verification foundation

Adds staff-issued room-scoped access tokens, time-based expiry, reissue revocation and explicit revoke RPCs. Customer QR screen accepts and verifies the access token against the physical room QR. Room QR alone grants no guest permissions. The employee issuing a code must check actual reception occupancy; **this does not yet query an authoritative motel check-in database**. Verification only displays a verified indicator: ordering, bills, and other private APIs remain locked until each RPC enforces access token and active-stay checks. Do not treat this as a complete room-charge authorization solution.

Manual tests needed: migration in a Supabase test project, permission denial for anon issuance, token expiry, revocation, room mismatch, QR rotation, repeated issuance, and UI compilation.
