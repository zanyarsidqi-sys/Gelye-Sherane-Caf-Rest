from pathlib import Path

SOURCE = (Path(__file__).resolve().parents[2] / 'lib/sections/products_inventory.dart').read_text()


def test_bigint_decimal_string_supported():
    assert "value is String && RegExp(r'^[0-9]+$').hasMatch(value)" in SOURCE
    assert 'int.tryParse(value)' in SOURCE


def test_quantity_and_minimum_are_normalized():
    assert "item['quantity'] = quantity;" in SOURCE
    assert "item['minimum_quantity'] = minimum;" in SOURCE
    assert "if (quantity == null) throw const FormatException" in SOURCE


def test_out_of_stock_uses_normalized_integer():
    assert SOURCE.count("r['quantity'] == 0") >= 2
    assert "num.tryParse('${r['quantity']}')" not in SOURCE
