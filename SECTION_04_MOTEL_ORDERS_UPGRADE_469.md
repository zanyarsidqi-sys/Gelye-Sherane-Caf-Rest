# Upgrade 469 — Cross-section RPC dependency audit

- Expanded the read-only cross-section audit to enumerate literal Supabase RPC references for Dashboard, Tables, Table Orders and Motel Orders and compare them with SQL function declarations in bundled migrations.
- The report identifies **review candidates**, not confirmed runtime errors. Dynamic RPC names and remotely provisioned functions cannot be verified offline.
- Generated `reports/section_review_469.json` as a reproducible baseline for pre-100% validation.
- No payment authorization or credit debit functionality was enabled.
- Flutter analysis, migration execution, and device tests remain outstanding.
