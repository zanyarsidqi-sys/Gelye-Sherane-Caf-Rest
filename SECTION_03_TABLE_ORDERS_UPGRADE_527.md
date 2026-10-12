# Upgrade 527 — Mandatory quantity correction reason

- Employees must enter a 5–250 character reason when changing a pre-acceptance quantity.
- The confirmation dialog displays the reason before submission.
- A new four-argument Supabase RPC validates and records the reason in the existing order revision audit event.
- The prior three-argument RPC has execute permission revoked to prevent bypassing the reason requirement.
- Apply migration `20261010_527_quantity_correction_reason.sql` after migration 524.
- This does not enable product replacement, and it does not claim live testing.
