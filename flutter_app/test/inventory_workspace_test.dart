
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_inventory_workspace.dart';
import 'package:gelye_sherane_cafe/staff_dashboard_page.dart';

Map<String,dynamic> item({num stock=10,bool moved=true})=>{
 'id':'item-1','name':'Milk','unit':'litre','department':'drinks','on_hand':stock,'reorder_level':20,
 'version':3,'has_movements':moved,'unit_locked':moved,
};
Map<String,dynamic> purchase({String status='approved'})=>{
 'id':'purchase-1','item_id':'item-1','item_name':'Milk','unit':'litre','supplier':'Dairy supplier',
 'quantity':5,'received':2,'status':status,'version':4,'note':'Morning delivery','review_note':'',
 'created_at':'2026-10-17T10:00:00Z',
};
Map<String,dynamic> workspace({List<Map<String,dynamic>>? items,List<Map<String,dynamic>> purchases=const [],
 List<Map<String,dynamic>> moves=const [],bool manage=false,bool request=false,bool approve=false,bool receive=false,bool waste=false,int? count})=>{
 'items':items??[item()],'purchases':purchases,'movements':moves,
 'counts':{'items':count??(items??[item()]).length,'purchases':purchases.length,'movements':moves.length},
 'server_time':'2026-10-17T11:00:00Z','can_manage':manage,'can_request':request,'can_approve':approve,
 'can_receive':receive,'can_waste':waste,
};
Widget host(Widget child)=>MaterialApp(home:Scaffold(body:SingleChildScrollView(child:child)));
void wide(WidgetTester tester){
 tester.view.physicalSize=const Size(1440,1800);tester.view.devicePixelRatio=1;
 addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
}
void main(){
 test('quantity input preserves decimals and rejects unsafe values',(){
  for(final value in ['-1','0','1.0001','NaN','1e3','1000000000']){
   expect(inventoryQuantityError(value),isNotNull);
  }
  expect(inventoryQuantityError('0',allowZero:true),isNull);
  expect(inventoryQuantityError('0.125'),isNull);
  expect(inventoryQuantityError('4',maximum:3),isNotNull);
  expect(inventoryAmount(10.250),'10.25');expect(inventoryAmount(0),'0');
 });
 test('response validation rejects malformed stock and received excess',(){
  expect(()=>cafeInventoryData(workspace(items:[{...item(),'on_hand':-1}])),throwsFormatException);
  expect(()=>cafeInventoryData(workspace(purchases:[{...purchase(),'received':6}])),throwsFormatException);
  expect(()=>cafeInventoryData(workspace(items:[{...item(),'department':'unknown'}])),throwsFormatException);
 });
 testWidgets('read-only stock cards hide writes and report result coverage',(tester)async{
  await tester.pumpWidget(host(CafeInventoryWorkspace(title:'Low Stock',rpc:(name,params)async{
   expect(name,'get_cafe_inventory_workspace');expect(params['p_card'],'low_stock');
   return workspace(count:501);
  })));await tester.pumpAndSettle();
  expect(find.text('Milk'),findsOneWidget);expect(find.text('Record waste'),findsNothing);
  expect(find.text('Edit item'),findsNothing);expect(find.textContaining('Limit 500'),findsOneWidget);
 });
 testWidgets('refresh error removes stock and write controls',(tester)async{
  var fail=false;
  await tester.pumpWidget(host(CafeInventoryWorkspace(title:'Inventory Waste',rpc:(name,params)async{
   if(fail){throw StateError('offline');}return workspace(waste:true);
  })));await tester.pumpAndSettle();
  expect(find.text('Record waste'),findsOneWidget);
  fail=true;await tester.tap(find.text('Refresh'));await tester.pumpAndSettle();
  expect(find.text('Milk'),findsNothing);expect(find.text('Record waste'),findsNothing);
  expect(find.textContaining('Could not load inventory'),findsOneWidget);
 });
 testWidgets('search is sent to server and retained on refresh',(tester)async{
  final queries=<String>[];
  await tester.pumpWidget(host(CafeInventoryWorkspace(title:'Inventory Overview',rpc:(name,params)async{
   queries.add(params['p_query'] as String);return workspace();
  })));await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField),'milk');
  await tester.testTextInput.receiveAction(TextInputAction.done);await tester.pumpAndSettle();
  await tester.tap(find.text('Refresh'));await tester.pumpAndSettle();
  expect(queries,['','milk','milk']);
  expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,'milk');
 });
 testWidgets('delivery validates remaining amount and retries identical command',(tester)async{
  wide(tester);final commands=<Map<String,dynamic>>[];
  await tester.pumpWidget(host(CafeInventoryWorkspace(title:'Supplier Deliveries',rpc:(name,params)async{
   if(name=='get_cafe_inventory_workspace'){return workspace(purchases:[purchase()],receive:true);}
   commands.add(Map<String,dynamic>.from(params));
   if(commands.length==1){throw StateError('lost result');}return {};
  })));await tester.pumpAndSettle();
  await tester.tap(find.text('Receive delivery'));await tester.pumpAndSettle();
  final fields=find.byType(TextFormField);
  await tester.enterText(fields.at(0),'4');await tester.enterText(fields.at(1),'Delivery D1');
  await tester.tap(find.text('Confirm'));await tester.pumpAndSettle();
  expect(commands,isEmpty);expect(find.text('Quantity exceeds the available amount'),findsOneWidget);
  await tester.enterText(fields.at(0),'1.250');
  await tester.tap(find.text('Confirm'));await tester.pumpAndSettle();
  expect(commands.single['p_action'],'receive');expect(commands.single['p_id'],'purchase-1');
  expect(commands.single['p_version'],4);expect(commands.single['p_data'],{'quantity':'1.250','note':'Delivery D1'});
  expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton,'Receive delivery')).onPressed,isNull);
  await tester.tap(find.text('Retry same request'));await tester.pumpAndSettle();
  expect(commands,hasLength(2));expect(commands[0],commands[1]);
 });
 testWidgets('waste requires a reason and cannot exceed current stock',(tester)async{
  wide(tester);final commands=<Map<String,dynamic>>[];
  await tester.pumpWidget(host(CafeInventoryWorkspace(title:'Inventory Waste',rpc:(name,params)async{
   if(name=='get_cafe_inventory_workspace'){return workspace(waste:true);}
   commands.add(params);return {};
  })));await tester.pumpAndSettle();
  await tester.tap(find.text('Record waste'));await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first,'11');
  await tester.tap(find.text('Confirm'));await tester.pumpAndSettle();
  expect(commands,isEmpty);expect(find.text('Quantity exceeds the available amount'),findsOneWidget);
  expect(find.text('Enter at least 3 characters'),findsOneWidget);
  await tester.enterText(find.byType(TextFormField).first,'0.25');
  await tester.enterText(find.byType(TextFormField).last,'Spilled milk');
  await tester.tap(find.text('Confirm'));await tester.pumpAndSettle();
  expect(commands.single['p_action'],'waste');expect(commands.single['p_version'],3);
 });
 testWidgets('purchase request requires item supplier and decimal quantity',(tester)async{
  wide(tester);final commands=<Map<String,dynamic>>[];
  await tester.pumpWidget(host(CafeInventoryWorkspace(title:'Purchase Requests',rpc:(name,params)async{
   if(name=='get_cafe_inventory_workspace'){return workspace(request:true);}
   commands.add(params);return {};
  })));await tester.pumpAndSettle();
  await tester.tap(find.text('New purchase request'));await tester.pumpAndSettle();
  await tester.tap(find.text('Confirm'));await tester.pumpAndSettle();
  expect(commands,isEmpty);expect(find.text('Choose a stock item'),findsOneWidget);
  await tester.tap(find.byType(DropdownButtonFormField<String>));await tester.pumpAndSettle();
  await tester.tap(find.text('Milk (litre)').last);await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).at(0),'Dairy supplier');
  await tester.enterText(find.byType(TextFormField).at(1),'5.125');
  await tester.tap(find.text('Confirm'));await tester.pumpAndSettle();
  expect(commands.single['p_action'],'request');expect(commands.single['p_id'],isNull);
  expect(commands.single['p_data']['quantity'],'5.125');
 });
 testWidgets('used stock unit cannot be edited',(tester)async{
  wide(tester);
  await tester.pumpWidget(host(CafeInventoryWorkspace(title:'Inventory Overview',rpc:(name,params)async=>workspace(manage:true))));
  await tester.pumpAndSettle();await tester.tap(find.text('Edit item'));await tester.pumpAndSettle();
  expect(tester.widget<TextFormField>(find.byType(TextFormField).at(1)).enabled,isFalse);
  expect(find.textContaining('Unit is locked'),findsOneWidget);
 });
 testWidgets('purchase approval controls require server capability',(tester)async{
  await tester.pumpWidget(host(CafeInventoryWorkspace(title:'Pending Approvals',rpc:(name,params)async=>workspace(purchases:[purchase(status:'requested')]))));
  await tester.pumpAndSettle();
  expect(find.text('Approve quantity'),findsNothing);expect(find.text('Reject'),findsNothing);
 });
 testWidgets('inventory screens and receiving form fit mobile RTL',(tester)async{
  tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  for(final title in ['Inventory Overview','Supplier Deliveries','Inventory Waste']){
   await tester.pumpWidget(const SizedBox());
   await tester.pumpWidget(host(Directionality(textDirection:TextDirection.rtl,child:
    CafeInventoryWorkspace(title:title,rpc:(name,params)async=>workspace(purchases:[purchase()],receive:true,waste:true,manage:true)))));
   await tester.pumpAndSettle();expect(tester.takeException(),isNull);
   if(title=='Supplier Deliveries'){
    final button=find.text('Receive delivery');await tester.ensureVisible(button);await tester.tap(button);await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);await tester.tap(find.text('Cancel'));await tester.pumpAndSettle();
   }
  }
 });
 testWidgets('all seven Dashboard cards open the intended permission-scoped workspace',(tester)async{
  wide(tester);
  for(final entry in cafeInventoryCards.entries){
   await tester.pumpWidget(const SizedBox());
   await tester.pumpWidget(MaterialApp(home:StaffDashboardPage(email:'test@example.com',role:'staff',
    grantedPermissions:{'dashboard:${entry.value}'})));
   await tester.pumpAndSettle();
   await tester.enterText(find.byKey(const ValueKey('dashboard-search')),entry.key);await tester.pumpAndSettle();
   final card=find.byKey(ValueKey('dashboard-card-${entry.value}'));
   await tester.ensureVisible(card);await tester.tap(card);await tester.pumpAndSettle();
   expect(tester.widget<CafeInventoryWorkspace>(find.byType(CafeInventoryWorkspace)).title,entry.key);
   expect(tester.takeException(),isNull);
  }
 });
}
