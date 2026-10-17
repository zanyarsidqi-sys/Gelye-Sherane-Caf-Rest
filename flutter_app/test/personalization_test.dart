import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/favorites_page.dart';
import 'package:gelye_sherane_cafe/staff_dashboard_page.dart';

class Store implements FavoritesStorage {
 final data=<String,List<String>>{};
 Completer<List<String>>? delayed;
 bool fail=false;
 @override Future<List<String>> read(String account) async {
  if(account=='old' && delayed!=null) return delayed!.future;
  if(fail) throw StateError('read failed');
  return List.of(data[account]??[]);
 }
 @override Future<void> write(String account,List<String> ids) async {data[account]=List.of(ids);}
}
const cards=[
 FavoriteCardEntry(id:'a',section:'Dashboard',title:'Alpha'),
 FavoriteCardEntry(id:'b',section:'Tables',title:'Beta'),
 FavoriteCardEntry(id:'c',section:'Kitchen',title:'Gamma'),
];
Widget host(Store store,{String account='staff',List<FavoriteCardEntry> allowed=cards,bool manage=false})=>
 MaterialApp(home:Scaffold(body:SingleChildScrollView(child:FavoritesPage(
  account:account,cards:allowed,storage:store,onOpen:(_){},manageInitially:manage,
 ))));
void wide(WidgetTester t) {t.view.physicalSize=const Size(1440,1800);t.view.devicePixelRatio=1;
 addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);}
void main(){
 testWidgets('saved ordering is shown and survives arranging and reopening',(t)async{
  wide(t);final store=Store()..data['staff']=['b','hidden','a','c'];
  await t.pumpWidget(host(store));await t.pumpAndSettle();
  expect(t.getTopLeft(find.text('Beta')).dy,lessThan(t.getTopLeft(find.text('Alpha')).dy));
  await t.tap(find.byKey(const ValueKey('favorites-arrange')));await t.pumpAndSettle();
  await t.tap(find.byKey(const ValueKey('move-up-a')));await t.pumpAndSettle();
  expect(store.data['staff'],['a','hidden','b','c']);
  expect(t.widget<IconButton>(find.byKey(const ValueKey('move-up-a'))).onPressed,isNull);
  await t.pumpWidget(const SizedBox());await t.pumpWidget(host(store));await t.pumpAndSettle();
  expect(t.getTopLeft(find.text('Alpha')).dy,lessThan(t.getTopLeft(find.text('Beta')).dy));
 });
 testWidgets('reset needs confirmation and cancel preserves stored hidden cards',(t)async{
  wide(t);final store=Store()..data['staff']=['a','hidden'];
  await t.pumpWidget(host(store));await t.pumpAndSettle();
  await t.tap(find.byKey(const ValueKey('favorites-reset')));await t.pumpAndSettle();
  await t.tap(find.text('Cancel'));await t.pumpAndSettle();expect(store.data['staff'],['a','hidden']);
  await t.tap(find.byKey(const ValueKey('favorites-reset')));await t.pumpAndSettle();
  await t.tap(find.widgetWithText(FilledButton,'Reset favorites'));await t.pumpAndSettle();
  expect(store.data['staff'],isEmpty);expect(find.textContaining('No favorites yet'),findsOneWidget);
 });
 testWidgets('late old account read cannot replace new account favorites',(t)async{
  final store=Store()..delayed=Completer<List<String>>()..data['new']=['b'];
  await t.pumpWidget(host(store,account:'old'));await t.pump();
  await t.pumpWidget(host(store,account:'new'));await t.pumpAndSettle();
  expect(find.text('Beta'),findsOneWidget);
  store.delayed!.complete(['a']);await t.pumpAndSettle();
  expect(find.text('Alpha'),findsNothing);expect(find.text('Beta'),findsOneWidget);
 });
 testWidgets('permission removal hides cards without deleting stored preference',(t)async{
  final store=Store()..data['staff']=['a','b'];
  await t.pumpWidget(host(store));await t.pumpAndSettle();
  await t.pumpWidget(host(store,allowed:[cards[0]]));await t.pumpAndSettle();
  expect(find.text('Beta'),findsNothing);expect(store.data['staff'],['a','b']);
 });
 testWidgets('refresh failure clears saved cards and disables changes',(t)async{
  final store=Store()..data['staff']=['a'];
  await t.pumpWidget(host(store));await t.pumpAndSettle();
  store.fail=true;await t.tap(find.text('Refresh favorites'));await t.pumpAndSettle();
  expect(find.text('Alpha'),findsNothing);
  expect(t.widget<TextButton>(find.byKey(const ValueKey('favorites-reset'))).onPressed,isNull);
  expect(t.widget<FilledButton>(find.byKey(const ValueKey('favorites-picker'))).onPressed,isNull);
 });
 testWidgets('adding preserves current order and another saved entry',(t)async{
  wide(t);final store=Store()..data['staff']=['b','a'];
  await t.pumpWidget(host(store,manage:true));await t.pumpAndSettle();
  store.data['staff']=['b','a','hidden'];
  await t.tap(find.byKey(const ValueKey('favorite-c')));await t.pumpAndSettle();
  expect(store.data['staff'],['b','a','hidden','c']);
 });
 testWidgets('arrangement fits mobile RTL',(t)async{
  t.view.physicalSize=const Size(390,1000);t.view.devicePixelRatio=1;
  addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
  final store=Store()..data['staff']=['a','b'];
  await t.pumpWidget(MaterialApp(home:Directionality(textDirection:TextDirection.rtl,
   child:Scaffold(body:SingleChildScrollView(child:FavoritesPage(account:'staff',cards:cards,storage:store,onOpen:(_){}))))));
  await t.pumpAndSettle();await t.tap(find.byKey(const ValueKey('favorites-arrange')));await t.pumpAndSettle();
  expect(find.byKey(const ValueKey('move-down-a')),findsOneWidget);expect(t.takeException(),isNull);
 });
 testWidgets('both Dashboard personalization routes open permitted management',(t)async{
  wide(t);final store=Store();
  for(final entry in {'Dashboard Personalization':'dashboard_personalization','Personalization':'personalization'}.entries){
   await t.pumpWidget(const SizedBox());
   await t.pumpWidget(MaterialApp(home:StaffDashboardPage(email:'staff@example.com',role:'staff',favoritesStorage:store,
    grantedPermissions:{'dashboard:${entry.value}','dashboard:today_revenue'})));
   await t.pumpAndSettle();
   await t.enterText(find.byKey(const ValueKey('dashboard-search')),entry.key);await t.pumpAndSettle();
   final card=find.byKey(ValueKey('dashboard-card-${entry.value}'));await t.ensureVisible(card);await t.tap(card);await t.pumpAndSettle();
   expect(find.byType(FavoritesPage),findsOneWidget);
   expect(t.widget<FavoritesPage>(find.byType(FavoritesPage)).title,entry.key);
   expect(find.byKey(const ValueKey('favorite-dashboard:Today Revenue')),findsOneWidget);
   expect(find.text('Cash Transfers'),findsNothing);
   expect(t.takeException(),isNull);
  }
 });
}
