#!/usr/bin/env python3
from pathlib import Path
root = Path(__file__).resolve().parents[1]
s = (root/'lib/services/secure_station_ticket_resolver.dart').read_text()
t = (root/'test/serialized_station_printer_test.dart').read_text()
checks = {
  'queue has terminal close state': 'bool _closed = false;' in s and 'void close()' in s,
  'queued prints stop on close': 'if (_closed) {\n        result.complete(StationPrintOutcome.uncertain);' in s,
  'new prints stop on close': 'if (_closed) return Future.value(StationPrintOutcome.uncertain);' in s,
  'lifecycle closes shared queue': '_sharedPrinter?.close();' in s,
  'queued shutdown regression': 'closing queue prevents queued second physical print' in t,
  'post-close regression': 'closed queue refuses new physical print requests' in t,
}
for name, ok in checks.items(): print(('PASS' if ok else 'FAIL') + ' ' + name)
assert all(checks.values())
print(f'{len(checks)}/{len(checks)} offline source checks passed; Dart execution not performed')
