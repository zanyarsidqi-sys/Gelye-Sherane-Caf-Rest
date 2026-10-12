# Upgrade 1281 — Weekly trend failure recovery

Section 01 Dashboard only. Added an accessible Retry trend button when the seven-day Supabase request fails without data. The retry invokes the existing coordinated Dashboard refresh, preserving the overview/week business-day pinning and refresh lock. Retry is disabled during an active refresh. Empty and loading states remain distinct; existing features and permissions are retained.

Verification: ZIP CRC and preservation of all previous archive entries, targeted source assertions. Flutter SDK and live Supabase unavailable; runtime behavior unverified.
