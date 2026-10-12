#!/usr/bin/env python3
"""Step 141-144 offline regression; not a Dart compiler substitute."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
s=(root/'lib/services/station_print_worker.dart').read_text()
t=(root/'test/station_print_worker_test.dart').read_text()
checks={
 'mandatory claimed order id': 'orderId is! int || orderId <= 0' in s,
 'strict resolved order match': 'ticket.orderId != orderId ||' in s,
 'manual review for malformed claim': 'if (claimedIdentity != null) _uncertain.add(claimedIdentity);' in s,
 'missing order id test': "test('missing order identity cannot reach resolver" in t,
 'noninteger order id test': "test('noninteger order identity is rejected" in t,
 'order mismatch test': "test('claimed order mismatch cannot print" in t,
 'ticket identity guard': 'ticket.ticketId != id || ticket.attempt != attempt' in s,
}
# Verify all local relative Dart imports in project source/test.
missing=[]
for p in list((root/'lib').rglob('*.dart'))+list((root/'test').rglob('*.dart')):
 for imp in re.findall(r"^import\s+['\"]([^'\"]+)['\"]",p.read_text(),re.M):
  if imp.startswith('.') and not (p.parent/imp).exists():missing.append(str(p.relative_to(root))+':'+imp)
checks['relative imports resolve']=not missing
for key,passed in checks.items():print(('PASS' if passed else 'FAIL'),key)
if missing:print('Missing:',missing)
assert all(checks.values())
