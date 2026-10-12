from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2] / "lib/shared/live_kitchen_panel.dart"

def test_served_requires_fresh_items():
    s = SOURCE.read_text()
    block = s.split("if (next == 'served') {", 1)[1].split("final confirmed = await showDialog<bool>", 1)[0]
    assert "await _loadItems(id)" in block
    assert "handoverItems.isNotEmpty" in block

def test_handover_rejects_inconsistent_amounts():
    s = SOURCE.read_text()
    assert "BigInt.from(parsedQuantity) * BigInt.from(unitPrice) == BigInt.from(lineTotal)" in s
    assert "Handover blocked:" in s

def test_employee_generation_rechecked_before_confirmation():
    s = SOURCE.read_text()
    block = s.split("if (next == 'served') {", 1)[1].split("final confirmed = await showDialog<bool>", 1)[0]
    assert "queueGeneration != _loadGeneration" in block
    assert "_isCurrentEmployee(employeeId)" in block
