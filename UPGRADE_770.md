# Upgrade 770 — Tables error disclosure fix

Changed `lib/sections/tables.dart:1529` to replace a raw backend exception in an employee-visible error with a safe retry/manager instruction.

Before: `SnackBar(content: Text('QR regeneration failed: $e')));`

After: `SnackBar(content: Text('QR regeneration failed: Please retry or contact a manager')));`

Static source verification only; no Flutter runtime or Supabase tests performed.
