# Upgrade 466 — Authorization concern escalation guard

Added a database trigger preventing escalation of authorization request status when the customer reported a concern. Cancelled, expired and rejected transitions remain possible. Added permission-controlled staff review RPC returning concern reasons and timestamps. No customer identity activation, consent, balance mutation, or credit debit is enabled.

Requires migration 465. Flutter compilation and live Supabase migration execution not performed.
