#!/usr/bin/env python3
from pathlib import Path
root=Path(__file__).resolve().parents[1]
s=(root/'lib/services/station_print_worker.dart').read_text()
t=(root/'test/station_print_worker_test.dart').read_text()
checks={
 'post-print shutdown guard': 'final result = await printer.print(output);\n      // The device write may finish after stop().' in s,
 'post-print lifecycle epoch': 'if (_stopped || pollEpoch != _lifecycleEpoch) {' in s[s.index('final result = await printer.print(output);'):],
 'ACK occurs after post-print guard': s.index('final result = await printer.print(output);') < s.index('completed after worker shutdown') < s.index('await (ackTicket ?? session.acknowledgePrintTicket)'),
 'deferred printer adapter': 'class _DeferredPrinter implements StationPrinterAdapter' in t,
 'printed after stop test': "test('stop during physical printing holds ticket without ACK'" in t,
 'failed after stop test': "test('stop during confirmed printer failure also holds ticket'" in t,
 'existing tests retained': t.count("  test('") >= 10,
}
for k,v in checks.items(): print(('PASS' if v else 'FAIL'),k)
assert all(checks.values())
