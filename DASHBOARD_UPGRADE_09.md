# Dashboard Upgrade 09 — Guest Experience

Added `lib/screens/dashboard/guest_engagement_cards.dart` and connected the cards to the actual dashboard screen.

- Guest Survey & Requests: concerns, service requests, suggestions, complaints, compliments; optional customer name.
- Employee Product Recommendations: promote existing products, suggest new products, or improve existing products.
- Responsive navigation: iPhone full-screen, Windows right-side panel.
- Recommendation access gated on `menu` section authorization. Both cards gated on Dashboard permission.
- Submission deliberately disabled: secure backend tables, authorization, attachments, staff assignment, audit and notifications are not implemented.
- No fake counts, no fabricated saves, no database migrations applied.

Status: Source-only change; Flutter compile/test and Supabase verification deferred until PC available.
Overall Phase 3 progress: ~54% previous estimate, not newly verified.
