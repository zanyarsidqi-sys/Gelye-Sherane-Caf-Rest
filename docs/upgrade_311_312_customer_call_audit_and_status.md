# Upgrades 311–312: Customer call accountability and status

- Upgrade 311: append-only audit records every staff status change with authenticated employee, old/new status and timestamp; row-level security and no direct public access.
- Upgrade 312: customer status RPC returns whether staff is assigned without disclosing private employee identity. Staff queue can filter to waiting requests only.
- Existing polling is foreground-only; no background push notifications. RPC return shape changes, so migrations must be deployed before the updated client.
- Neither Flutter compilation nor live Supabase migration was run. Audit retention and production permissions need review.
