#!/usr/bin/env python3
from pathlib import Path
root = Path(__file__).resolve().parents[1]
s = (root / 'lib/services/station_print_worker.dart').read_text()
t = (root / 'test/station_print_worker_test.dart').read_text()
checks = {
 'lifecycle epoch tracked': 'int _lifecycleEpoch = 0;' in s,
 'restart while busy rejected': "Cannot restart print worker while an earlier poll is active" in s,
 'epoch checked before physical print': s.count('pollEpoch != _lifecycleEpoch') == 2,
 'stop invalidates in-flight work': '_lifecycleEpoch++; _timer?.cancel()' in s,
 'mismatched ticket regression': 'mismatched resolved ticket is held' in t,
 'ack failure regression': 'acknowledgment failure never allows' in t,
 'stop during resolver regression': 'stop during ticket resolution prevents' in t,
}
for label, ok in checks.items(): print(('PASS' if ok else 'FAIL'), label)
assert all(checks.values())
