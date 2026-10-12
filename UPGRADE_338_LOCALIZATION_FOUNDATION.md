# Upgrade 338 — First actual navigation localization pass

- Adds app-wide inherited language context using the persisted selection from Upgrade 337.
- Applies RTL directionality for Arabic and Sorani; LTR for English and Badini.
- Translates common management section titles and workspace headings in the navigation, with English fallback for incomplete dictionary entries.
- Preserves existing authentication, section permissions, room QR and scheduled meals.
- Full localization of all 35 screens, customer forms, validation and backend messages remains pending.
- Flutter SDK and live Supabase are unavailable; compile and end-to-end tests not performed.
