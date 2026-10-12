# Upgrade 160 — Tables transfer review queue

Added an authorized, **read-only** pending bill-transfer request queue and
per-item financial preflight in Flutter. Staff can inspect the requested
source/destination visit, original line values and detailed blocker reasons.

No approval button or transfer execution is enabled. The existing financial
preflight returns `ready_to_apply=false`, intentionally blocking transfers
until authoritative payment allocation and settlement validation are complete.

Tables development estimate: 41%; 7/20 milestones fully complete and 13
remaining. This upgrade advances the partial bill-transfer milestone.

ZIP integrity was checked; Flutter compilation and live Supabase execution
were not performed. Test migrations and permissions in staging first.
