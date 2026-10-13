from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCREEN = (ROOT / "lib/screens/dashboard/dashboard_screen.dart").read_text()
FOCUS = (ROOT / "lib/screens/dashboard/dashboard_focus.dart").read_text()
TEST = (ROOT / "test/dashboard_focus_test.dart").read_text()

assert "dashboardCardOrderForFocus(" in SCREEN
assert "available.intersection(focusSet)" in FOCUS
assert "'waiter': <String>{" in FOCUS
assert "'kitchen': <String>{" in FOCUS
assert "'occupied_tables'" in FOCUS
assert "'kitchen_queue'" in FOCUS
assert "ValueKey<String>('customers_today')" in SCREEN
assert "ValueKey<String>('tourism_customers')" in SCREEN
assert "Focus changes card order" not in SCREEN
assert "Focus cannot add a card that permissions did not provide" in TEST
print("Dashboard focus card filtering and permission boundary: PASS")
