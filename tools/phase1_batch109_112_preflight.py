#!/usr/bin/env python3
"""Offline regression assertions. Not a Dart compiler or printer test."""
from pathlib import Path
p = Path(__file__).resolve().parents[1] / 'lib/services/station_print_worker.dart'
s = p.read_text()
checks = {
 'positive_ticket_metadata': 'ticket.ticketId <= 0 || ticket.attempt <= 0 || ticket.orderId <= 0' in s,
 'station_required': '_safe(ticket.station).isEmpty || ticket.items.isEmpty' in s,
 'error_reporter_is_guarded': 'void _reportError(Object error)' in s and 'catch (_)' in s,
 'all_external_callbacks_guarded': s.count('onError?.call(') == 1 and s.count('_reportError(') == 4,
 'uncertain_prints_not_acknowledged': 'if (result == StationPrintOutcome.uncertain)' in s and '_uncertain.add(identity);' in s,
 'worker_stop_guard': 'if (_stopped)' in s,
 'claim_identity_checked': 'ticket.ticketId != id || ticket.attempt != attempt' in s,
}
for key, ok in checks.items(): print(f'{"PASS" if ok else "FAIL"}: {key}')
assert all(checks.values()), checks
print(f'{len(checks)}/{len(checks)} offline checks passed')
