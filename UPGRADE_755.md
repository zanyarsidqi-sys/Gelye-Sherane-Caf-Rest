# Upgrade 755 — Tables error disclosure fix

Changed `lib/sections/tables.dart:426` to replace a raw backend exception in an employee-visible error with a safe retry/manager instruction.

Before: `if (mounted) setState(() => _error = 'Could not load table state: $e');`

After: `if (mounted) setState(() => _error = 'Could not load table state: Please retry or contact a manager');`

Static source verification only; no Flutter runtime or Supabase tests performed.
