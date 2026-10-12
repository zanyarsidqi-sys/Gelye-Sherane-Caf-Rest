# Tables Upgrade 217 — Quantity-aware item delivery (backend foundation)

Adds quantity totals and immutable employee-attributed pickup/delivery events, enforced by serialized row locks. Prevents over-pickup and over-delivery. The assigned employee may record partial pickups and deliveries; a delivery job is completed only after the entire ordered quantity is delivered. Existing whole-item RPC refuses to operate once quantity events exist.

**Limitations:** No Flutter quantity entry UI in this upgrade. Legacy full-item delivery that occurred before this migration is not backfilled. There is no live Supabase migration/Flutter compilation verification. Run migration in staging and test concurrent pickup/delivery, event triggers, permissions and cancellation edge cases before enabling in production.

Tables estimated 91%; Customers paused at 45%.
