from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SQL = (ROOT / 'supabase/migrations/20261011_1185_station_pickup_delivery.sql').read_text()
UI = (ROOT / 'lib/shared/live_kitchen_panel.dart').read_text()

def test_handover_auth_and_state_guards():
    for token in ("gs_can_access('kitchen','can_edit')", "v_prep.state <> 'ready'", "Pickup required before delivery", "already delivered", "for update"):
        assert token in SQL

def test_handover_audit_and_permissions():
    for token in ('picked_up_by','delivered_by','transaction_timestamp()', 'gs_cafe_station_preparation_events', 'revoke all on function', 'grant execute on function'):
        assert token in SQL

def test_flutter_station_handover_controls():
    for token in ('_stationHandoverPanel', 'gs_record_station_handover', 'gs_station_handover_details', 'Record pickup', 'Record delivery'):
        assert token in UI
