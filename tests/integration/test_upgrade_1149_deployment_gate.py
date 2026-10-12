from pathlib import Path
SQL=(Path(__file__).resolve().parents[2]/'supabase/verification/kitchen_1149_deployment_gate.sql').read_text().lower()
def test_gate_checks_security():
    for key in ('has_function_privilege','prosecdef','aclexplode','t.tgenabled','t.tgtype & 4','t.tgtype & 8','t.tgtype & 16'):
        assert key in SQL
def test_gate_read_only():
    assert 'with checks(' in SQL and 'select name,passed' in SQL
    assert 'insert into ' not in SQL and 'drop table ' not in SQL
def test_gate_not_claimed_as_live():
    assert 'does not test behavior' in SQL
