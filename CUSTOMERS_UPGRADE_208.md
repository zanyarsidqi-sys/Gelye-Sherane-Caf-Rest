# Upgrade 208 — Monthly Customer Rankings

- Added `gs_cafe_customer_period_rankings(p_month, p_rank_by)` with server-enforced `customers.can_view` permission.
- Filters visits by `visited_at` and cash-only settlement attestations by `attested_at` in the **Asia/Baghdad** local calendar month; uses exclusive end boundaries.
- Supports rankings by verified cash spending or visit count, with stable ties. Only customers with period activity appear.
- Customers Flutter screen includes previous/next month and ranking selector.
- Rankings remain conservative: mixed, credit, card and unattested receipts are excluded. Historical manual visits and verified check-ins are included as recorded.
- ZIP structure/integrity validated. No Flutter compiler or live Supabase available; schema integration must be tested before deployment.
- Estimated progress: Tables 84%; Customers 35% (not deployment verification).
