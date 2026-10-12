"""Execute Kitchen staging checks via psql and fail closed on any false result.

Requires DATABASE_URL for a *staging* Postgres instance and psql on PATH.
Does not print credentials, and never changes application data.
"""
import argparse
import csv
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CHECKS = [
    ROOT / 'supabase/verification/kitchen_1145_readiness.sql',
    ROOT / 'supabase/verification/kitchen_1146_semantic_readiness.sql',
    ROOT / 'supabase/verification/kitchen_1147_access_readiness.sql',
    ROOT / 'supabase/verification/kitchen_1149_deployment_gate.sql',
]


def parse_check_rows(output: str) -> list[tuple[str, bool]]:
    """Read two- or three-column CSV rows: check name, boolean, optional reason."""
    rows = list(csv.reader(io.StringIO(output)))
    if not rows:
        raise ValueError('No verification rows returned')
    checked = []
    for row in rows:
        if len(row) < 2:
            raise ValueError(f'Malformed verification row: {row!r}')
        name, flag = row[0].strip(), row[1].strip().lower()
        if not name or flag not in ('t', 'f', 'true', 'false'):
            raise ValueError(f'Unexpected check name or boolean value: {row!r}')
        checked.append((name, flag in ('t', 'true')))
    return checked


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--staging', action='store_true', help='Explicitly confirm target is staging')
    args = parser.parse_args(argv)
    if not args.staging:
        print('Refusing: pass --staging after checking DATABASE_URL points to staging', file=sys.stderr)
        return 2
    if not os.environ.get('DATABASE_URL'):
        print('Refusing: DATABASE_URL must be set', file=sys.stderr)
        return 2
    if not shutil.which('psql'):
        print('Refusing: psql executable not installed', file=sys.stderr)
        return 2
    all_passed = True
    for sql in CHECKS:
        if not sql.is_file():
            print(f'MISSING: {sql.name}', file=sys.stderr)
            all_passed = False
            continue
        # --no-psqlrc avoids local client configuration; ON_ERROR_STOP fails closed.
        proc = subprocess.run(
            ['psql', '--no-psqlrc', '--set=ON_ERROR_STOP=1', '--csv', '--tuples-only',
             '--dbname', os.environ['DATABASE_URL'], '--file', str(sql)],
            capture_output=True, text=True, timeout=45,
        )
        if proc.returncode != 0:
            print(f'FAILED TO EXECUTE: {sql.name} (exit {proc.returncode})', file=sys.stderr)
            all_passed = False
            continue
        try:
            checks = parse_check_rows(proc.stdout)
        except ValueError as exc:
            print(f'INVALID RESULTS: {sql.name}: {exc}', file=sys.stderr)
            all_passed = False
            continue
        failed = [name for name, passed in checks if not passed]
        print(f'{sql.name}: {len(checks) - len(failed)}/{len(checks)} passed')
        for name in failed:
            print(f'  FAIL: {name}')
        all_passed = all_passed and not failed
    if all_passed:
        print('Staging schema/authorization checks passed; functional acceptance remains pending.')
        return 0
    print('Kitchen staging deployment gate FAILED', file=sys.stderr)
    return 1


if __name__ == '__main__':
    raise SystemExit(main())
