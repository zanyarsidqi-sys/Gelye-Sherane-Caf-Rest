# Upgrade 1277 — Dashboard selected-day stale data guard

- Section 01 Dashboard only. When the selected date changes during an in-flight overview request, show an accessible loading state instead of rendering the previous day's figures beneath the new date.
- Keep the existing serialized/queued refresh behavior, permissions, Supabase RPCs, and metric cards intact.
- Static assertions and ZIP integrity verified; Flutter SDK, device rendering, and live Supabase integration not available in this environment.
