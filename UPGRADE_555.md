# Upgrade 555 — Kitchen revision serialization

Adds a server-side guard to both quote and commit RPCs: a new replacement for an order item is refused while a previous product replacement kitchen revision has no acknowledgment. This includes failed dispatches; kitchen staff must recover and acknowledge the earlier revision first. Existing order-row locks serialize concurrent commits.

No historical financial records are modified. Migration 555 must follow 554.

Verification: static migration assertions and ZIP CRC only; Flutter compilation and live Supabase testing unavailable.
