import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_minibar_board.dart';
import 'package:gelye_sherane_cafe/staff_dashboard_page.dart';

Map<String,dynamic> station({String department='nargile',bool locked=true})=>{
 'id':'s1','name':'Station A','department':department,'department_version':2,'classification_locked':locked,'active':true};
Map<String,dynamic> row({String status='preparing',String department='nargile'})=>{
 'id':'ticket1','station_id':'s1','station_name':'Station A','department':department,'order_id':'order1',
 'item_name':'Mint nargile','quantity':1,'order_status':status,'ordered_at':'2026-10-17T10:00:00Z',
 'printed_at':'2026-10-17T10:01:00Z','destination':'Table 4','source':'table','notes':'Guest note'};
Map<String,dynamic> data({List<Map<String,dynamic>>? rows,bool manage=false,List<Map<String,dynamic>>? stations,int? total})=>{
 'rows':rows??[row()],'stations':stations??[station()],'total':total??(rows??[row()]).length,
 'can_classify':manage,'server_time':'2026-10-17T11:00:00Z','unclassified_stations':1};
Widget host(Widget child)=>MaterialApp(home:Scaffold(body:SingleChildScrollView(child:child)));
void wide(WidgetTester t){t.view.physicalSize=const Size(1440,1800);t.view.devicePixelRatio=1;
 addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);}
