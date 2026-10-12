# Upgrade 320 — Background privacy and foreground reauthorization

The customer bill screen clears visit-specific items and gross amounts when the app becomes inactive, hidden, or paused. Any outstanding request is invalidated by its generation number. When resumed, the screen reauthorizes the visit and loads a fresh snapshot, rather than showing an old bill. This also fixes the prior case where a pending request prevented a foreground refresh.

Verification: source reviewed and ZIP integrity checked; Flutter compilation and live Supabase testing were not available. The preview remains gross ordered items, not the final payable balance.
