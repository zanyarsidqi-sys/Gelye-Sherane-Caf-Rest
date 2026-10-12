# Upgrade 465 — Customer authorization concern reporting

Added authenticated customer concern reporting for a visible credit invoice authorization. The RPC resolves the customer through a verified identity binding, checks identity safety holds, and resolves the invoice within that customer's account. Concerns are auditable and cannot approve, cancel, or debit payments. The customer UI provides a reason dialog and clear non-consent messaging.

Flutter compilation and live Supabase migration execution not performed.
