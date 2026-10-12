#!/usr/bin/env python3
"""Static regression checks for Upgrade 1240; does not compile Flutter."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
w=(root/'lib/services/station_print_worker.dart').read_text()
a=(root/'lib/shared/gelye_official_invoice_layout.dart').read_text()
b=(root/'lib/shared/gelye_invoice_templates.dart').read_text()
r=(root/'lib/services/station_print_review_service.dart').read_text()
assert "RegExp(r'[\\x00-\\x1f\\x7f]')" in w
assert "RegExp(r'\\s+')" in w
assert "RegExp(r'[\\\\x00-\\\\x1f\\\\x7f]')" not in w
assert "'total_minor','payment_status'" in a
assert "'total_minor':doc.totalMinor" in b
assert "uniqueRequestKey.trim().isEmpty" in r
print('Upgrade 1240 static regression checks passed (not runtime tests).')
