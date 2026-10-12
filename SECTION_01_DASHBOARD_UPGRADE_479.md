# Upgrade 479 — Permission-scoped operational ratios

Adds a read-only operational ratios section to the Dashboard: occupied/available table capacity, tourism share of occupied tables, and daily table/motel order mix. Ratios are shown only when all required server-authorized inputs are present, valid, and denominators are positive. No monetary totals or credit deductions are introduced.

**Estimated Section 01 development progress:** 82% (provisional).
**Verification:** ZIP structural validation only; Flutter compilation, live Supabase migration and integration tests not performed.
**Remaining:** validated financial KPIs, navigation, integration and live testing.
