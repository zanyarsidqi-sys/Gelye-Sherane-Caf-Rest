# Professional iPhone visual upgrade — first implementation pass

Source: Gelye_Cafe_Rest.zip, October 11, 2026.

## Implemented
- Added `lib/shared/gelye_professional_theme.dart`: navy/gold Material 3 light and dark themes, consistent cards, inputs, focus states, buttons, tab bar, bottom navigation, and app bars.
- Connected theme to `lib/app/cafe_app.dart` without modifying existing Supabase authorization, payments, order logic, printing or routing.
- Existing user-selected light/dark preference remains intact.

## Still to implement to match the concept image
- Rework dashboard card composition, floor-plan tiles, table/order detail panels, menu photos, payment screens, reports and mobile bottom navigation at widget level.
- Audit each of the 35 screens for overflow, contrast, accessibility and Arabic/Kurdish localization.
- Confirm currency presentation remains IQD (concept art shows USD and is not authoritative).
- No fake orders, customer records, staff identities, prices or revenue figures should be introduced.

## Verification
- ZIP structure and textual patch checked. Flutter/Dart compilation and device screenshots NOT run; requires local SDK, Supabase staging credentials, and authorized test accounts.
