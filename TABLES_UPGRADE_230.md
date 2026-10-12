# Upgrade 230 — QR menu live activity foundation

- Anonymous, expiring per-table QR menu sessions; 2-minute activity window.
- Public menu screen reports activity every 45 seconds while open.
- Tables dashboard displays active QR session counts on manual refresh.
- QR activity is **not** evidence of occupancy or a placed order.
- Public route must actually render PublicMenuScreen with its `token` query parameter for tracking to work; route deployment and production rate limiting require verification.
- Order-to-station automatic printing remains pending. This upgrade prioritizes the user's newest QR visibility request.
- No live Flutter build or Supabase migration execution performed.
