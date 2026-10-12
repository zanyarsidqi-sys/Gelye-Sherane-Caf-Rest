# Phase 3 — Step 2: live order workflow entry point

## Implemented in this update
- Table Orders, Motel Orders and Kitchen now open their existing live Supabase record/queue views by default, rather than a misleading local-only order simulation.
- Staff can switch to live order creation on Table Orders or Motel Orders. The existing SecureOrderService delegates pricing and authorization to server-side RPCs.
- Kitchen live view already offers authorized new → preparing → ready → served transitions and refresh.
- Local demonstrations remain available only by explicitly turning the live switch off.

## Still outstanding (not verification-only)
- Tables section remains a local occupancy/pricing preview; no live table occupancy write workflow was added.
- A single live screen does not yet unify creating orders, viewing them and kitchen dispatch without navigation.
- Supabase migrations and RLS must be deployed and reviewed; app compilation and live device testing were not run.
- Full end-to-end workflows, payments and offline behavior remain incomplete.

## Progress
Historical planning estimate: 60% implementation, **not verified**. This update does not justify increasing it. Seven planned milestones remain, including this partially completed milestone.
