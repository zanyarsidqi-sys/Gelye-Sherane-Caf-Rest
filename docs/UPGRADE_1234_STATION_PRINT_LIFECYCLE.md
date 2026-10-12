# Upgrade 1234 — Station POS print lifecycle

- Added two independent queue workers to the lifecycle (original and revision) using the station-scoped resolver, claim and acknowledgment endpoints.
- Station POS gate accepts an injected physical printer driver; without one, no ticket is claimed. Starts after an authorized session and order-print permission; stops on logout, disposal, session invalidation, network loss or permission revocation.
- Displays worker/printer errors in station UI; no fabricated success or automatic reprint of uncertain outcomes.
- Existing customer branding remains in station ticket formatter; company-wide screen and official A4 invoice templates still require integration.

**Safety limitations:** The worker's local uncertain set is not durable across restarts. Backend must ensure claimed/unknown tickets never requeue automatically. Printer driver remains unimplemented. Concurrent original/revision workers share one driver; physical drivers must serialize their own output. No actual printing or live tests were performed. A station status change while a hardware print is in progress cannot undo paper already printed. Review RPC and migration schemas against production before deployment.
