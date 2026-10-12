from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SQL=(ROOT/'supabase/migrations/20261011_1176_kitchen_completed_history.sql').read_text()
DART=(ROOT/'lib/shared/live_kitchen_panel.dart').read_text()

def test_completion_time_is_stamped_by_database_not_device():
    assert 'new.kitchen_completed_at := transaction_timestamp()' in SQL
    assert "old.status is distinct from 'served' and new.status = 'served'" in SQL
    assert 'alter table public.gs_orders add column if not exists' in SQL

def test_completed_today_and_history_are_server_filtered():
    assert "requestedStatus == 'today_completed'" in DART
    assert "requestedStatus == 'history'" in DART
    assert ".gte('kitchen_completed_at'" in DART
    assert ".lt('kitchen_completed_at'" in DART
    assert 'DateTime.utc(' in DART
    assert "case 'yesterday'" in DART

def test_history_never_fabricates_old_completion_dates():
    assert 'Historic served rows remain NULL' in SQL
    assert 'Older served orders remain available under Served/All' in DART
