#!/usr/bin/env python3
from pathlib import Path
root=Path(__file__).resolve().parents[1]
s=(root/'lib/services/station_print_worker.dart').read_text()
t=(root/'test/station_print_worker_test.dart').read_text()
checks={
 'claimed identity captured before payload validation':s.index("claimedIdentity = '$queueName:$id'") < s.index("throw StateError('Invalid ticket claim')"),
 'station key sanitized':"stationKey != StationTicketFormatter._safe(stationKey)" in s,
 'receipt item cap':"ticket.items.length > 500" in s,
 'malformed station regression':"malformed claimed station is held" in t,
 'invalid attempt regression':"invalid attempt retains valid claim identity" in t,
 'oversized receipt regression':"formatter rejects oversized item lists" in t,
}
for k,v in checks.items():print(('PASS' if v else 'FAIL')+' '+k)
assert all(checks.values())
