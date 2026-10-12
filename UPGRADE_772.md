# Upgrade 772 — Tables error disclosure fix

Changed `lib/sections/tables.dart:1561` to replace a raw backend exception in an employee-visible error with a safe retry/manager instruction.

Before: `refresh(() => error = 'Could not load notifications: $e');`

After: `refresh(() => error = 'Could not load notifications: Please retry or contact a manager');`

Static source verification only; no Flutter runtime or Supabase tests performed.
