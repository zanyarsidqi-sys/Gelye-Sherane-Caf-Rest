# Upgrade 1221 — Customer pricing questions

- Adds `pricing_request` to customer table QR assistance choices.
- Requires a product/pricing description.
- Adds request-type validation to Supabase with original visit authorization, rate limiting and active-request checks retained.
- Allows supervisors to route `pricing_request` to an active pricing/cashier station using existing station routing.
- Unmapped requests remain in supervisor queue; requests never change prices or invoices.
- Flutter compilation, Supabase integration, and printer/device testing deferred by request.
- Remaining: station screen polish, printer dispatch/worker, cross-section station-access audit.
