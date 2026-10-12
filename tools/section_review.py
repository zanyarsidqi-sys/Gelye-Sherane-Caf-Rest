#!/usr/bin/env python3
"""Read-only, reproducible static section audit. Does not verify Flutter or Supabase."""
from pathlib import Path
import re, collections, json
ROOT = Path(__file__).resolve().parents[1]
SECTIONS = {'01 Dashboard':'dashboard', '02 Tables':'tables', '03 Table Orders':'table_orders', '04 Motel Orders':'motel_orders'}
result = {'verification':'static source checks only; Flutter, Supabase and device tests NOT performed','sections':{}}
for name, stem in SECTIONS.items():
    path = ROOT / 'lib' / 'sections' / (stem + '.dart')
    content = path.read_text() if path.exists() else ''
    result['sections'][name] = {'source_exists':path.is_file(),'bytes':len(content.encode()),'section_shell': 'SectionShell(' in content,'section_id_present': bool(re.search(r"sectionId:\s*['\"]"+stem+r"['\"]",content)),'rpc_references':len(re.findall(r"\.rpc\(",content))}
migrations=list((ROOT/'supabase'/'migrations').glob('*.sql'))
by_name=collections.Counter(x.name for x in migrations)
result['migrations']={'count':len(migrations),'duplicate_filenames':[x for x,n in by_name.items() if n>1]}
result['tests']={'dart_test_files':len(list((ROOT/'test').rglob('*_test.dart')))}
# Scan literal Flutter RPC names against SQL function declarations; dynamic calls remain out of scope.
all_sql='\n'.join(p.read_text(errors='replace') for p in migrations)
functions=set(re.findall(r'\b(?:create\s+or\s+replace\s+function|create\s+function)\s+(?:public\.)?\"?([a-zA-Z_][a-zA-Z_0-9]*)\"?\s*\(',all_sql,re.I))
for name,stem in SECTIONS.items():
    path=ROOT/'lib'/'sections'/(stem+'.dart')
    code=path.read_text(errors='replace') if path.exists() else ''
    refs=sorted(set(re.findall(r"\.rpc\(\s*['\"]([a-zA-Z_][a-zA-Z_0-9]*)['\"]",code)))
    result['sections'][name]['literal_rpc_names']=refs
    result['sections'][name]['rpc_not_declared_in_migrations']=[r for r in refs if r not in functions]
result['rpc_scan_note']='Unresolved names are review candidates; functions may be provided externally or by earlier deployment. This does not establish a runtime failure.'
result['sql_function_declarations']=len(functions)
# Cross-section integration references are scanned across shared Dart services too.
critical = {
 'table_reservation': ['gs_cancel_reservation', 'gs_check_in_cafe_reservation'],
 'table_order_fulfillment': ['gs_staff_table_order_board', 'gs_advance_table_item_fulfillment'],
 'motel_credit_security': ['gs_credit_my_authorization_requests'],
}
all_dart = '\n'.join(p.read_text(errors='replace') for p in (ROOT/'lib').rglob('*.dart'))
result['integration_reference_inventory'] = {
 area: {name: {'flutter_literal_reference': bool(re.search(r"\.rpc\(\s*['\"]"+re.escape(name)+r"['\"]",all_dart)), 'sql_declaration_present': name in functions} for name in names}
 for area,names in critical.items()
}
result['integration_note']='Reference inventory is not a runtime integration test; live database and device verification still required.'

print(json.dumps(result,indent=2))
