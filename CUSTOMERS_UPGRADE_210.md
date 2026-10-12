# Upgrade 210 — Customer performance analytics

- Adds permission-checked SQL RPCs `gs_cafe_customer_performance` and `gs_cafe_customer_monthly_trend`.
- Reports first/last visit, recorded visit count, total attested cash-only spending, qualifying order count and average cash-only order value.
- Six-month local-time (Asia/Baghdad) trend covers recorded visits and attested cash spending, including months with zero activity.
- Uses aggregate queries rather than capped history to avoid incorrect lifetime cash totals.
- Adds Customers screen analytics button/dialog. No claims about credit/card/mixed spend.

Validation: ZIP integrity, uniqueness and expected code paths checked. Flutter compilation, SQL execution and live Supabase testing not performed.
Estimated: Tables 84%, Customers 45%.
