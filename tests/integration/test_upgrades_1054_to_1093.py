from pathlib import Path
import re
BASE = Path(__file__).resolve().parents[2]
REG = (BASE / 'lib/app/section_registry.dart').read_text()
NAMES = re.findall(r"CafeSection\(\s*'([a-z_]+)'\s*,", REG)

def test_35_unique_sections_registered():
    assert len(NAMES) == len(set(NAMES)) == 35

def test_all_sections_have_permission_wrapper():
    for name in NAMES:
        text = (BASE / 'lib/sections' / (name + '.dart')).read_text()
        assert "../shared/section_shell.dart" in text, name
        assert ("sectionId: '" + name + "'" in text or 'sectionId: "' + name + '"' in text), name

def test_five_sections_gated_before_content():
    for name in ('device_layout_mode','invoices_payments','notifications','offline_mode_synchronization','payments_management'):
        text = (BASE / 'lib/sections' / (name + '.dart')).read_text()
        assert 'authorizedContent:' in text
        assert 'SectionShell(' in text

def test_no_duplicate_section_registry():
    assert len(set(NAMES)) == 35
