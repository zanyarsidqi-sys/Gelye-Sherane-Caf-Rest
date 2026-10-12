# Upgrade 406 — Credit Provider Integration Contract

Introduces an administrator-provisioned metadata contract for a future authoritative Credit Management provider. Contract records are **not connected**, cannot assert ownership/balance/debit support, and do not grant payment permission. Replaces the existing Credit Backend Checks RPC to display whether any provider contract has been configured, while continuing to block credit payment eligibility.

No customer balances, debit/credit ledger transactions, approval, or payments are created. Migration has not been applied to live Supabase and Flutter has not been compiled. Next: inspect authoritative Credit Management schema, design adapter and tests before implementing real debits.
