from pathlib import Path
p=Path(__file__).resolve().parents[2]/'lib/shared/customer_table_bill_screen.dart'
s=p.read_text()
def test_countdown_updates_without_network_poll():
    assert 'Timer.periodic(const Duration(seconds: 30)' in s
    assert '_countdownTimer?.cancel();' in s
    assert 'readyAt.difference(_clockNow)' in s
    assert 'Past estimated ready time' in s
    assert "status == 'delivered'" in s
    assert "status == 'picked_up'" in s
    assert "status == 'ready'" in s
    assert 'DateTime.tryParse' in s
