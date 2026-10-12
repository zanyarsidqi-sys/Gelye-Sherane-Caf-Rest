# Upgrade 461 — Authorization Safety Hold UI

Added a permission-gated RPC for historical identity safety-hold status by authorization request ID. The Credit Identity Review authorization history now offers a **Safety Hold** button showing hold count and whether new authorization is blocked. The RPC avoids exposing private dispute explanations. No hold does not mean customer consent is verified. Credit debits remain disabled.

Not tested with Flutter CLI or a live Supabase instance.
