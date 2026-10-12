# Upgrade 317 — Customer QR bill preview safety

- Clear previous order amounts on RPC failure to prevent showing stale or unauthorized financial data.
- Add empty-state feedback, swipe-to-refresh, last-refresh time and readable IQD grouping.
- Preserve gross-order-only disclaimer. This is not the final payable balance.
- Backend remains `gs_customer_visit_bill_preview` with visit-token validation.

Verification: source inspected and ZIP checked; Flutter compilation and live Supabase tests not available in this environment.
