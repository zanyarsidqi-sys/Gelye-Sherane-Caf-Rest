#!/usr/bin/env python3
"""Two-session, read-only PostgreSQL row-lock regression test.

Requires psycopg 3 and TEST_DATABASE_URL pointing to an isolated STAGING DB.
No checkout gates are enabled; no payment/order rows are modified.
"""
import os,sys
try:
 import psycopg
 from psycopg.errors import LockNotAvailable
except ImportError:
 sys.exit('Install psycopg 3: pip install "psycopg[binary]"')

url=os.getenv('TEST_DATABASE_URL')
if not url: sys.exit('Set TEST_DATABASE_URL for a STAGING PostgreSQL database')
if os.getenv('CONFIRM_STAGING')!='YES':
 sys.exit('Set CONFIRM_STAGING=YES to confirm this is not production')

with psycopg.connect(url,autocommit=False) as a, psycopg.connect(url,autocommit=False) as b:
 with a.cursor() as ca,b.cursor() as cb:
  ca.execute('SELECT id FROM public.gs_orders ORDER BY id LIMIT 1')
  row=ca.fetchone()
  if not row: sys.exit('SKIP: staging fixture needs at least one order')
  oid=row[0]
  ca.execute('SELECT id FROM public.gs_orders WHERE id=%s FOR UPDATE',(oid,))
  # A second session must NOT be able to acquire the same order lock.
  try:
   cb.execute('SELECT id FROM public.gs_orders WHERE id=%s FOR UPDATE NOWAIT',(oid,))
  except LockNotAvailable:
   b.rollback()
   print('PASS: simultaneous session blocked by locked order row')
  else:
   b.rollback();a.rollback()
   sys.exit('FAIL: second session acquired a locked order')
  a.rollback()
  cb.execute('SELECT id FROM public.gs_orders WHERE id=%s FOR UPDATE NOWAIT',(oid,))
  assert cb.fetchone()[0]==oid
  b.rollback()
  print('PASS: lock released after first session rollback')
print('PASS: no rows changed; both transactions rolled back')
print('LIMITATION: this does not prove checkout RPC lock ordering, idempotency or provider verification')
