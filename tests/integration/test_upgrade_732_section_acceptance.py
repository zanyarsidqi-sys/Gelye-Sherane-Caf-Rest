import importlib.util
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('audit',ROOT/'tools_section_audit_732.py')
audit=importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)

def test_all_twenty_source_contracts():
    results=audit.run()['criteria']
    assert len(results)==20
    assert all(row['passed'] for row in results), [row for row in results if not row['passed']]

def test_seven_sections_are_separately_reported():
    result=audit.run()
    assert len(result['sections'])==7
    assert all(section['completion_percent'] is None for section in result['sections'].values())

def test_no_raw_supabase_exception_in_menu_create():
    source=(ROOT/'lib/shared/live_menu_product_create.dart').read_text()
    assert 'Could not save product: $error' not in source
    assert 'Could not save product. Check your permissions and connection.' in source
