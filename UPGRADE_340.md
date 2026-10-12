# Upgrade 340 — Public motel QR landing screen

- New separate `CustomerMotelRoomQrScreen` routed by `?motel_room_token=<uuid>`.
- Room lookup returns only registered room label, name and accommodation type.
- All private/transactional actions are visibly locked until a separate active-stay guest session exists.
- No cleaning option on motel QR screen; all six requested menu options are listed.
- Language keys added for English fallback, Arabic, Badini and Sorani (partial translation).
- Requires applying migration `20261010_340_motel_public_room_details.sql` after prior migrations.
- No Flutter compile or live Supabase test performed.
