# Upgrade 252 — Section 03 Table Orders

- Started focused development of Section 03 using the existing live Supabase cart workflow.
- Corrected selected product display names for dropdown selection (not only barcode lookup).
- Added per-item +/- quantity controls and removal.
- Added estimated base-price subtotals for Normal/Tourism, clearly labeled non-authoritative.
- Added required review confirmation before submitting a real order.
- Editing quantities or changing tables invalidates review confirmation.
- Kept server-side pricing authoritative; no local discount or owner-price assumptions.
- No changes to deployed Supabase schema or physical printing.
- Pending: inline preparation notes, true Owner/Discount price previews, backend integration tests.
- ZIP integrity checked; Flutter compilation and Supabase live testing NOT performed.
