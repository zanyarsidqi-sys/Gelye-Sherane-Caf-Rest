#!/usr/bin/env python3
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
resolver = (root/'lib/services/secure_station_ticket_resolver.dart').read_text()
tests = (root/'test/secure_station_ticket_resolver_test.dart').read_text()
checks = {
 'supported kind allowlist': 'supportedKinds.contains(kind.toUpperCase())' in resolver,
 'parser validates formatter': 'StationTicketFormatter.format(ticket);' in resolver,
 'parser returns validated ticket': 'return ticket;' in resolver,
 'unsupported kind test': 'unsupported immutable ticket kind' in tests,
 'valid revision test': 'valid revision kind' in tests,
 'total print size test': 'total receipt size is bounded' in tests,
}
for name, ok in checks.items(): print(('PASS' if ok else 'FAIL') + ': ' + name)
assert all(checks.values())
print(f'{sum(checks.values())}/{len(checks)} checks passed')
