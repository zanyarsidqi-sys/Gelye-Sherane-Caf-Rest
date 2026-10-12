# Upgrade 279 - Specific table reservations

- Public website backend: list reservable tables by capacity, check time-slot availability, and request a particular table/date/time (pending approval).
- Staff backend: create an approved booking for a customer or confirm a pending request for the customer-selected table.
- Serialized booking lock and overlap checks prevent double confirmation; review audit is written.
- Existing cancellation workflow remains in place.
- Reservation customer-facing date/time selector and employee form are NOT yet wired into Flutter screens.
- Anonymous booking RPC requires production edge rate limiting/CAPTCHA before exposure.
- Live Supabase migration and Flutter compilation have NOT been tested.
