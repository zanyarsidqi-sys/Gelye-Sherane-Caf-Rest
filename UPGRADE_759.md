# Upgrade 759 — Tables error disclosure fix

Changed `lib/sections/tables.dart:776` to replace a raw backend exception in an employee-visible error with a safe retry/manager instruction.

Before: `if (mounted) setState(() => _error = 'Reservation check-in failed: $e');`

After: `if (mounted) setState(() => _error = 'Reservation check-in failed: Please retry or contact a manager');`

Static source verification only; no Flutter runtime or Supabase tests performed.
