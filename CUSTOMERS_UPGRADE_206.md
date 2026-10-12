# Upgrade 206 - Linked customer reservations

- Added optional customer foreign key to cashier reservation requests.
- Added authenticated permission-checked RPC to create customer-linked cashier requests.
- Added private customer reservation-history RPC and UI.
- Cashier can select an existing customer and auto-fill name/phone.
- Reservations remain pending until approval; no false visits or spend inferred.
- Anonymous public requests are not automatically matched by phone/name.
- Existing cashier RPC remains for older clients.
- Migration must be applied after 204 and 177; live testing pending.
