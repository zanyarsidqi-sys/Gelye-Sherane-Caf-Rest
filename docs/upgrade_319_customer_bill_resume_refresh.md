# Upgrade 319 — Customer bill lifecycle safety

- Revalidate the authorized visit and refresh gross order preview when the Flutter app resumes.
- Clear prior order rows and update timestamp at refresh start, preventing old gross amounts from being presented during reauthorization.
- Hide the gross total while loading or after a failed refresh.
- Keep generation-based protection against late responses from a prior visit.

This is **not** a payable balance. Financial reconciliation, Flutter compilation, and live Supabase testing remain outstanding.
