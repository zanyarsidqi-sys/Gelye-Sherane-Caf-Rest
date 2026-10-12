# Upgrade 754 — Tables error disclosure fix

Changed `lib/sections/tables.dart:321` to replace a raw backend exception in an employee-visible error with a safe retry/manager instruction.

Before: `update(() => error = 'Could not save discount: $e');`

After: `update(() => error = 'Could not save discount: Please retry or contact a manager');`

Static source verification only; no Flutter runtime or Supabase tests performed.
