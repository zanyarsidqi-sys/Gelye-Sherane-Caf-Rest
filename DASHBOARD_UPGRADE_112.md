# Dashboard Upgrade 112 — Correct checkout integrity bug

This upgrade fixes a specific cross-visit safety issue in the physical
checkout status RPC introduced in Upgrade 110. The function previously
trusted the physical table's departure timestamp and service tasks without
checking whether there were conflicting open visits or tasks attached to
another physical table.

The replacement function now rejects both cases, scopes task counting to
the visit **and** physical table, and gives staff a clear blocking reason.
This is an actual change to the checkout readiness logic, not another
request/approval workflow.

**Still blocked:** checkout/table release and financial settlement require
independent, authoritative payment verification. No cash refund is inferred.

**Verification:** ZIP integrity checked; migration not deployed or executed;
Flutter not compiled. Run migration 112 after 110 and test conflicting
visits, mismatched tasks, normal visits, and reused tables in staging.
