# Upgrade 1314 — Dashboard and linked Payments receipt verification

- Dashboard cash card explains individual receipts must be verified in Payments.
- Payments receipts require a positive whole-IQD amount, nonempty receipt ID, and parseable collection timestamp before displaying formatted proof or enabling copy.
- Invalid receipts show a non-copyable warning rather than a selectable formatted receipt.
- Other files preserved; source/ZIP checks only, Flutter and live Supabase testing pending.
