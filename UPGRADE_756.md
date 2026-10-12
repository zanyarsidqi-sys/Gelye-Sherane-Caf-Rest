# Upgrade 756 — Tables error disclosure fix

Changed `lib/sections/tables.dart:450` to replace a raw backend exception in an employee-visible error with a safe retry/manager instruction.

Before: `error = '$e';`

After: `error = 'Please retry or contact a manager';`

Static source verification only; no Flutter runtime or Supabase tests performed.
