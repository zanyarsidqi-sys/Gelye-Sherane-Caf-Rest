# Upgrade 209 — Combined customer profile

Added a customer profile action in Customers (`lib/sections/customers.dart`) that loads existing permission-checked RPCs for visits, reservations and attested cash settlement history. The dialog displays recent activity and a conservative cash-only total calculated from the returned history (up to 500 records); it explicitly does not claim lifetime or all-method spend.

No schema changes. Existing 35-section project retained.

Validation: ZIP CRC/unique entries and source presence only. Flutter compilation and Supabase integration not run.

Estimated progress: Tables 84%; Customers 40%.
