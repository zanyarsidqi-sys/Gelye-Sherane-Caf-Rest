# Upgrade 753 — Tables error disclosure fix

Changed `lib/sections/tables.dart:289` to replace a raw backend exception in an employee-visible error with a safe retry/manager instruction.

Before: `error = 'Admin authorization or loading failed: $e';`

After: `error = 'Admin authorization or loading failed: Please retry or contact a manager';`

Static source verification only; no Flutter runtime or Supabase tests performed.
