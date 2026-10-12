# Upgrade 761 — Tables error disclosure fix

Changed `lib/sections/tables.dart:940` to replace a raw backend exception in an employee-visible error with a safe retry/manager instruction.

Before: `if (mounted) setState(() => _error = 'Guest move request was not submitted: $e');`

After: `if (mounted) setState(() => _error = 'Guest move request was not submitted: Please retry or contact a manager');`

Static source verification only; no Flutter runtime or Supabase tests performed.
