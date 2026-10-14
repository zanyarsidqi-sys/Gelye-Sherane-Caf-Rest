#!/usr/bin/env python3
"""Reproducible source-contract evidence for priority sections; NOT production readiness."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parent

def has(path, *tokens):
    file = ROOT / path
    return file.exists() and all(token in file.read_text(encoding='utf-8') for token in tokens)

CHECKS = [
(713,'01 Dashboard','Operational server summary', 'lib/sections/dashboard.dart',['gs_dashboard_operational_summary']),
(714,'01 Dashboard','Cash collection server source','lib/sections/dashboard.dart',['gs_dashboard_cash_collections_today']),
(715,'01 Dashboard','Weekly trend server source','lib/sections/dashboard.dart',['gs_dashboard_order_week']),
(716,'02 Tables','Server-side table state','lib/sections/tables.dart',["from('gs_cafe_tables')"]),
(717,'02 Tables','Reservation cancellation','lib/sections/tables.dart',['gs_cancel_reservation']),
(718,'02 Tables','Table transfer financial preflight','lib/sections/tables.dart',['gs_table_transfer_financial_preflight']),
(719,'03 Table Orders','Server-side board pagination','lib/sections/table_orders.dart',['gs_staff_table_order_board_page']),
(720,'03 Table Orders','Idempotent replacement confirmation','lib/sections/table_orders.dart',['p_request_id','p_expected_tourism_mode']),
(721,'03 Table Orders','Kitchen replacement receipt status','lib/sections/table_orders.dart',['gs_table_replacement_kitchen_receipt_status']),
(722,'04 Motel Orders','Room registry integrated','lib/sections/motel_orders.dart',['MotelRoomRegistryScreen']),
(723,'04 Motel Orders','Food ledger integrated','lib/sections/motel_orders.dart',['MotelFoodBillingLedgerScreen']),
(724,'04 Motel Orders','Scheduled meals integrated','lib/sections/motel_orders.dart',['MotelScheduledMealsScreen']),
(725,'05 Kitchen','Live kitchen status RPC','lib/shared/live_kitchen_panel.dart',['gs_update_kitchen_status']),
(726,'05 Kitchen','Scheduled motel meals queue','lib/sections/kitchen.dart',['KitchenScheduledMotelMealsPanel']),
(727,'05 Kitchen','Motel food requests queue','lib/sections/kitchen.dart',['KitchenMotelFoodQueuePanel']),
(728,'06 Menu','Owner-reviewed menu revisions','supabase/migrations/20261014_1506_menu_management_approval.sql',['gs_menu_submit_product_revision','gs_menu_review_product_revision','gs_menu_user_is_owner()']),
(729,'06 Menu','Audited menu availability changes','supabase/migrations/20261014_1506_menu_management_approval.sql',['gs_menu_set_product_availability','availability_changed']),
(730,'06 Menu','Approved public catalog with product photos','lib/shared/public_menu_screen.dart',['gs_menu_public_catalog','service.publicImageUrl']),
(731,'07 Products & Inventory','Server inventory overview','lib/sections/products_inventory.dart',['gs_inventory_overview']),
(732,'07 Products & Inventory','Server inventory adjustment','lib/sections/products_inventory.dart',['gs_inventory_adjust']),
]

def run():
    rows=[]
    for number,section,label,path,tokens in CHECKS:
        rows.append({'upgrade':number,'section':section,'criterion':label,'source':path,'passed':bool(has(path,*tokens)),'verification':'source contract only'})
    summary={}
    for section in sorted(set(row['section'] for row in rows)):
        subset=[r for r in rows if r['section']==section]
        summary[section]={'passed':sum(r['passed'] for r in subset),'total':len(subset),'completion_percent':None,'runtime_verified':False}
    return {'scope':'20 source acceptance checkpoints, not 20 runtime feature upgrades', 'criteria':rows,'sections':summary,'verified_completion_percent':None,'flutter_compiled':False,'live_supabase_tested':False}
if __name__=='__main__':
    result=run()
    print(json.dumps(result,indent=2))
