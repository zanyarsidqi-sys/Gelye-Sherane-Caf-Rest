from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
SQL = (ROOT / 'supabase/migrations/20261011_1188_station_overdue_alerts.sql').read_text()
UI = (ROOT / 'lib/shared/live_kitchen_panel.dart').read_text()

def test_only_overdue_preparing_active_tickets():
    assert "p.state='preparing'" in SQL
    assert 'p.estimated_ready_at < transaction_timestamp()' in SQL
    assert "o.status in ('preparing','ready')" in SQL

def test_authorization_and_scoped_visibility():
    assert "gs_can_access('kitchen','can_view')" in SQL
    assert 'p.accepted_by=v_user or v_manager' in SQL
    assert 'revoke all on function public.gs_kitchen_overdue_station_alerts() from public,anon' in SQL

def test_in_app_alert_panel():
    assert 'Widget _overdueStationAlerts()' in UI
    assert "rpc('gs_kitchen_overdue_station_alerts')" in UI
    assert '    _overdueStationAlerts(),' in UI
