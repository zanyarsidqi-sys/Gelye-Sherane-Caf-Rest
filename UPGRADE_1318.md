# Upgrade 1318: Dashboard + Payments receipt metadata safety

- Dashboard cash card directs staff to protected receipt review in Payments Management.
- Payments Management sanitizes receipt ID, reference and employee ID before rendering or copying receipt text; line breaks, Unicode line separators and control characters cannot inject forged receipt fields.
- Receipt IDs that become empty after sanitation are invalid and cannot be copied.
- Metadata is length-limited to 160 characters for receipt legibility.
- Existing RPCs, route identifiers, permission logic and unrelated files remain unchanged.
- Archive/source assertions performed; Flutter compilation and live Supabase/device tests remain outstanding.
