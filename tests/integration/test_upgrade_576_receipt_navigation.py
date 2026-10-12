from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = (ROOT / 'lib/sections/table_orders.dart').read_text()

def test_receipt_history_opens_existing_reconciliation():
    assert "_lookupReplacementRequestId(initialRequestId: id);" in SRC
    assert "final id = entry['request_id']?.toString();" in SRC
    assert "Navigator.pop(ctx);" in SRC

def test_manual_lookup_remains_available():
    assert 'Future<void> _lookupReplacementRequestId({String? initialRequestId})' in SRC
    assert "TextEditingController(text: initialRequestId ?? '')" in SRC
    assert 'onPressed: () => _lookupReplacementRequestId(),' in SRC

def test_history_and_lookup_buttons_are_siblings():
    assert "label: const Text('My replacement receipts (all devices)'),\n        ),\n      ),\n      Align(" in SRC
