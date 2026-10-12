# Upgrade 337 — Global language selector

A language switcher is overlaid by the root MaterialApp builder, so it is available across the public customer routes, employee login, and all 35 staff sections. Choices: English, Arabic, Badini Kurdish, Sorani Kurdish. The selection persists on this device using the existing `gelye_cafe_language_v1` key, also used by Dictionary & Language preferences.

**Scope limitation:** This is the global language selection UI and persistence only. The majority of strings are still hardcoded in English; this does not claim complete translation, RTL layout, or server-side per-employee language synchronization. Those require a full localization pass and language dictionary integration.

**Testing:** Flutter SDK and live Supabase are not available in this environment; compilation and end-to-end verification remain pending.
