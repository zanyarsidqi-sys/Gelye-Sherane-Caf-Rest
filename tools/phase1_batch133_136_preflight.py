#!/usr/bin/env python3
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
s = (root/'lib/services/station_print_worker.dart').read_text()
t = (root/'test/station_print_worker_test.dart').read_text()
checks = {
 'public poll validates queue': 'pollOnce is public' in s and s.count("hasMatch(queueName)") >= 2,
 'claim station strict identifier': "hasMatch(stationKey)" in s,
 'formatter station strict identifier': "hasMatch(ticket.station)" in s,
 'queue direct regression': 'direct polling rejects unsafe queue' in t,
 'invisible claim regression': 'invisible station character' in t,
 'invisible format regression': 'ambiguous station identifiers' in t,
 'regression test total >= 19': t.count("  test('") >= 19,
}
for name, passed in checks.items(): print(('PASS' if passed else 'FAIL')+' '+name)
assert all(checks.values())
