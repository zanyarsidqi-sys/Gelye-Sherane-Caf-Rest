# Upgrade 765 — Tables error disclosure fix

Changed `lib/sections/tables.dart:1235` to replace a raw backend exception in an employee-visible error with a safe retry/manager instruction.

Before: `if (dialogContext.mounted) change(() => previewError = '$e');`

After: `if (dialogContext.mounted) change(() => previewError = 'Please retry or contact a manager');`

Static source verification only; no Flutter runtime or Supabase tests performed.
