from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
sql = (ROOT / "supabase/migrations/20261011_1184_station_preparation_ready.sql").read_text()
dart = (ROOT / "lib/shared/live_kitchen_panel.dart").read_text()

def test_ready_rpc_enforces_permissions_and_state():
    assert "gs_can_access('kitchen','can_edit')" in sql
    assert "v_state <> 'preparing'" in sql
    assert "where ticket_id=p_ticket_id for update" in sql

def test_ready_is_attributed_and_audited():
    assert "ready_by=auth.uid()" in sql
    assert "event_kind)" in sql
    assert "'ready'" in sql

def test_station_ready_does_not_serve_whole_order():
    section = sql.split('create or replace function public.gs_complete_station_preparation')[1].split('$$;')[0]
    assert 'update public.gs_orders' not in section
    assert "set state='ready'" in section

def test_station_ui_exposes_ready_action():
    assert "gs_complete_station_preparation" in dart
    assert "Mark station ready" in dart
    assert "Station preparation complete" in dart
