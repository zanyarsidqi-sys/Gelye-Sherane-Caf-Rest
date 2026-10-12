# Upgrade 1264 — Dashboard recovery and accessibility

- Updated the existing live-data failure panel to give actionable connection and permission guidance without assuming a particular migration number.
- Added an explicitly labeled retry button with a refresh icon and screen-reader semantics.
- Preserved existing RPC loading, permission filters, layout and navigation.
- Static patch verification only; Flutter compilation, device tests, and Supabase runtime remain unverified.
