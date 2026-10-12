# Upgrade 262: order timestamp visibility

- Staff order board displays the existing server-provided order created_at timestamp in Asia/Baghdad (UTC+03:00).
- Original order time is not modified when a status advances.
- Missing or invalid timestamps display an explicit unavailable message.
- Important: this is the ORDER timestamp, not a per-product addition time.
- Per-item event history, modification timestamps, preparation, collection and delivery timestamps, print revisions and customer timeline remain pending.
- Flutter compilation and live Supabase validation not performed.
