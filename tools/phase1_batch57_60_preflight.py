#!/usr/bin/env python3
"""Step 57-60 offline Flutter source preflight; not a Dart compiler."""
from pathlib import Path
import re,sys
root=Path(__file__).resolve().parents[1]
source=root/'lib/app/cafe_app.dart'
s=source.read_text(encoding='utf-8')
checks={
 'timer does not invalidate in-flight review': 'if (!_verificationInFlight && !_sessionTerminated) _verify();' in s,
 'session change terminates protected route': '_sessionTerminated = true;\n        _lock();' in s,
 'dashboard callback checks permission snapshot': 'allowedSectionsSnapshot.contains(sectionId)' in s,
 'saved permission snapshot immutable': 'Set<String>.unmodifiable(result.allowedSections)' in s,
 'protected route checks AAL2': 'AuthenticatorAssuranceLevels.aal2' in s,
}
imports=re.findall(r"^import\s+['\"](\.\./[^'\"]+)['\"]\s*;",s,re.M)
checks['all relative imports resolve']=all((source.parent / imp).resolve().is_file() for imp in imports)
# Lightweight structural scan ignoring comments and quoted Dart strings.
stack=[]; state='code'; quote=''; i=0
while i<len(s):
 c=s[i]; nxt=s[i:i+2]
 if state=='line':
  if c=='\n':state='code'
 elif state=='block':
  if nxt=='*/':state='code';i+=1
 elif state=='string':
  if c=='\\':i+=1
  elif c==quote:state='code'
 else:
  if nxt=='//':state='line';i+=1
  elif nxt=='/*':state='block';i+=1
  elif c in ('\"',"'"):state='string';quote=c
  elif c in '({[':stack.append(c)
  elif c in ')}]':
   if not stack or stack.pop()!={' )':'(',')':'(',']':'[','}':'{'}[c]:
    checks['delimiter balance']=False;break
 i+=1
else:checks['delimiter balance']=not stack and state!='block'
for name,ok in checks.items():print(('PASS' if ok else 'FAIL'),name)
sys.exit(0 if all(checks.values()) else 1)
