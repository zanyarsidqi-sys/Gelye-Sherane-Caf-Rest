# Upgrade 1225 — Station device session and heartbeat UI

Implemented Flutter station device login session service using flutter_secure_storage, a station-only device gate, periodic 30-second heartbeat, reconnection state, and local logout. The login component now stores the issued token via secure storage, never SharedPreferences. The public home page now has a separate Station POS Device entry that opens the station-only login flow without entering employee authentication.

IMPORTANT LIMITATIONS: Logout clears the local token but does not yet revoke the server session. Network errors show disconnected and retain the token for recovery; expired/revoked sessions clear it when the endpoint returns an invalid-session result. The Edge Function currently returns HTTP errors; verify SDK error handling so revocation reliably signs out. Heartbeat says the device is online only, not that a printer is ready. The printer-ready flag is always false until a real printer driver is integrated. Do not enable automatic printing yet.

No Flutter compilation, live Supabase calls, printer or device tests were performed. New flutter_secure_storage dependency needs platform build verification.
