# Upgrade 1366: posted invoice methods and details

Posted invoice payment method choices are now derived from authorized RPC metadata, rather than hard-coded Cash/Credit values. Tapping a posted invoice row opens its existing read-only source-line details. Existing date, employee, subtype, and bottom-of-list total logic remains. No invoice printing, saving, payment processing, or new permissions were enabled.

Verified: ZIP integrity, archive-entry preservation, source assertions. Flutter build and live Supabase tests pending.
