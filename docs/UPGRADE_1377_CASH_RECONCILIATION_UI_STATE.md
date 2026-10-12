# Upgrade 1377: Cash Reconciliation visual/interaction fidelity

- Stable `ValueKey` per filter selection ensures Flutter DropdownButtonFormField state reflects the Clear filters action.
- Invalid order identifiers no longer display a chevron suggesting a usable drill-down.
- Financial review `_money` no longer truncates fractional or non-finite monetary values into apparently valid whole-IQD figures; it displays Unavailable.
- Existing permission-scoped RPC, search, bottom filtered total, and attestation flows preserved.
- No other card advanced. Invoice print/save remain unimplemented.
- ZIP CRC, entry preservation, and static source assertions checked; Flutter build and visual similarity not verified.