void main(){
 test('response rejects kitchen leakage and malformed status',(){
  expect(()=>minibarBoardData(data(rows:[row(department:'kitchen')]),'minibar_live_board'),throwsFormatException);
  expect(()=>minibarBoardData(data(rows:[row(department:'drinks')]),'nargile_orders'),throwsFormatException);
  expect(()=>minibarBoardData(data(rows:[row(status:'invented')]),'nargile_orders'),throwsFormatException);
 });
 testWidgets('board discloses whole-order status printing and truncated coverage',(t)async{
  wide(t);await t.pumpWidget(host(CafeMinibarBoard(title:'Nargile Orders',autoRefresh:false,rpc:(name,params)async{
   expect(name,'get_cafe_minibar_board');expect(params['p_card'],'nargile_orders');return data(total:501);
  })));await t.pumpAndSettle();
  expect(find.text('1 × Mint nargile'),findsOneWidget);
  expect(find.text('Order status: preparing'),findsOneWidget);
  expect(find.textContaining('Paper confirmed:'),findsOneWidget);
  expect(find.textContaining('501 match'),findsOneWidget);
  expect(find.text('Station classification'),findsNothing);
  expect(find.text('Mark ready'),findsNothing);
 });
 testWidgets('search is server scoped and history clears active status selection',(t)async{
  final calls=<Map<String,dynamic>>[];
  await t.pumpWidget(host(CafeMinibarBoard(title:'Minibar Live Board',autoRefresh:false,rpc:(name,p)async{
   calls.add(p);return data(rows:p['p_history']==true?[row(status:'cancelled')]:[row()]);
  })));await t.pumpAndSettle();
  await t.enterText(find.byType(TextField),'mint');await t.testTextInput.receiveAction(TextInputAction.done);await t.pumpAndSettle();
  expect(calls.last['p_query'],'mint');
  await t.tap(find.text('Recent history'));await t.pumpAndSettle();
  expect(calls.last,{'p_card':'minibar_live_board','p_history':true,'p_query':'mint'});
  expect(find.text('CANCELLED — DO NOT PREPARE'),findsOneWidget);
  expect(t.widget<TextField>(find.byType(TextField)).controller!.text,'mint');
 });
 testWidgets('failed refresh removes old items and classification controls',(t)async{
  var fail=false;
  await t.pumpWidget(host(CafeMinibarBoard(title:'Nargile Orders',autoRefresh:false,rpc:(name,p)async{
   if(fail) throw StateError('offline');return data(manage:true);
  })));await t.pumpAndSettle();fail=true;
  await t.tap(find.text('Refresh'));await t.pumpAndSettle();
  expect(find.text('1 × Mint nargile'),findsNothing);expect(find.text('Station classification'),findsNothing);
  expect(find.textContaining('Could not load the board'),findsOneWidget);
 });
 testWidgets('classification confirms and retries exact request identity',(t)async{
  wide(t);final commands=<Map<String,dynamic>>[];
  await t.pumpWidget(host(CafeMinibarBoard(title:'Minibar Live Board',autoRefresh:false,rpc:(name,p)async{
   if(name=='get_cafe_minibar_board') return data(rows:[],manage:true,stations:[station(department:'unclassified',locked:false)]);
   commands.add(Map.of(p));if(commands.length==1) throw StateError('lost reply');return {};
  })));await t.pumpAndSettle();
  await t.tap(find.text('Station classification'));await t.pumpAndSettle();
  await t.tap(find.text('Classify'));await t.pumpAndSettle();
  await t.tap(find.byType(DropdownButtonFormField<String>).last);await t.pumpAndSettle();
  await t.tap(find.text('nargile').last);await t.pumpAndSettle();
  await t.tap(find.text('Confirm classification'));await t.pumpAndSettle();
  expect(commands.single['p_station_id'],'s1');expect(commands.single['p_version'],2);
  expect(commands.single['p_department'],'nargile');
  await t.tap(find.text('Retry same classification'));await t.pumpAndSettle();
  expect(commands.length,2);expect(commands.first,commands.last);
 });
 testWidgets('used classification cannot be changed in UI',(t)async{
  wide(t);
  await t.pumpWidget(host(CafeMinibarBoard(title:'Nargile Orders',autoRefresh:false,rpc:(name,p)async=>data(manage:true))));
  await t.pumpAndSettle();await t.tap(find.text('Station classification'));await t.pumpAndSettle();
  expect(t.widget<TextButton>(find.widgetWithText(TextButton,'Classify')).onPressed,isNull);
 });
 testWidgets('late old scope result cannot replace new board',(t)async{
  final pending=Completer<dynamic>();
  Future<dynamic> rpc(String name,Map<String,dynamic> p)async {
   if(p['p_card']=='minibar_live_board') return pending.future;
   return data();
  }
  await t.pumpWidget(host(CafeMinibarBoard(title:'Minibar Live Board',autoRefresh:false,rpc:rpc)));await t.pump();
  await t.pumpWidget(host(CafeMinibarBoard(title:'Nargile Orders',autoRefresh:false,rpc:rpc)));await t.pumpAndSettle();
  pending.complete(data(rows:[{...row(department:'drinks'),'item_name':'Tea'}]));await t.pumpAndSettle();
  expect(find.text('1 × Mint nargile'),findsOneWidget);expect(find.text('1 × Tea'),findsNothing);
 });
 testWidgets('board fits mobile RTL',(t)async{
  t.view.physicalSize=const Size(390,1000);t.view.devicePixelRatio=1;
  addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(host(Directionality(textDirection:TextDirection.rtl,
   child:CafeMinibarBoard(title:'Nargile Orders',autoRefresh:false,rpc:(name,p)async=>data()))));
  await t.pumpAndSettle();expect(t.takeException(),isNull);
 });
 testWidgets('both Dashboard routes require their card permission',(t)async{
  wide(t);
  for(final entry in minibarBoardCards.entries){
   await t.pumpWidget(const SizedBox());
   await t.pumpWidget(MaterialApp(home:StaffDashboardPage(email:'staff@example.com',role:'staff',
    grantedPermissions:{'dashboard:${entry.value}'})));await t.pumpAndSettle();
   await t.enterText(find.byKey(const ValueKey('dashboard-search')),entry.key);await t.pumpAndSettle();
   final card=find.byKey(ValueKey('dashboard-card-${entry.value}'));await t.ensureVisible(card);await t.tap(card);await t.pumpAndSettle();
   expect(t.widget<CafeMinibarBoard>(find.byType(CafeMinibarBoard)).title,entry.key);
   expect(t.takeException(),isNull);
  }
  await t.pumpWidget(const SizedBox());await t.pumpAndSettle();
 });
}
