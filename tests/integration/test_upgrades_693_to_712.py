from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]
class Upgrade693To712ContractTests(unittest.TestCase):
    def test_upgrade_693(self):
        self.assertIn('class DashboardScreen', (ROOT / 'lib/sections/dashboard.dart').read_text())
    def test_upgrade_694(self):
        self.assertIn("sectionId: 'dashboard'", (ROOT / 'lib/sections/dashboard.dart').read_text())
    def test_upgrade_695(self):
        self.assertIn('onAuthStateChange.listen', (ROOT / 'lib/shared/section_shell.dart').read_text())
    def test_upgrade_696(self):
        self.assertIn('class TablesScreen', (ROOT / 'lib/sections/tables.dart').read_text())
    def test_upgrade_697(self):
        self.assertIn("sectionId: 'tables'", (ROOT / 'lib/sections/tables.dart').read_text())
    def test_upgrade_698(self):
        self.assertIn('client.auth.currentUser?.id != user.id', (ROOT / 'lib/shared/section_shell.dart').read_text())
    def test_upgrade_699(self):
        self.assertIn('class TableOrdersScreen', (ROOT / 'lib/sections/table_orders.dart').read_text())
    def test_upgrade_700(self):
        self.assertIn('replacement', (ROOT / 'lib/sections/table_orders.dart').read_text())
    def test_upgrade_701(self):
        self.assertIn('_refreshAccess()', (ROOT / 'lib/shared/section_shell.dart').read_text())
    def test_upgrade_702(self):
        self.assertIn('class MotelOrdersScreen', (ROOT / 'lib/sections/motel_orders.dart').read_text())
    def test_upgrade_703(self):
        self.assertIn('MotelFoodBillingLedgerScreen()', (ROOT / 'lib/sections/motel_orders.dart').read_text())
    def test_upgrade_704(self):
        self.assertIn('MotelFoodRequestsScreen()', (ROOT / 'lib/sections/motel_orders.dart').read_text())
    def test_upgrade_705(self):
        self.assertIn('class KitchenScreen', (ROOT / 'lib/sections/kitchen.dart').read_text())
    def test_upgrade_706(self):
        self.assertIn('KitchenMotelFoodQueuePanel()', (ROOT / 'lib/sections/kitchen.dart').read_text())
    def test_upgrade_707(self):
        self.assertIn('KitchenScheduledMotelMealsPanel()', (ROOT / 'lib/sections/kitchen.dart').read_text())
    def test_upgrade_708(self):
        self.assertIn('LiveMenuProductEdit()', (ROOT / 'lib/sections/menu.dart').read_text())
    def test_upgrade_709(self):
        self.assertIn('tourismPrice: tourism', (ROOT / 'lib/sections/menu.dart').read_text())
    def test_upgrade_710(self):
        self.assertIn('requestedEmployeeId', (ROOT / 'lib/sections/products_inventory.dart').read_text())
    def test_upgrade_711(self):
        self.assertIn('historyEmployeeId', (ROOT / 'lib/sections/products_inventory.dart').read_text())
    def test_upgrade_712(self):
        self.assertIn('Inventory unavailable. Check your connection and permissions', (ROOT / 'lib/sections/products_inventory.dart').read_text())
