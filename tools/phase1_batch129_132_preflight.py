#!/usr/bin/env python3
from pathlib import Path
root=Path(__file__).resolve().parents[1]
s=(root/'lib/services/station_print_worker.dart').read_text()
t=(root/'test/station_print_worker_test.dart').read_text()
checks={
 'queue identifier validation': "^[a-zA-Z0-9_-]{1,64}$" in s,
 'station length cap': 'ticket.station.length > 128' in s,
 'item note cap': 'item.note.length > 2048' in s,
 'customer name cap': '(item.customerName?.length ?? 0) > 128' in s,
 'queue regression test': 'unsafe queue identifiers are rejected' in t,
 'oversized note test': 'overlong item notes are rejected' in t,
 'station metadata test': 'overlong station metadata is rejected' in t,
}
for name,passed in checks.items(): print(('PASS' if passed else 'FAIL')+' '+name)
assert all(checks.values())
