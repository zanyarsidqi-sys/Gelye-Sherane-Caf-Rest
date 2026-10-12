# Upgrade 1470: verified provider receipt retry reconciliation

The provider verification Edge Function now reconciles duplicate transaction references against the full immutable receipt evidence. An exact replay returns HTTP 200; mismatched evidence returns HTTP 409. The normal new-receipt path returns HTTP 201. Both paths leave allocation, invoice settlement and unified ledger unposted.

Staging steps: configure a controlled HTTPS provider fixture and a disposable Supabase project, apply all migrations, deploy Edge Function, then POST the same confirmed receipt twice; expect 201 then 200. Change invoice/amount/confirmation time for the same transaction and expect 409. Test concurrent duplicate submissions, RLS and rollback before any production use.

No live provider or database test was performed in this upgrade. Do not infer paid invoice state or certified IQD totals. Rollback: disable the Edge Function; preserve append-only receipt evidence.
