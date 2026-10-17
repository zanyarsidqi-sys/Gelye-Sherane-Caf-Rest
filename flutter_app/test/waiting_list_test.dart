import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_waiting_list.dart';
import 'package:gelye_sherane_cafe/staff_dashboard_page.dart';

Map<String,dynamic> party(String id,String status,{int version=1}) => {
  'id':id,'title':'Party $id','quantity':4,'status':status,'version':version,
  'created_at':'2026-10-17T10:00:00Z','updated_at':'2026-10-17T10:00:00Z',
  'details':'Garden preferred','table_name':'Table 1',
};
Map<String,dynamic> data({String status='open',bool seat=true}) => {
  'tasks':[party('p1',status)],'can_seat':seat,
  'tables':[{'id':'t1','name':'Table 1','area':'Garden','seats':6,
    'status':'available','active':false,'blocked':false}],
};
Widget app(Future<dynamic> Function(String,Map<String,dynamic>) rpc) =>
  MaterialApp(home:Scaffold(body:SingleChildScrollView(child:CafeWaitingList(rpc:rpc))));

void main() {
  test('waiting transitions expose only appropriate actions',(){
    expect(waitingActions('open',true),['offered','cancelled']);
    expect(waitingActions('offered',true),['accepted','open','cancelled']);
    expect(waitingActions('arrived',false),['cancelled']);
    expect(waitingActions('seated',true),isEmpty);
    expect(waitingActions('cancelled',true),isEmpty);
  });
  testWidgets('create validates party size and retains idempotency key after ambiguous failure',(tester) async {
    final sent=<Map<String,dynamic>>[];
    await tester.pumpWidget(app((name,params) async {
      if(name=='get_cafe_table_task_workspace') return data();
      sent.add(Map<String,dynamic>.from(params));
      if(sent.length==1) throw StateError('Timeout');
      return {'id':'new'};
    }));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add party')); await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField,'Party name'),'Family');
    await tester.enterText(find.widgetWithText(TextFormField,'Guests'),'0');
    await tester.tap(find.text('Save party')); await tester.pumpAndSettle();
    expect(sent,isEmpty);
    expect(find.text('Enter 1–100 guests'),findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField,'Guests'),'6');
    await tester.tap(find.text('Save party')); await tester.pumpAndSettle();
    expect(sent,hasLength(1));
    expect(sent.single['p_data'],{'title':'Family','quantity':6,'details':''});
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton,'Add party')).onPressed,isNull);
    await tester.tap(find.text('Retry same request')); await tester.pumpAndSettle();
    expect(sent,hasLength(2));
    expect(sent[0],sent[1]);
    expect(find.text('Retry same request'),findsNothing);
  });
  testWidgets('seating confirms current version once and terminal parties stay in history',(tester) async {
    var seated=false; final sent=<Map<String,dynamic>>[];
    await tester.pumpWidget(app((name,params) async {
      if(name=='get_cafe_table_task_workspace') return data(status:seated?'seated':'arrived');
      sent.add(params); seated=true; return {'status':'seated'};
    }));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seat guests')); await tester.pumpAndSettle();
    expect(sent,isEmpty);
    await tester.tap(find.text('Confirm')); await tester.pumpAndSettle();
    expect(sent.single['p_action'],'seated');
    expect(sent.single['p_version'],1);
    expect(sent.single['p_id'],'p1');
    expect(find.text('Party p1 · 4 guests'),findsNothing);
    await tester.tap(find.text('History')); await tester.pumpAndSettle();
    expect(find.text('Party p1 · 4 guests'),findsOneWidget);
    expect(find.text('Seat guests'),findsNothing);
  });
  testWidgets('server capability prevents seating and errors clear old data',(tester) async {
    var fail=false;
    await tester.pumpWidget(app((name,params) async {
      if(fail) throw StateError('Unavailable');
      return data(status:'arrived',seat:false);
    }));
    await tester.pumpAndSettle();
    expect(find.text('Seat guests'),findsNothing);
    fail=true;
    await tester.tap(find.text('Refresh')); await tester.pumpAndSettle();
    expect(find.text('Party p1 · 4 guests'),findsNothing);
    expect(find.textContaining('Could not load the waiting list'),findsOneWidget);
  });
  testWidgets('offer selects table and requires confirmation',(tester) async {
    final sent=<Map<String,dynamic>>[];
    await tester.pumpWidget(app((name,params) async {
      if(name=='get_cafe_table_task_workspace') return data();
      sent.add(params); return {};
    }));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Offer table')); await tester.pumpAndSettle();
    await tester.tap(find.text('Table 1 · Garden · 6 seats')); await tester.pumpAndSettle();
    expect(sent,isEmpty);
    await tester.tap(find.text('Confirm')); await tester.pumpAndSettle();
    expect(sent.single['p_action'],'offered');
    expect(sent.single['p_data'],{'table_id':'t1'});
  });
  testWidgets('waiting list fits mobile RTL',(tester) async {
    tester.view.physicalSize=const Size(390,1100); tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(
      child:Directionality(textDirection:TextDirection.rtl,child:CafeWaitingList(rpc:(n,p)async=>data()))))));
    await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
  });
  testWidgets('dashboard routes require underlying table permissions',(tester) async {
    tester.view.physicalSize=const Size(1440,1800);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    for(final admin in [true,false]) {
      for(final title in ['Waiting List','Table Map']) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(MaterialApp(home:StaffDashboardPage(email:'review@example.com',
          role:admin?'admin':'staff',grantedPermissions:const {'dashboard:waiting_list','dashboard:table_map'})));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('dashboard-search')),title);await tester.pumpAndSettle();
        final entry=find.byKey(ValueKey('dashboard-card-${title.toLowerCase().replaceAll(' ','_')}'));
        await tester.ensureVisible(entry);await tester.tap(entry);await tester.pumpAndSettle();
        expect(title=='Waiting List'?find.byType(CafeWaitingList):find.byKey(const ValueKey('dashboard-table-map')),
          admin?findsOneWidget:findsNothing);
        expect(tester.takeException(),isNull);
      }
    }
  });
}
