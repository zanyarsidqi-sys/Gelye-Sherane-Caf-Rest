from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


registry = source("lib/app/section_registry.dart")
assert len(re.findall(r"^\s*CafeSection\(", registry, re.MULTILINE)) == 26, (
    "The top-level section registry must contain exactly 26 entries."
)
assert "CafeSection('tables', \"Tables\", (context) => const TablesAndOrdersScreen())" in registry
assert not re.search(r"CafeSection\(\s*['\"]table_orders['\"]", registry)

combined = source("lib/sections/table_orders.dart")
assert "class TablesAndOrdersScreen" in combined
assert "additionalAccessSectionIds: const ['table_orders']" in combined
assert "TablesScreen(compact: true)" in combined
assert "TableOrdersScreen(compact: true)" in combined
assert "class TableOrdersWorkspace" in combined

tables = source("lib/sections/tables.dart")
assert "sectionId: 'tables'" in tables
assert "compact: compact" in tables

shell = source("lib/shared/section_shell.dart")
assert "acceptableSections.any(allowed.contains)" in shell
assert "if (widget.compact)" in shell

app = source("lib/app/cafe_app.dart")
assert "if (ids.contains('table_orders')) ids.add('tables')" in app
assert "sectionId == 'table_orders'" in app
assert "? 'tables'" in app
assert "section.id == 'tables' && _sections.contains('table_orders')" in app
assert "TablesAndOrdersScreen(initialTabIndex: 1)" in app

access_panel = source("lib/shared/employee_access_panel.dart")
assert "My authorized sections ($sectionCount)" in access_panel
assert "Floor map & seating:" in access_panel
assert "Live orders:" in access_panel

migration = source(
    "supabase/migrations/20261014170000_tables_orders_merge.sql"
).lower()
assert "delete from public.management_sections" in migration
assert "catalog_count_after <> 34" in migration
assert "permission_digest_after is distinct from permission_digest_before" in migration
for forbidden in (
    "insert into public.employee_section_permissions",
    "update public.employee_section_permissions",
    "delete from public.employee_section_permissions",
    "delete from public.gs_orders",
    "truncate ",
):
    assert forbidden not in migration, f"Unexpected destructive or grant-changing SQL: {forbidden}"

assert source("release/VERSION").strip() == "1.0.0.15"
workflow = source(
    ".github/workflows/validate-1.0.0.15-kitchen-consolidation.yml"
)
assert "staging/release-1.0.0.15-kitchen-consolidation" in workflow
assert "APP_RELEASE_VERSION=1.0.0.15" in workflow
assert "Write and verify canonical staging release metadata" in workflow
assert 'release.json' in workflow and 'release-version.txt' in workflow
assert 'Staging JavaScript SHA-256 mismatch.' in workflow

print("Tables consolidation contract passed: 26 top-level sections; feature grants preserved.")
