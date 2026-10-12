# Phase 3 — cash payment status review

The Payments Management reconciliation now classifies each loaded order as Unpaid, Partially paid, Paid in cash, or No total, and lets staff filter by these statuses. Statuses are derived from the server-reported order total and cash ledger; they are not persisted as an independent payment state. This avoids creating a second source of truth.

**Important:** The labels represent recorded cash only. External card, credit, or other payments are not included. This is not a complete settlement status. The existing receipt viewer and Supabase authorization remain unchanged.

**Testing still required:** Flutter analyze/build, live Supabase RPC, role checks, no-total/partial/full cases, and receipt rendering. No new SQL migration is needed.

**Progress:** previous 61% implementation estimate retained; verified percentage unknown. Step 2 remains in progress.
