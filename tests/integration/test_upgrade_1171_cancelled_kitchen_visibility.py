from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
PANEL=(ROOT/'lib/shared/live_kitchen_panel.dart').read_text()
SCHEMA=(ROOT/'supabase/migrations/20261009_001_phase3_order_foundation.sql').read_text()

def test_cancelled_is_schema_status_and_kitchen_filter():
    assert "'cancelled'" in SCHEMA
    assert "'served', 'cancelled'" in PANEL

def test_cancelled_orders_are_visible_in_summary():
    assert "'ready', 'cancelled'" in PANEL

def test_terminal_orders_have_no_status_action():
    assert "'ready' => 'served'" in PANEL
    assert "_ => null" in PANEL
