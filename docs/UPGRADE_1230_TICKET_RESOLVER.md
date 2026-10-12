# Upgrade 1230 — Station print payload and adapter boundaries

- Adds an immutable station-ticket snapshot table and a service-role-only resolver validating station, active device session, dispatch attempt, and ticket lease.
- Adds Edge Function `resolve_print` and Flutter resolver validating the returned station and ticket identity.
- Adds printer driver interface and lifecycle coordinator. **The lifecycle is intentionally not started automatically until a real, configured printer driver is supplied**; no fake successful print acknowledgment.
- Existing station POS screen and session code remain intact. A future integration must attach the lifecycle to the POS screen when a real driver is installed and stop it on logout or permission loss.
- **Blocking prerequisite:** trusted order-routing code must populate immutable snapshots transactionally before queueing tickets. Until then the resolver fails closed, preventing printing fabricated/mutable order details. Correction/replacement snapshot generation is also outstanding.
- A paper-print success callback cannot be simulated by socket-write completion; unknown outcomes require manual review.

No Flutter compilation, live Supabase migrations, or physical printer tests performed.
