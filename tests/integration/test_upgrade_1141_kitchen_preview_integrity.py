from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2] / "lib/shared/live_kitchen_panel.dart"

def test_preview_and_handover_share_validation():
    code = SOURCE.read_text()
    assert "bool _validKitchenItem(Map<String, dynamic> item)" in code
    assert "handoverItems.every(_validKitchenItem)" in code
    assert "items.every(_validKitchenItem)" in code

def test_line_total_is_checked_exactly():
    code = SOURCE.read_text()
    assert "BigInt.from(quantity) * BigInt.from(unitPrice) == BigInt.from(lineTotal)" in code

def test_preview_rejects_invalid_items_before_sum():
    code = SOURCE.read_text()
    assert code.index("if (!items.every(_validKitchenItem))") < code.index("final total = items.fold<BigInt>")
