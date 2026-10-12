# Upgrade 326 — Item-specific customer bill correction

Added a **Report issue** action on each validated customer bill line. The action opens the existing customer assistance flow with cashier selected and a prefilled description containing the product, quantity and displayed gross amount. The existing visit-token authorization, employee queue, and request audit/status controls are reused. The customer must explicitly submit the request; opening the form does not submit it. Product names in the prefilled note are capped at 65 characters to stay within the existing 300-character request note limit.

This does not change financial ledger totals or promise an accurate outstanding balance. Flutter compilation and live Supabase tests remain outstanding.
