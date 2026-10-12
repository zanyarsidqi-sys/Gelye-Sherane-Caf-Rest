# Dashboard Upgrade 48 — Design review checkpoint

Added Owner Guest Offers read-only Dashboard detail (iPhone full-screen,
Windows side panel), with a draft owner-offer ledger and permission-checked
read RPC. No owner approval/write flow is implemented: staff cannot mark
their own request verified.

Motel Meal Offers shortcut retained from Upgrade 47.

DESIGN REVIEW: iPhone and Windows mockups are illustrative, not app
screenshots. Mockups may depict planned controls and sample values that
are not implemented. User approval is required before Section 02.

Outstanding: reconcile migration schema/permissions, owner verification
and invoice posting, full motel reservation barcode workflow, automated
cleaning, notifications, payment settlement, build and integration tests.
No live Supabase deployment or Flutter build was performed.
Overall Phase 3 estimate remains historical ~54%, not verified.
