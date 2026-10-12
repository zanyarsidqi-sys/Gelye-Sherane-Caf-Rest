# Dashboard Upgrade 121 — Fix checkout authorization gap

**Concrete security defect corrected:** the cash-only release RPC previously
accepted a table editor with **financial read-only** permission. Such a staff
member could finalize table release based on someone else's attestation.

The replacement `gs_release_cash_only_table_visit` now requires:

- Authenticated **MFA AAL2** session.
- Table **edit** and invoices/payments **edit** permissions.
- Explicitly provisioned and enabled finance reviewer.
- A **different reviewer** from the person who attested any order in the visit.
- All existing payment snapshot, physical checkout and legacy order guards.

This is an authorization fix to the actual release operation, not another
status check. Mixed methods remain unsupported. Requires staging deployment,
permission validation, concurrency testing and Flutter compilation. ZIP
integrity verified; SQL has **not** been executed.
