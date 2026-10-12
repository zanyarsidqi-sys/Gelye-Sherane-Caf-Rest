#!/usr/bin/env python3
"""Offline, fail-closed verification of DELETE RPC source guards; not a DB test."""
from pathlib import Path
import re,sys
root=Path(__file__).resolve().parents[1]
m=root/'supabase'/'migrations'
checks={
 '20261010_183_counter_draft_item_removal.sql':{
  'authenticated_permission':r"auth\.uid\(\) is null or not public\.gs_can_access\('table_orders','can_edit'\)",
  'row_lock':r'where id=p_request_id for update',
  'pending_only':r"v_request\.status <> 'pending'",
  'delete_scoped':r'delete from public\.gs_counter_order_request_items\s+where id=p_item_id and request_id=p_request_id',
  'execution_grant':r'grant execute on function public\.gs_remove_counter_request_menu_item\(bigint,bigint\)\s+to authenticated',
 },
 '20261010_294_event_scope_safety.sql':{
  'authorized_editor':r"auth\.uid\(\) is null or not public\.cafe_can_manage_website\('edit'\)",
  'event_row_lock':r'where id=p_event_id for update',
  'pending_only':r"e\.status <> 'pending_admin'",
  'table_row_lock':r'order by t\.id for update',
  'delete_scoped':r'delete from public\.gs_event_requested_tables where event_id=e\.id',
  'execution_grant':r'grant execute on function public\.gs_staff_set_event_requested_tables\(uuid,uuid\[\]\) to authenticated',
 }
}
failed=[]
for name, rules in checks.items():
 p=m/name
 if not p.exists():
  failed.append('missing '+name);continue
 s=p.read_text(encoding='utf-8')
 for label, pattern in rules.items():
  ok=bool(re.search(pattern,s,re.I|re.S))
  print(('PASS' if ok else 'FAIL'),name,label)
  if not ok:failed.append(name+': '+label)
print('Checks:',sum(map(len,checks.values())),'Failed:',len(failed))
sys.exit(bool(failed))
