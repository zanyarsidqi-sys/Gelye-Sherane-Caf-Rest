import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_table_maintenance.dart';

Map<String,dynamic> snapshot({String status='open',bool admin=false})=>{
  'tasks':[{'id':'m','title':'Loose leg','quantity':1,'version':3,'status':status,
    'created_at':'2026-10-17T10:00:00Z','updated_at':'2026-10-17T10:00:00Z',
    'table_name':'Table 1','details':'Check before seating'}],
  'tables':[{'id':'t','name':'Table 1','area':'Garden'}],
  'can_approve':admin,
};
Widget host(Future<dynamic> Function(String,Map<String,dynamic>) rpc)=>MaterialApp(
  home:Scaffold(body:SingleChildScrollView(child:CafeTableMaintenance(rpc:rpc))));
void main(){
  test('maintenance review and cancellation require server approval capability',(){
    expect(maintenanceActions('review',false),isEmpty);
    expect(maintenanceActions('review',true),['resolved','cancelled']);
    expect(maintenanceActions('open',false),['in_progress']);
    expect(maintenanceActions('resolved',true),isEmpty);
  });
  testWidgets('repair resolution confirms exact record version and keeps history',(tester)async{
    var resolved=false;final commands=<Map<String,dynamic>>[];
    await tester.pumpWidget(host((name,params)async{
      if(name=='get_cafe_table_task_workspace'){
        expect(params,{'p_kind':'maintenance'});
        return snapshot(status:resolved?'resolved':'review',admin:true);
      }
      commands.add(params);resolved=true;return {};
    }));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve repair'));await tester.pumpAndSettle();
    expect(commands,isEmpty);
    await tester.tap(find.text('Confirm'));await tester.pumpAndSettle();
    expect(commands.single['p_kind'],'maintenance');
    expect(commands.single['p_action'],'resolved');
    expect(commands.single['p_version'],3);
    expect(commands.single['p_id'],'m');
    expect(find.text('Loose leg'),findsNothing);
    await tester.tap(find.text('History'));await tester.pumpAndSettle();
    expect(find.text('Loose leg'),findsOneWidget);
    expect(find.text('Approve repair'),findsNothing);
  });
  testWidgets('non-admin cannot resolve a repair',(tester)async{
    await tester.pumpWidget(host((name,params)async=>snapshot(status:'review')));
    await tester.pumpAndSettle();
    expect(find.text('Approve repair'),findsNothing);
    expect(find.text('Administrator approval is required to resolve this repair.'),findsOneWidget);
  });
  testWidgets('new maintenance requires a table and problem',(tester)async{
    final sent=<Map<String,dynamic>>[];
    await tester.pumpWidget(host((name,params)async{
      if(name=='get_cafe_table_task_workspace')return snapshot();
      sent.add(params);return {};
    }));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report problem'));await tester.pumpAndSettle();
    await tester.tap(find.text('Save request'));await tester.pumpAndSettle();
    expect(sent,isEmpty);
    expect(find.text('Select a table'),findsOneWidget);
    expect(find.text('Describe the problem'),findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));await tester.pumpAndSettle();
    await tester.tap(find.text('Table 1 · Garden').last);await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField,'Problem'),'Broken chair');
    await tester.tap(find.text('Save request'));await tester.pumpAndSettle();
    expect(sent.single['p_data'],{'title':'Broken chair','details':'','table_id':'t','quantity':1});
    expect(sent.single['p_action'],'create');
    expect(tester.takeException(),isNull);
  });
}
