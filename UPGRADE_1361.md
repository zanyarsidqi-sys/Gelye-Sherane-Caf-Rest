# Upgrade 1361: Filtered motel finance invoice list

Added read-only date, custom range, payment method, and exact employee-ID filters. The list and its bottom total share the same filtered records. Missing metadata is excluded when its filter is active; no values are invented. Existing source inspection and payment safety are preserved.

Pending: full cross-card filter support, dedicated cash/credit subtype schema, invoice printing/saving, Flutter compilation and live Supabase tests.
