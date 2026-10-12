# Upgrade 1245 - Kitchen station access

Added Kitchen tab **Station POS Accounts**, linked from Kitchen > Stations. The station account directory includes unprovisioned stations so a supervisor can create the first station username/password. Existing station-account RPC hashes passwords and revokes prior sessions; never store passwords in client preferences. Employee assignment stays in Kitchen > Station Staff and employee MFA remains separate.

**Not verified:** Flutter compile, live Supabase migration, RLS/function tests, real station login and physical printer. Security concern to assess during Phase 4: server-side scope of global station supervisor permissions versus station-specific permissions, and proper isolation of station device tokens. Existing login is an Edge Function and is not replaced by this UI. Do not deploy without staging tests.
