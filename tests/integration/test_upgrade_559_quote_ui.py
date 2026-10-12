from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "lib/sections/table_orders.dart").read_text()

class ReplacementQuoteUiContracts(unittest.TestCase):
    def test_reason_changes_refresh_dialog_action(self):
        self.assertIn('onChanged: (_) => updateDialog(() {})', SOURCE)
        self.assertIn('reason.text.trim().length < 5', SOURCE)
    def test_quote_totals_are_checked(self):
        for key in ('old_unit_price_iqd', 'new_unit_price_iqd', 'old_line_total_iqd', 'new_line_total_iqd', 'difference_iqd'):
            self.assertIn("quotedIqd('" + key + "')", SOURCE) if key != 'new_unit_price_iqd' else self.assertIn("quotedIqd('new_unit_price_iqd')", SOURCE)
    def test_fractional_quote_values_rejected(self):
        self.assertIn('if (value is! int)', SOURCE)

if __name__ == '__main__': unittest.main()
