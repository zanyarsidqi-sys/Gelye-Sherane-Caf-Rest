# Upgrade 318 — customer bill consistency

- Removed the 200-product limit from the visit-scoped gross bill preview RPC. Previously a visit with over 200 distinct products could show an incomplete gross total.
- Kept token/visit validation and the explicit warning that this is NOT the final payable balance.
- Prevented an in-flight response from a previous visit token overwriting the current visit’s bill; cleared cached bill on token changes.
- Flutter compilation and live Supabase tests remain outstanding. Apply migrations in order.
