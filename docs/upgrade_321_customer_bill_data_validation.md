# Upgrade 321 — Customer bill line-item validation

The customer QR gross bill preview now validates every response row before displaying any monetary data. Non-list responses, malformed line items, missing/non-numeric/non-finite/negative amounts, and missing/non-positive/non-integral quantities are rejected. The screen clears all amounts and asks the customer to contact the cashier rather than silently replacing invalid values with zero. In-flight generation and session checks remain in effect.

This does not calculate the final outstanding balance. Flutter compilation and live Supabase testing are pending.
