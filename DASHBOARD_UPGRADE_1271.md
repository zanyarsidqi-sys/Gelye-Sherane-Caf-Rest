# Dashboard upgrade 1271

## Change
The successful Dashboard snapshot timestamp now displays both the device-local calendar date and local time, using Flutter Material localizations. Previously only the time was shown, which could mislead staff reviewing a snapshot from a previous day.

## Scope
Changed only `lib/screens/dashboard/dashboard_screen.dart`. Existing snapshot visibility rules, refresh, authorization, and cards are unchanged.

## Verification
ZIP integrity and static source assertions checked. Flutter SDK/device and Supabase tests not available in this environment.
