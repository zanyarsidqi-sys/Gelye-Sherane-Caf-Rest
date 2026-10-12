# Upgrade 1365: Posted invoice subtype filter

Adds a read-only payment subtype selector to the posted motel food finance invoice list.
The choices are derived exclusively from `payment_subtype` values actually returned
by the authorized posted invoice RPC. Explicit subtype filtering excludes records
without matching metadata. The existing employee, method, and date filters still
combine with this selector, and the bottom-of-list total continues to use
`visiblePostedInvoices`.

This does not add backend fields, authorize additional reads, implement invoice
printing, or treat draft amounts as collected revenue.

Verification: ZIP CRC integrity, original-entry preservation, and static source
assertions only. Flutter build and live Supabase/RLS tests remain pending.
