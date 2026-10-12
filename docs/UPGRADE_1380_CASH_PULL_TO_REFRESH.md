# Upgrade 1380: Cash Reconciliation source-aligned mobile interaction

- Added Flutter Material RefreshIndicator around the existing order ListView, enabling native pull-to-refresh on iPhone/Android.
- AlwaysScrollableScrollPhysics permits the gesture with a short list. Refresh reissues only the existing authorized RPC; preserves filters and keeps backend errors visible through FutureBuilder.
- Added a Material Divider immediately before the existing bottom-of-list total, matching the source-aligned preview.
- No new permissions, payment actions, invoice print/save or attestation behavior.
- Verified archive CRC, original entry preservation and static source anchors. Flutter SDK and live Supabase unavailable, so no visual percentage is verified.
