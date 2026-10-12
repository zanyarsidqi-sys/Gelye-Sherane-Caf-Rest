# Phase 3 — Kitchen item detail refinement

- Expand each live kitchen order to see server-stored order items, quantities, charged unit prices, line totals, and the total in IQD.
- Motel orders display an explicit Tourism pricing requirement.
- Existing kitchen status RPC and permission enforcement are unchanged.
- Order-item reads are subject to Supabase RLS; failed reads show a non-destructive error.
- Product IDs are shown rather than guessing names or making assumptions about menu access.
- Refresh clears cached item details.
- No SQL migrations or live database modifications.

Testing postponed until tomorrow as requested. Flutter SDK unavailable here.
