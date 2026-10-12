# Upgrade 539 — Kitchen replacement revision acknowledgement

Adds permitted kitchen_revision destination to outbox (fixes a constraint conflict in Upgrade 538), permission-checked kitchen acknowledgment with immutable actor audit, and a staff dispatch-view acknowledgement control. This is not confirmation of physical printing. Existing station print acknowledgements remain separate.

Verification: static inspection and ZIP integrity only; Flutter and live Supabase tests not run.
