from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SQL=(ROOT/'supabase/migrations/20261011_1175_kitchen_required_acceptance_eta.sql').read_text()
DART=(ROOT/'lib/shared/live_kitchen_panel.dart').read_text()

def test_mandatory_eta_and_atomic_acceptance():
    for key in ('gs_accept_kitchen_order', 'p_estimated_minutes not between 1 and 480', 'transaction_timestamp()', 'gs_update_kitchen_status', 'gs_require_kitchen_acceptance_eta'):
        assert key in SQL

def test_employee_acceptance_requires_eta():
    assert "TextEditingController(text: '20')" in DART
    assert 'estimatedMinutes == null' in DART
    assert "rpc('gs_accept_kitchen_order'" in DART
    assert "'p_estimated_minutes': estimatedMinutes" in DART

def test_eta_available_to_views():
    assert 'kitchen_estimated_ready_at' in DART
    assert 'Estimated preparation:' in DART
    assert 'kitchen_accepted_by' in SQL
