
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_staff_tasks.dart';
import 'package:gelye_sherane_cafe/cafe_report_library.dart';
import 'package:gelye_sherane_cafe/staff_dashboard_page.dart';

Map<String,dynamic> task(String id,String kind,String status)=>{
  'id':id,'kind':kind,'title':'Task $id','status':status,'version':3,
  'created_at':'2026-10-17T10:00:00Z','table_name':'Table 4','details':'Check carefully',
  'assigned_to':null,'assignee':null,
};
Map<String,dynamic> source(List<Map<String,dynamic>> rows,{bool admin=false})=>{
  'tasks':rows,'staff':[{'id':'employee-a','name':'Ali'}],'can_approve':admin,
};
Widget host(Widget child)=>MaterialApp(home:Scaffold(body:SingleChildScrollView(child:child)));

void main(){
  test('task parser rejects wrong source and unknown status',(){
    expect(()=>cafeTaskRows(source([task('1','chairs','open')]),'maintenance'),throwsFormatException);
    expect(()=>cafeTaskRows(source([task('1','maintenance','unknown')]),'maintenance'),throwsFormatException);
    for(final state in ['resolved','cancelled','delivered','seated','separated']){
      expect(cafeTaskPending({'status':state}),isFalse);
    }
    expect(cafeTaskPending({'status':'review'}),isTrue);
  });
  testWidgets('pending board loads only assigned sources and excludes history',(tester)async{
    final calls=<String>[];
    await tester.pumpWidget(host(CafeStaffTasks(kinds:const {'maintenance'},pendingOnly:true,
      rpc:(name,params)async{
        calls.add(params['p_kind'] as String);
        return source([task('active','maintenance','review'),task('closed','maintenance','resolved')]);
      })));
    await tester.pumpAndSettle();
    expect(calls,['maintenance']);
    expect(find.text('Task active'),findsOneWidget);
    expect(find.text('Task closed'),findsNothing);
    expect(find.text('Assign employee'),findsNothing);
    await tester.enterText(find.byType(TextField),'missing');await tester.pump();
    expect(find.text('No matching tasks in loaded sources.'),findsOneWidget);
  });
  testWidgets('partial failure is explicit and refresh removes stale records',(tester)async{
    var fail=false;
    await tester.pumpWidget(host(CafeStaffTasks(kinds:const {'maintenance','chairs'},rpc:(name,params)async{
      if(fail||params['p_kind']=='chairs')throw StateError('offline');
      return source([task('repair','maintenance','open')]);
    })));
    await tester.pumpAndSettle();
    expect(find.text('1/2 sources loaded'),findsOneWidget);
    expect(find.textContaining('Incomplete sources'),findsOneWidget);
    expect(find.text('Task repair'),findsOneWidget);
    fail=true;await tester.tap(find.text('Refresh'));await tester.pumpAndSettle();
    expect(find.text('Task repair'),findsNothing);
    expect(find.text('0/2 sources loaded'),findsOneWidget);
    expect(find.text('No matching tasks in loaded sources.'),findsNothing);
  });
  testWidgets('permission change prevents late responses restoring revoked tasks',(tester)async{
    final delayed=Completer<dynamic>();
    Future<dynamic> rpc(String name,Map<String,dynamic> params)async{
      if(params['p_kind']=='maintenance')return delayed.future;
      return source([task('chair','chairs','open')]);
    }
    await tester.pumpWidget(host(CafeStaffTasks(kinds:const {'maintenance'},rpc:rpc)));
    await tester.pump();
    await tester.pumpWidget(host(CafeStaffTasks(kinds:const {'chairs'},rpc:rpc)));
    await tester.pumpAndSettle();
    delayed.complete(source([task('secret','maintenance','open')]));
    await tester.pumpAndSettle();
    expect(find.text('Task chair'),findsOneWidget);
    expect(find.text('Task secret'),findsNothing);
    expect(find.widgetWithText(ChoiceChip,'Table Maintenance'),findsNothing);
  });
  testWidgets('assignment confirms employee and retries same versioned command',(tester)async{
    tester.view.physicalSize=const Size(1200,1800);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final commands=<Map<String,dynamic>>[];
    await tester.pumpWidget(host(CafeStaffTasks(kinds:const {'maintenance'},rpc:(name,params)async{
      if(name=='get_cafe_table_task_workspace')return source([task('repair','maintenance','open')],admin:true);
      commands.add(Map<String,dynamic>.from(params));
      if(commands.length==1)throw StateError('response lost');
      return {'ok':true};
    })));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign employee'));await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));await tester.pumpAndSettle();
    await tester.tap(find.text('Ali').last);await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm assignment'));await tester.pumpAndSettle();
    expect(commands.single['p_id'],'repair');
    expect(commands.single['p_version'],3);
    expect(commands.single['p_data'],{'assigned_to':'employee-a'});
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton,'Assign employee')).onPressed,isNull);
    await tester.tap(find.text('Retry same assignment'));await tester.pumpAndSettle();
    expect(commands,hasLength(2));expect(commands[1],commands[0]);
    expect(find.text('Retry same assignment'),findsNothing);
  });
  testWidgets('report library limits reports and drops revoked selection',(tester)async{
    final requests=<Map<String,dynamic>>[];
    Future<dynamic> rpc(String name,Map<String,dynamic> params)async{
      requests.add(params);
      return {'columns':['Order'],'rows':[],'from':'2026-10-17','to':'2026-10-17'};
    }
    await tester.pumpWidget(host(CafeReportLibrary(allowed:const {'Kitchen Orders'},rpc:rpc)));
    await tester.pumpAndSettle();
    expect(find.text('Today Revenue'),findsNothing);
    await tester.tap(find.text('Kitchen Orders'));await tester.pumpAndSettle();
    expect(requests.single['p_card'],'kitchen_orders');
    expect(requests.single['p_section'],'dashboard');
    await tester.pumpWidget(host(CafeReportLibrary(allowed:const {},rpc:rpc)));await tester.pumpAndSettle();
    expect(find.text('All reports'),findsNothing);
    expect(find.text('No Dashboard report permissions have been assigned.'),findsOneWidget);
  });
  testWidgets('task board fits mobile RTL',(tester)async{
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host(Directionality(textDirection:TextDirection.rtl,child:
      CafeStaffTasks(kinds:cafeTaskSources.keys.toSet(),rpc:(name,params)async=>source([
        task('one',params['p_kind'] as String,'open')
      ])))));
    await tester.pumpAndSettle();expect(tester.takeException(),isNull);
  });
  testWidgets('dashboard task route does not grant underlying sources',(tester)async{
    tester.view.physicalSize=const Size(1440,1800);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home:StaffDashboardPage(email:'test@example.com',role:'staff',
      grantedPermissions:const {'dashboard:tasks'})));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('dashboard-search')),'Tasks');await tester.pumpAndSettle();
    final entry=find.byKey(const ValueKey('dashboard-card-tasks'));
    await tester.ensureVisible(entry);await tester.tap(entry);await tester.pumpAndSettle();
    expect(tester.widget<CafeStaffTasks>(find.byType(CafeStaffTasks)).kinds,isEmpty);
    expect(find.text('No table-task source access has been assigned.'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
