import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_station_workspace.dart';

void main() {
  testWidgets('station queue switches destinations and confirmation is explicit',(tester) async {
    final queries=<String>[]; final confirmed=<String>[];
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:CafeStationWorkspace(rpc:(name,p) async {
      if(name=='get_cafe_print_stations')return {'can_manage':true,'stations':[{'id':'k','name':'Kitchen','active':true},{'id':'b','name':'Minibar','active':true}]};
      if(name=='get_cafe_station_queue') {queries.add(p['p_station_id']);return {'unrouted_products':0,'tickets':[{'order_id':'order','station':p['p_station_id']=='k'?'Kitchen':'Minibar','event':'new','status':'received','created_at':'2026-10-17','destination':'Table 1','notes':'No sugar','items':[{'ticket_id':'ticket-${p['p_station_id']}','name':p['p_station_id']=='k'?'Soup':'Tea','quantity':1}]}]};}
      if(name=='confirm_cafe_station_tickets') {confirmed.addAll(List<String>.from(p['p_ids']));return null;}
      throw StateError(name);
    })))));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 x Soup'),findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip,'Minibar'));await tester.pumpAndSettle();
    expect(find.textContaining('1 x Tea'),findsOneWidget);
    expect(queries.last,'b');expect(confirmed,isEmpty);
    await tester.ensureVisible(find.text('Confirm printed'));await tester.tap(find.text('Confirm printed'));await tester.pumpAndSettle();
    await tester.tap(find.text('Keep in queue'));await tester.pumpAndSettle();expect(confirmed,isEmpty);
    await tester.tap(find.text('Confirm printed'));await tester.pumpAndSettle();await tester.tap(find.text('Yes, received'));await tester.pumpAndSettle();
    expect(confirmed,['ticket-b']);expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
