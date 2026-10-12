# Dashboard Upgrade 23 — Local Card Personalization

- Edit Dashboard toggle, individual KPI card palette choices (8 colors), per-card order using move-left/right controls, and reset.
- Local device persistence namespaced by authenticated Supabase user ID via shared_preferences.
- Existing permission-filtered RPC data and card details retained. Missing backend metrics are not fabricated.
- IMPORTANT: Cross-device syncing, drag-and-drop gesture, sizing, and customization of non-KPI feature cards are not yet implemented. Those remain follow-up tasks.
- Flutter compile/test, Supabase migrations, and PC verification deferred at user request.
