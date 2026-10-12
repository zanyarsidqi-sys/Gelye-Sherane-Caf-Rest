# Upgrade 1348

Standing Cash: repeat of the same receipt reference, order and amount returns the original receipt after order lock, even after visit closure; mismatched reference reuse fails. Payment error messaging preserves retry reference guidance.

Pending Payment: read-only motel invoice paid_cash/unpaid state versus cash settlement identity/amount inconsistency flags; collection remains disabled.

Production Flutter/Supabase tests not run.
