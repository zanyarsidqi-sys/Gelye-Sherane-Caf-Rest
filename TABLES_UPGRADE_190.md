# Tables Upgrade 190 — Verified item delivery closes employee job

- Replaces the fulfillment transition RPC to require the **assigned**
  delivery worker for `prepared -> picked_up -> delivered`.
- Locks the order item and matching job and rejects missing, duplicate,
  cancelled or unassigned jobs.
- Picking up automatically moves the matching job to `in_progress`.
- Confirmed delivery atomically marks the matching job `completed`,
  records employee identity, time and an audit/notification event.
- Item delivery remains separate from payment; no invoice or payment
  state changes.

**Limitations:** One job per full order item; partial quantity handoff,
worker reassignment, real push dispatch and Supabase/Flutter live tests
are pending. Earlier migration 187 identifies jobs by a text field;
upgrade 191 should introduce a proper foreign-key association to remove
that fragility. No claim of production readiness.

Tables **69% estimated**. ZIP integrity checked.
