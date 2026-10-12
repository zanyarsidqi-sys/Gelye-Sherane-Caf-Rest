# Dashboard Upgrade 1285

## Change
Normalize the date picker's first/last/initial calendar values to local date-only DateTime objects constructed from the Baghdad (UTC+03) calendar date. Prevent device-timezone offsets from allowing future Baghdad dates or incorrectly restricting today's business day. Clamp a previously selected future date only for the picker display. No changes to RPCs, authorization, or other sections.

## Verification
ZIP CRC/integrity, preservation of all prior entries, and targeted source assertions. Flutter compilation and Supabase runtime not available here.
