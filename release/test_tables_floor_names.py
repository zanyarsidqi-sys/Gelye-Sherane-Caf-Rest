from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = (ROOT / "supabase/migrations/20261013_1500_table_floor_names.sql").read_text()
TABLES = (ROOT / "lib/sections/tables.dart").read_text()
RESERVATION = (ROOT / "lib/shared/staff_specific_reservation_screen.dart").read_text()
WORKFLOW = (ROOT / ".github/workflows/validate-1.0.0.6-tables.yml").read_text()


class TablesFloorNameTests(unittest.TestCase):
    def test_floor_names_have_safe_default_and_length_constraint(self):
        self.assertIn(
            "add column if not exists floor_name text not null default 'Unassigned floor'",
            MIGRATION,
        )
        self.assertIn("gs_cafe_tables_floor_name_length", MIGRATION)

    def test_floor_rpcs_require_permission_and_keep_immutable_audit(self):
        self.assertIn("gs_create_cafe_table_in_floor", MIGRATION)
        self.assertIn("gs_set_cafe_table_floor", MIGRATION)
        self.assertEqual(
            MIGRATION.count("not public.gs_can_access('tables', 'can_edit')"),
            2,
        )
        self.assertIn("gs_table_floor_event_immutable", MIGRATION)
        self.assertIn(
            "revoke all on public.gs_table_floor_events from public, anon, authenticated",
            MIGRATION,
        )
        self.assertIn(
            "Cannot change floor while the table is occupied or needs cleaning",
            MIGRATION,
        )

    def test_reservation_choices_reuse_floor_names_and_keep_party_size_filter(self):
        self.assertIn("gs_public_reservable_table_options", MIGRATION)
        self.assertIn("left join public.gs_cafe_tables c", MIGRATION)
        self.assertIn("t.table_label::numeric between 1 and 2147483647", MIGRATION)
        self.assertIn("coalesce(c.floor_name, 'Unassigned floor')", MIGRATION)
        self.assertIn("t.seats >= p_party_size and p_party_size between 1 and 30", MIGRATION)
        self.assertIn("to anon, authenticated", MIGRATION)

    def test_tables_ui_creates_assigns_displays_and_filters_floors(self):
        self.assertIn("floor_name,updated_at", TABLES)
        self.assertIn("'gs_create_cafe_table_in_floor'", TABLES)
        self.assertIn("'gs_set_cafe_table_floor'", TABLES)
        self.assertIn("Floor: ${_floorName(t)}", TABLES)
        self.assertIn("_floorName(t) == _floorFilter", TABLES)
        self.assertIn("_floorName(t).toLowerCase().contains(query)", TABLES)

    def test_reservation_form_collects_party_size_for_capacity_checks(self):
        self.assertIn("labelText: 'How many guests?'", RESERVATION)
        self.assertGreaterEqual(RESERVATION.count("'p_party_size': _guests"), 3)

    def test_candidate_ci_is_staging_only_and_does_not_deploy(self):
        self.assertIn("staging/release-1.0.0.6-tables", WORKFLOW)
        self.assertIn("flutter analyze --no-fatal-infos", WORKFLOW)
        self.assertIn("flutter test", WORKFLOW)
        self.assertIn("Upload staging artifact", WORKFLOW)
        self.assertNotIn("deploy-pages", WORKFLOW)


if __name__ == "__main__":
    unittest.main()
