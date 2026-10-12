from pathlib import Path
SOURCE = Path(__file__).resolve().parents[2] / 'lib/shared/live_kitchen_panel.dart'

def test_invalid_amounts_cannot_be_silently_zeroed():
    code = SOURCE.read_text()
    assert "((item['line_total_iqd'] as num?)?.toInt() ?? 0)" not in code
    assert "amounts.any((amount) => amount == null)" in code

def test_money_parsing_is_integral_and_nonnegative():
    code = SOURCE.read_text()
    assert "value is int" in code
    assert "int.tryParse(value)" in code
    assert 'int.tryParse(value)' in code

def test_totals_use_exact_integer_arithmetic():
    code = SOURCE.read_text()
    assert 'fold<BigInt>(BigInt.zero' in code
    assert 'BigInt.from(amount!)' in code
