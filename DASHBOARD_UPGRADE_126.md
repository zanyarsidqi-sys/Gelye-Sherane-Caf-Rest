# Dashboard Upgrade 126 — No new orders after guest departure

**Actual defect addressed:** the visit association trigger (Upgrade 118)
accepted a new order on an occupied table even when the guests had already
left and cleaning had started. That could introduce new unpaid work while
checkout was being prepared.

The existing trigger function is **replaced**, not duplicated. It still
serializes visit association changes and locks both old and new visits,
but now refuses attaching an order if the destination table already has a
recorded guest departure. A returning guest needs a new authorized visit;
the existing visit must first be safely completed and released.

**Scope:** blocks new associations after departure; does not prevent
legitimate edits of existing orders through the normal permission rules.
Does not add mixed-payment checkout or certify production readiness.

ZIP integrity verified; Supabase deployment and concurrency testing pending.
