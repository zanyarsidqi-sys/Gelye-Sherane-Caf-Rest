# Upgrade 327 — structured bill item issues

Customer bill items now open a reason selector before creating a cashier assistance request. Reasons: not ordered, wrong quantity, wrong price, or other. The request includes the selected reason, item name, quantity and displayed IQD amount. It is submitted only through the existing authorized customer assistance flow; this change does not alter financial records or automatically refund charges.

Validation: source-level check and archive integrity only. Flutter analyzer, UI tests, and live Supabase tests were not run.
