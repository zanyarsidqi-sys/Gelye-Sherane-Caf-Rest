# Dashboard Upgrade 1307

Section 01 only. Harden the shared IQD formatter for Dashboard overview and detail figures: reject non-numeric, non-finite, fractional and web-unsafe values instead of silently truncating or rounding them. Preserve valid whole IQD, signed adjustments, and missing-value placeholder. Weekly response validation and all other project files are retained.

Verification: archive integrity and static source assertions. Flutter compilation, Supabase integration, and real device tests were not available.
