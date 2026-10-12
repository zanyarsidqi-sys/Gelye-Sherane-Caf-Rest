# Upgrade 488 — Dashboard weekly cash collections

Added permission-scoped seven-day Table Orders and Motel Orders cash-collection breakdown, each using Asia/Baghdad business-day boundaries. Inaccessible ledgers return null rather than zero. Includes server and Flutter validation. Cash remains unreconciled, and credit/revenue/profit are excluded.

Development estimate: Dashboard 84% provisional; Tables 94%; Table Orders 69% historical; Motel Orders 91%. Flutter compilation and live Supabase testing not performed.
