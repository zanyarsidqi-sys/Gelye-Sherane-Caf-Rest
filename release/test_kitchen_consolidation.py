from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


registry = read("lib/app/section_registry.dart")
registered = re.findall(r"^\s*CafeSection\(", registry, re.MULTILINE)
assert len(registered) == 26, f"Expected 26 visible entries, got {len(registered)}"
assert "additionalAccessSectionIds: [" in registry
assert all(
    f"'{key}'" in registry
    for key in ("menu", "products_inventory", "nargile_management")
)

kitchen = read("lib/sections/kitchen.dart")
assert "additionalAccessSectionIds: const [" in kitchen
assert "EmployeePermissionService().getSectionPermissions()" in kitchen
assert "grants['menu']?.canView == true" in kitchen
assert "grants['products_inventory']?.canView == true" in kitchen
assert "grants['nargile_management']?.canView == true" in kitchen
assert "MenuScreen(compact: true)" in kitchen
assert "ProductsInventoryScreen(compact: true)" in kitchen
assert "NargileManagementScreen(compact: true)" in kitchen
assert "LiveKitchenPanel()" in kitchen
assert "StationPrintReviewPanel()" in kitchen

for path, permission_id in (
    ("lib/sections/menu.dart", "menu"),
    ("lib/sections/products_inventory.dart", "products_inventory"),
    ("lib/sections/nargile_management.dart", "nargile_management"),
):
    source = read(path)
    assert f'sectionId: "{permission_id}"' in source or \
        f"sectionId: '{permission_id}'" in source
    assert "compact: compact" in source

app = read("lib/app/cafe_app.dart")
assert "section.isVisibleTo(_sections)" in app
assert "additionalAccessSectionIds: section.additionalAccessSectionIds" in app
assert "kitchenMergedSectionIds.any(_sections.contains)" in app
assert "initialSectionId: sectionId" in app

access_panel = read("lib/shared/employee_access_panel.dart")
assert "kitchenAreaIds" in access_panel
assert "title: const Text('Kitchen')" in access_panel
assert "authorized module(s)" in access_panel

migration = read(
    "supabase/migrations/20261014190000_kitchen_workspace_merge.sql"
).lower()
assert "catalog_count_before <> 29" in migration
assert "catalog_count_after <> 26" in migration
assert "delete from public.management_sections" in migration
assert "permission_digest_after is distinct from permission_digest_before" in migration
for merged_key in ("'menu'", "'products_inventory'", "'nargile_management'"):
    assert merged_key in migration
for forbidden in (
    "insert into public.employee_section_permissions",
    "update public.employee_section_permissions",
    "delete from public.employee_section_permissions",
    "delete from public.gs_orders",
    "delete from public.gs_payments",
    "delete from public.gs_inventory",
    "truncate ",
):
    assert forbidden not in migration, f"Unexpected data/grant mutation: {forbidden}"

assert read("release/VERSION").strip() == "1.0.0.15"
print(
    "Kitchen consolidation contract passed: 26 visible sections, retained "
    "module-level permissions, and catalog-only migration."
)
