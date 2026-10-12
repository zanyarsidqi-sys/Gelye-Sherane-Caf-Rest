# Upgrade 1476 — shared security and approved identity lookup

All 35 management sections: add a visible employee-access recheck control, and clear a previous section's workflow search when switching sections. The existing permission gate, section routes, content, footer and finance controls remain unchanged.

Financial read-only RPC: `gs_financial_approved_motel_cafe_identity(uuid)` returns an independently approved mapping if registered; otherwise it returns a reason without guessing order identities. This is not a settlement, paid-state transition or certification. A real reviewer must validate source documents. SQL not executed on staging.

Staging procedure: deploy prior migrations in sequence; run this migration in a disposable staging project; sign in with authorized and unauthorized test users; verify no mapping, unapproved mapping, and independently approved mapping; verify the function cannot update invoice status or ledger. Test repeated calls and revoked access. Do not run against production without backup/change approval.

Rollback: drop function public.gs_financial_approved_motel_cafe_identity(uuid); restore previous section_shell.dart from Upgrade 1475. Do not roll back financial evidence tables or journal entries.
