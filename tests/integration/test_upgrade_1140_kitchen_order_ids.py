from pathlib import Path
S = (Path(__file__).resolve().parents[2] / "lib/shared/live_kitchen_panel.dart").read_text()

def test_order_id_parser_accepts_postgrest_integer_strings():
    assert "int? _validOrderId(dynamic value)" in S
    assert "int.tryParse(value)" in S
    assert "parsed > 0" in S

def test_queue_sort_uses_validated_ids():
    assert "_validOrderId(a['id']) ?? 0" in S
    assert "_validOrderId(b['id']) ?? 0" in S

def test_order_action_uses_validated_id():
    assert "final id = _validOrderId(order['id']);" in S
    assert "if (id == null || id <= 0)" in S
