# Upgrade 768 — Tables error disclosure fix

Changed `lib/sections/tables.dart:1439` to replace a raw backend exception in an employee-visible error with a safe retry/manager instruction.

Before: `SnackBar(content: Text('Financial review failed: $e')));`

After: `SnackBar(content: Text('Financial review failed: Please retry or contact a manager')));`

Static source verification only; no Flutter runtime or Supabase tests performed.
