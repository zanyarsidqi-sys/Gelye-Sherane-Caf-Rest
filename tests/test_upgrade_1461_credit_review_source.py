import pathlib,zipfile,sys
p=pathlib.Path(sys.argv[1]);root='gelye_cafe_rest'
with zipfile.ZipFile(p) as z:
 s=z.read(root+'/lib/shared/payments_management_panel.dart').decode()
 m=z.read(root+'/supabase/migrations/20261012_1461_credit_source_review_before_post.sql').decode()
 checks=[('source review RPC', 'gs_financial_review_credit_charge_source' in s and 'gs_financial_review_credit_charge_source' in m),('server invoice shown','Invoice: $reviewInvoice' in s),('server IQD shown','Amount: $reviewAmount IQD' in s),('review before confirm',s.index("'gs_financial_review_credit_charge_source'")<s.index("'Confirm real credit-account debit'")),('session continuity','Employee session changed during credit source review' in s),('release gate','GS_ENABLE_VERIFIED_CREDIT_POSTING' in s),('permissions',all(x in m for x in ["gs_can_access('motel_orders'","gs_can_access('invoices_payments'","gs_can_access('credit_management'"])),('source lines','v_count<>f.source_count' in m),('verified barcode',"l.link_status<>'verified'" in m),('no cash collision','gs_motel_food_cash_settlements' in m),('no credit collision','gs_financial_credit_invoice_charge_links' in m),('unpaid only',"f.payment_status<>'unpaid'" in m),('no false certification',"'dashboard_certified',false" in m),('posting still server-side',"'gs_financial_post_verified_credit_charge'" in s)]
 for label,ok in checks:
  assert ok,label
 print(f'{len(checks)}/{len(checks)} source assertions passed')
