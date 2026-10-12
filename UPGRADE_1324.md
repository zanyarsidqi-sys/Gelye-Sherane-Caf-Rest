# Upgrade 1324 — Finance Dashboard batch

- Added Yesterday/Today Baghdad-day shortcuts; Last week/Last month/Tomorrow explicitly disclose unavailable period-aware backend support rather than inventing values.
- Linked Order value and Outstanding order balances detail navigation to Payments Management, alongside Recorded cash and Cash discrepancies. The cash-only ledger does not prove those broader figures; a warning documents the limitation.
- Financial detail screens disclose that only the current authorized account is available; cross-employee filtering awaits a permission-scoped RPC.
- Added brand-specific copyright and Powered by Zanyar Sidqi footer; version reads installed package metadata.
- Kept existing Payments RPC, receipt validation, navigation and permissions unchanged.
- Requires Flutter analyze/build, live RLS and RPC checks, period aggregation and employee filtering backend design.
