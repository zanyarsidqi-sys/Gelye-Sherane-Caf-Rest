# Upgrade 1367 — invoice employee and date validation

- Posted invoice employee filter is now a selector populated from employee_id / created_by IDs actually returned by the authorized RPC.
- Invalid custom date ranges explicitly show an error and match no records; the existing bottom-of-list total then matches the empty list.
- No new Supabase permissions, payment processing, invoice printing or PDF saving introduced.
- ZIP CRC, original entry preservation, and source assertions verified. Flutter compile/live Supabase remain unverified.
