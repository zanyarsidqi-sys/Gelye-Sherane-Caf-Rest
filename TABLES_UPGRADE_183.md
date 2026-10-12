# Upgrade 183 — Review and edit takeaway/delivery draft lines

- Selecting a counter request now loads its priced menu items and IQD draft total.
- Each line displays quantity, product, pricing mode and line total.
- Authorized staff can remove a draft item using a permission-checked RPC.
- The RPC locks the parent request and refuses edits unless still pending.
- Totals are reloaded after add/remove; no financial posting, kitchen ticket,
  delivery status or payment is changed.

This is a **draft** workflow, not a working checkout. Live Supabase and
Flutter compilation not verified. ZIP integrity checked. Tables estimated
60%; Table Orders progress is not claimed as production-ready.
