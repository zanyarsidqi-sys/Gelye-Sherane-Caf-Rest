from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SQL=(ROOT/'supabase/migrations/20261011_1174_kitchen_item_station_labels.sql').read_text()
DART=(ROOT/'lib/shared/live_kitchen_panel.dart').read_text()

def test_kitchen_rpc_checks_permissions():
    assert "gs_can_access('kitchen','can_view')" in SQL
    assert 'from public, anon' in SQL
    assert 'to authenticated' in SQL

def test_station_mapping_uses_existing_tables():
    assert 'gs_cafe_product_preparation' in SQL
    assert 'gs_cafe_preparation_stations' in SQL
    assert 'Unassigned preparation station' in SQL

def test_flutter_renders_names_and_station():
    assert "rpc('gs_kitchen_order_item_details'" in DART
    assert "item['product_name']" in DART
    assert "item['station_name']" in DART
