# Dashboard Upgrade 119 — Fix attested order transfer race

**Real defect repaired:** the Upgrade 114 settlement mutation guard locked
only the *destination* parent order when an order item was moved. It could
therefore race an independent finance attestation on the *source* order.

The replacement trigger function now locks **both parent orders** in
ascending ID order and refuses mutations if **either** has an immutable
cash-only finance attestation. This applies to financial records as well
as order items, including reassignment between orders. Existing Upgrade
114 triggers automatically call the replaced function.

This is a concurrency code fix, **not** a new dashboard card or another
readiness-only RPC. No mixed-payment release has been enabled.

**Deployment status:** ZIP integrity verified. The SQL was not executed;
transactional concurrency tests and complete schema compatibility checks
are still required before production rollout.
