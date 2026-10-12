# Upgrade 762 — Tables error disclosure fix

Changed `lib/sections/tables.dart:1007` to replace a raw backend exception in an employee-visible error with a safe retry/manager instruction.

Before: `if (mounted) setState(() => _error = 'Guest movement review failed: $e');`

After: `if (mounted) setState(() => _error = 'Guest movement review failed: Please retry or contact a manager');`

Static source verification only; no Flutter runtime or Supabase tests performed.
