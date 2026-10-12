"""Offline release gate. Usage: python tools/verify_kitchen_release_1150.py"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / "supabase" / "migrations"


def verify(root=ROOT):
    failures = []
    for number, slug in [(1142, "kitchen_served_item_integrity"),
                         (1143, "kitchen_served_item_row_locks"),
                         (1144, "kitchen_served_item_immutability")]:
        matches = list((root / "supabase" / "migrations").glob(f"*_{number}_{slug}.sql"))
        if len(matches) != 1:
            failures.append(f"Expected one migration {number} ({slug}), found {len(matches)}")
    migrations = list((root / "supabase" / "migrations").glob("*.sql"))
    for n in (1142,1143,1144):
        if not any(re.search(rf"_{n}_", p.name) for p in migrations):
            failures.append(f"Missing migration {n}")
    for n in (1145,1146,1147,1149):
        if not list((root / "supabase" / "verification").glob(f"kitchen_{n}_*.sql")):
            failures.append(f"Missing staging verification {n}")
    if not (root / "tests/integration/test_upgrade_1149_deployment_gate.py").is_file():
        failures.append("Missing prior regression test")
    return failures

if __name__ == "__main__":
    errors=verify()
    for error in errors:
        print("FAIL:", error)
    if errors:
        sys.exit(1)
    print("PASS: migration and staging verification artifacts present. NOT a live acceptance test.")
