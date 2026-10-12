# Upgrade 524 — Quantity correction financial integrity

- Replaces the Upgrade 522 quantity-correction function with a stored unit-price validation guard.
- Rejects missing, negative or implausibly large IQD unit prices before changing quantity or writing audit revisions.
- Preserves existing authorization, kitchen ticket, invoice lock, and optimistic concurrency checks.
- Apply migration 524 after 522. No live database verification has been performed.
