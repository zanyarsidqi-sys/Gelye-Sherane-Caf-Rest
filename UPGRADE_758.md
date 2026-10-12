# Upgrade 758 — Tables error disclosure fix

Changed `lib/sections/tables.dart:573` to replace a raw backend exception in an employee-visible error with a safe retry/manager instruction.

Before: `if (dialogContext.mounted) change(() => error = '$e');`

After: `if (dialogContext.mounted) change(() => error = 'Please retry or contact a manager');`

Static source verification only; no Flutter runtime or Supabase tests performed.
