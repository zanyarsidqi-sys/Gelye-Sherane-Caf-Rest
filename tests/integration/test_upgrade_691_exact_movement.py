from pathlib import Path

SRC = Path(__file__).resolve().parents[2] / 'lib/sections/products_inventory.dart'

def test_signed_bigint_parser():
    s = SRC.read_text()
    assert "static int? _movementInteger(Object? value)" in s
    assert "RegExp(r'^-?[0-9]+$')" in s
    assert "return int.tryParse(value);" in s

def test_history_does_not_round_bigint():
    s = SRC.read_text()
    assert "final delta = _movementInteger(row['delta']);" in s
    assert "num.tryParse('${row['delta']}')" not in s
    assert "parsedDelta.roundToDouble()" not in s

def test_invalid_delta_distinguished_from_zero():
    s = SRC.read_text()
    assert "delta == null ? 'Unknown movement'" in s
