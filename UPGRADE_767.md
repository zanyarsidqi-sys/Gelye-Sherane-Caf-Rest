# Upgrade 767 — Tables error disclosure fix

Changed `lib/sections/tables.dart:1427` to replace a raw backend exception in an employee-visible error with a safe retry/manager instruction.

Before: `SnackBar(content: Text('Unable to load review history: $e')));`

After: `SnackBar(content: Text('Unable to load review history: Please retry or contact a manager')));`

Static source verification only; no Flutter runtime or Supabase tests performed.
