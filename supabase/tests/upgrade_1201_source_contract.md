# Upgrade 1201 source contract (not live integration tests)

- Employee Table Orders tab calls existing authenticated correction-request RPC.
- Approval and replacement RPCs retain finance manager/MFA checks.
- Corrected bill uses approved removals, not original generated line totals.
- Waste history is internal, permission-scoped and immutable.
- Prepared vs unprepared waste classification, kitchen cancellation/reprint, customer invoice printing, inventory valuation and multi-method payment integration remain pending.
