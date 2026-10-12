from pathlib import Path
import re, sys
root=Path(__file__).resolve().parents[1]
tests=[
("recipe edit permission","20261009_029_recipe_ingredient_consumption.sql",r"gs_can_access\('products_inventory','can_edit'\)"),
("counter pending guard","20261010_183_counter_draft_item_removal.sql",r"v_request.status <> 'pending'"),
("active jobs guard","20261010_199_active_job_capability_guards.sql",r"if v_active>0 then"),
("event permission","20261010_294_event_scope_safety.sql",r"cafe_can_manage_website\('edit'\)"),
]
files=list(root.rglob("*.sql"))
ok=True
for label,name,pattern in tests:
    matches=[p for p in files if p.name==name]
    passed=len(matches)==1 and bool(re.search(pattern,matches[0].read_text(),re.I))
    print(("PASS" if passed else "FAIL"),label)
    ok &= passed
sys.exit(0 if ok else 1)
