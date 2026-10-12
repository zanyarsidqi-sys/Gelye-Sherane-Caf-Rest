from pathlib import Path
import json,re,zipfile,subprocess
root=Path(__file__).resolve().parents[1]
sections={
'01 — Dashboard':['lib/sections/dashboard.dart','lib/screens/dashboard'],
'02 — Tables':['lib/sections/tables.dart','lib/shared'],
'03 — Table Orders':['lib/sections/table_orders.dart','lib/shared/order_preview_workspace.dart'],
'04 — Motel Orders':['lib/sections/motel_orders.dart','lib/shared/motel_room_registry_screen.dart','lib/shared/motel_food_requests_screen.dart','lib/shared/motel_food_billing_ledger_screen.dart'],
'05 — Kitchen':['lib/sections/kitchen.dart','lib/shared/live_kitchen_panel.dart','lib/shared/kitchen_motel_food_queue_panel.dart','lib/shared/kitchen_scheduled_motel_meals_panel.dart'],
'06 — Menu':['lib/sections/menu.dart','lib/shared/live_menu_product_create.dart','lib/shared/live_menu_product_edit.dart','lib/shared/recipe_management_panel.dart'],
'07 — Products & Inventory':['lib/sections/products_inventory.dart','lib/shared'],
}
checks={
'01 — Dashboard':{'screen':'class Dashboard','backend_rpc':'.rpc(','error_handling':'catch (','loading_state':'_loading','financial_summary':'cash','permissions':'sectionId'},
'02 — Tables':{'screen':'class Tables','backend_rpc':'.rpc(','error_handling':'catch (','reservation':'reserv','table_assignment':'table','permissions':'sectionId'},
'03 — Table Orders':{'screen':'class TableOrders','backend_rpc':'.rpc(','error_handling':'catch (','replacement_receipts':'receipt','kitchen_link':'kitchen','permissions':'sectionId'},
'04 — Motel Orders':{'screen':'class MotelOrders','backend_rpc':'.rpc(','error_handling':'catch (','room_registry':'MotelRoomRegistry','food_billing':'MotelFoodBillingLedger','permissions':'sectionId'},
'05 — Kitchen':{'screen':'class Kitchen','backend_rpc':'.rpc(','error_handling':'catch (','scheduled_meals':'KitchenScheduledMotelMeals','food_requests':'KitchenMotelFoodQueue','permissions':'sectionId'},
'06 — Menu':{'screen':'class Menu','backend_rpc':'.rpc(','error_handling':'catch (','tourism_pricing':'tourism','live_editor':'LiveMenuProductEdit','permissions':'sectionId'},
'07 — Products & Inventory':{'screen':'class ProductsInventory','backend_rpc':'.rpc(','error_handling':'catch (','stock_adjustment':'gs_inventory','stock_history':'history','permissions':'sectionId'},
}
# Structural evidence is explicitly not functional correctness.
report={'checkpoint':686,'basis':'Source presence checks across each section and its explicitly listed shared components. These do not establish correctness or completeness.','runtime_gates':{'flutter_analyze':'not_run_flutter_sdk_unavailable','flutter_test':'not_run_flutter_sdk_unavailable','supabase_migrations':'not_applied','supabase_integration':'not_run','ios_windows_device_tests':'not_run'},'sections':{}}
for name,paths in sections.items():
    texts=[]; found=[]
    for p in paths:
        target=root/p
        if target.is_file():
            texts.append(target.read_text(errors='replace'));found.append(p)
        elif target.is_dir():
            files=list(target.rglob('*.dart'))
            texts.extend(f.read_text(errors='replace') for f in files)
            found.append(f'{p}/ ({len(files)} Dart files)')
    source='\n'.join(texts)
    result={k: (v.lower() in source.lower()) for k,v in checks[name].items()}
    report['sections'][name]={'inspected_paths':found,'source_evidence':result,'source_evidence_passed':sum(result.values()),'source_evidence_total':len(result),'source_evidence_pct':round(100*sum(result.values())/len(result)),'verified_completion_pct':None,'previous_estimated_completion_pct':76 if name.startswith('03') else None,'percentage_point_change':None,'blocking_gates':['Flutter analyzer','Supabase migration execution','end-to-end workflow tests','cross-section financial and kitchen reconciliation','iPhone and Windows acceptance tests']}
(root/'SECTION_01_TO_07_READINESS_AUDIT_686.json').write_text(json.dumps(report,indent=2)+'\n')
