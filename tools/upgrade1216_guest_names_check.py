from pathlib import Path
p=Path(__file__).resolve().parents[1]/'lib/shared/live_kitchen_panel.dart'
s=p.read_text()
assert 'gsKitchenGuestDisplay' in s
assert s.count('Customer: ${gsKitchenGuestDisplay') >= 2
assert "return 'Table Order';" in s
assert "return 'Guest $number';" in s
assert 'Unnamed guest' not in s and 'Guest (unnamed)' not in s
print('Upgrade 1216: 5/5 source checks passed')
