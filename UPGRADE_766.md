# Upgrade 766 — Tables error disclosure fix

Changed `lib/sections/tables.dart:1377` to replace a raw backend exception in an employee-visible error with a safe retry/manager instruction.

Before: `SnackBar(content: Text('Finance review not recorded: $e')),`

After: `SnackBar(content: Text('Finance review not recorded: Please retry or contact a manager')),`

Static source verification only; no Flutter runtime or Supabase tests performed.
