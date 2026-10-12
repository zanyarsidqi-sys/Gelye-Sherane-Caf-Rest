from pathlib import Path
root=Path(__file__).resolve().parents[2]
table=(root/'lib/shared/table_orders_replacement_delivery_progress.dart').read_text()
kitchen=(root/'lib/shared/kitchen_delivery_tasks_panel.dart').read_text()
assert 'generation == _loadGeneration' in table
assert '_loadGeneration++' in table
assert "gs_table_orders_replacement_delivery_progress" in table
assert "gs_replacement_handoff_consistency" in table
assert "gs_list_ready_delivery_tasks" in kitchen
assert "await _reload();" not in kitchen.split('Future<void> _action(')[1].split('Future<void> _assign(')[0]
assert "gs_record_station_handover" in kitchen
assert "gs_assign_delivery_employee" in kitchen
assert (root/'supabase/migrations/20261011_1212_replacement_delivery_consistency.sql').exists()
print('9/9 source integration assertions passed')
