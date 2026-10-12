# Upgrade 281 — Public specific-table reservation selector

- Connected existing public Flutter reservation screen to upgrade 279 table options, availability and specific-table request RPCs.
- Customer selects party size, duration, local date/time, and a specific capacity-qualified table.
- Availability hint refreshes on changes; the backend revalidates upon submission.
- Request remains pending until staff approval; no private order or bill information is exposed.
- Existing employee workflows and all existing source files preserved.

## Unverified / release blockers
- Flutter SDK unavailable in this environment: compilation and device layout are not tested.
- Live Supabase migrations and RLS are not tested.
- Public anonymous RPC still requires production-grade rate limiting/CAPTCHA at the edge before exposure.
- Staff specific-table create/change Flutter screens remain to be wired in Upgrade 282.
- Local time display assumes the device timezone is Asia/Baghdad; explicit timezone handling remains to be implemented.
