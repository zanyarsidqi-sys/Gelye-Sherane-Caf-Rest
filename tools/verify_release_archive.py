#!/usr/bin/env python3
"""Read-only source archive integrity check; never connects to production."""
import sys, zipfile, hashlib, json
from pathlib import Path
p=Path(sys.argv[1])
with zipfile.ZipFile(p) as z:
    names=z.namelist()
    assert z.testzip() is None, "Corrupt ZIP member"
    assert len(names)==len(set(names)), "Duplicate ZIP entries"
    assert all(not x.startswith(("/", "\\")) and ".." not in x.split("/") for x in names), "Unsafe ZIP path"
    required=["gelye_cafe_rest/pubspec.yaml", "gelye_cafe_rest/supabase/functions/browser-push/index.ts", "gelye_cafe_rest/release/DISPATCH_POLICY_STAGING.md"]
    assert all(x in names for x in required), "Missing critical source"
    print(json.dumps({"result":"pass", "entries":len(names),"sha256":hashlib.sha256(p.read_bytes()).hexdigest()}))
