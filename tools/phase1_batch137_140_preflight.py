#!/usr/bin/env python3
"""Offline Step 137-140 source regression checks; not a Dart compiler."""
from pathlib import Path
p=Path(__file__).resolve().parents[1]
s=(p/'lib/services/station_print_worker.dart').read_text()
t=(p/'test/station_print_worker_test.dart').read_text()
checks={
 'attempt tracking': 'final Set<String> _printedAttempts' in s,
 'claim replay guard': '_printedAttempts.contains(attemptIdentity)' in s,
 'success tracked before ack': s.index('_printedAttempts.add(attemptIdentity);') < s.index('await (ackTicket ??'),
 'duplicate print regression': 'duplicate server claim after printed ACK' in t,
 'duplicate failure regression': 'confirmed failure ACK is not repeated' in t,
 'review on duplicate': 'Previously printed ticket' in s,
}
for name, ok in checks.items(): print(('PASS' if ok else 'FAIL')+' '+name)
assert all(checks.values())
print(f'{len(checks)}/{len(checks)} passed')
