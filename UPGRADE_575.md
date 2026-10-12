# Upgrade 575 — Replacement revision full identity

Reconciles kitchen acknowledgment only after verifying revision order, item, product, unit price, quantity, actor, and change type against the authenticated employee’s immutable replacement receipt. Any mismatch returns investigation guidance without treating kitchen evidence as valid.

Verification: static regression checks only; Flutter and live Supabase not executed. Apply migration after 574.
