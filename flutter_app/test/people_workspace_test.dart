
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_people_workspace.dart';
import 'package:gelye_sherane_cafe/staff_dashboard_page.dart';

Map<String,dynamic> feedback({String state='open',int? rating})=>{
 'id':'feedback-1','version':2,'title':'Cold tea','details':'Please replace','customer_name':'Guest',
 'category':'complaint','rating':rating,'status':state,'created_at':'2026-10-17T10:00:00Z','resolution':'',
};
Map<String,dynamic> attendance({bool closed=false})=>{
 'id':'attendance-1','version':1,'employee_name':'Ali','clocked_in_at':'2026-10-16T20:00:00Z',
 'clocked_out_at':closed?'2026-10-17T10:00:00Z':null,'period_seconds':3600,
};
Map<String,dynamic> data(List<Map<String,dynamic>> rows,{bool admin=false,Map<String,dynamic>? active,
 List<Map<String,dynamic>> events=const [],bool truncated=false})=>{
 'rows':rows,'events':events,'active':active,'can_admin':admin,'total_count':truncated?501:rows.length,
 'truncated':truncated,'server_time':'2026-10-17T11:00:00Z',
};
Widget host(Widget child)=>MaterialApp(home:Scaffold(body:SingleChildScrollView(child:child)));
void wide(WidgetTester tester){
 tester.view.physicalSize=const Size(1440,1800);tester.view.devicePixelRatio=1;
 addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
}
void main(){
 test('review actions reserve dismissal and reopening for administrators',(){
  expect(cafeFeedbackActions('open',false),['in_review']);
  expect(cafeFeedbackActions('in_review',false),['resolved']);
  expect(cafeFeedbackActions('resolved',false),isEmpty);
  expect(cafeFeedbackActions('dismissed',true),['open']);
 });
 test('response validation rejects invalid rating and time',(){
  expect(()=>cafePeopleData(data([feedback(rating:6)]),'feedback'),throwsFormatException);
  expect(()=>cafePeopleData(data([{...attendance(),'period_seconds':-1}]),'attendance'),throwsFormatException);
  expect(cafePeopleData(data([feedback()]),'feedback')['rows'],hasLength(1));
 });
 testWidgets('feedback distinguishes unrated records and partial loaded results',(tester)async{
  await tester.pumpWidget(host(CafePeopleWorkspace(kind:'feedback',rpc:(name,params)async{
   expect(name,'get_cafe_people_workspace');
   expect(DateTime.parse(params['p_to']).difference(DateTime.parse(params['p_from'])).inDays,29);
   return data([feedback()],truncated:true);
  })));
  await tester.pumpAndSettle();
  expect(find.text('No ratings in the matching records.'),findsOneWidget);
  expect(find.textContaining('Showing the newest 500'),findsOneWidget);
  expect(find.textContaining('501 records in selected dates'),findsOneWidget);
 });
 testWidgets('feedback load failure clears previously loaded content and disables writes',(tester)async{
  var fail=false;
  await tester.pumpWidget(host(CafePeopleWorkspace(kind:'feedback',rpc:(name,params)async{
   if(fail)throw StateError('offline');return data([feedback()]);
  })));
  await tester.pumpAndSettle();expect(find.text('Cold tea'),findsOneWidget);
  fail=true;await tester.tap(find.text('Refresh'));await tester.pumpAndSettle();
  expect(find.text('Cold tea'),findsNothing);
  expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton,'Record feedback')).onPressed,isNull);
 });
 testWidgets('feedback form validates subject and retry preserves the exact request',(tester)async{
  wide(tester);final commands=<Map<String,dynamic>>[];
  await tester.pumpWidget(host(CafePeopleWorkspace(kind:'feedback',rpc:(name,params)async{
   if(name=='get_cafe_people_workspace')return data([]);
   commands.add(Map<String,dynamic>.from(params));
   if(commands.length==1)throw StateError('lost response');
   return {'ok':true};
  })));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Record feedback'));await tester.pumpAndSettle();
  await tester.tap(find.text('Save feedback'));await tester.pumpAndSettle();
  expect(find.text('Enter a subject'),findsOneWidget);expect(commands,isEmpty);
  await tester.enterText(find.byType(TextFormField).first,'Cold tea');
  await tester.tap(find.text('Save feedback'));await tester.pumpAndSettle();
  expect(commands.single['p_action'],'create');
  expect(commands.single['p_data']['rating'],isNull);
  expect(commands.single['p_data']['title'],'Cold tea');
  expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton,'Record feedback')).onPressed,isNull);
  await tester.tap(find.text('Retry same request'));await tester.pumpAndSettle();
  expect(commands,hasLength(2));expect(commands[1],commands[0]);
 });
 testWidgets('resolution requires a note and submits selected record version',(tester)async{
  wide(tester);final commands=<Map<String,dynamic>>[];
  await tester.pumpWidget(host(CafePeopleWorkspace(kind:'feedback',rpc:(name,params)async{
   if(name=='get_cafe_people_workspace')return data([feedback(state:'in_review')]);
   commands.add(params);return {};
  })));await tester.pumpAndSettle();
  await tester.tap(find.text('Resolve feedback'));await tester.pumpAndSettle();
  await tester.tap(find.text('Confirm'));await tester.pumpAndSettle();
  expect(commands,isEmpty);expect(find.text('Enter at least 3 characters'),findsOneWidget);
  await tester.enterText(find.byType(TextFormField),'Replaced the tea');
  await tester.tap(find.text('Confirm'));await tester.pumpAndSettle();
  expect(commands.single['p_id'],'feedback-1');expect(commands.single['p_version'],2);
  expect(commands.single['p_data'],{'resolution':'Replaced the tea'});
 });
 testWidgets('clock-out uses current open session outside the selected date range',(tester)async{
  wide(tester);final commands=<Map<String,dynamic>>[];
  await tester.pumpWidget(host(CafePeopleWorkspace(kind:'attendance',rpc:(name,params)async{
   if(name=='get_cafe_people_workspace'){
    expect(params['p_from'],params['p_to']);return data([],active:attendance());
   }
   commands.add(params);return {};
  })));await tester.pumpAndSettle();
  await tester.tap(find.text('Clock out'));await tester.pumpAndSettle();
  await tester.tap(find.text('Cancel'));await tester.pumpAndSettle();expect(commands,isEmpty);
  await tester.tap(find.text('Clock out'));await tester.pumpAndSettle();
  await tester.tap(find.text('Confirm'));await tester.pumpAndSettle();
  expect(commands.single['p_id'],'attendance-1');expect(commands.single['p_version'],1);
  expect(commands.single['p_action'],'clock_out');expect(commands.single['p_data'],isEmpty);
 });
 testWidgets('clock-in supplies neither timestamp nor employee identity',(tester)async{
  final commands=<Map<String,dynamic>>[];
  await tester.pumpWidget(host(CafePeopleWorkspace(kind:'attendance',rpc:(name,params)async{
   if(name=='get_cafe_people_workspace')return data([]);
   commands.add(params);return {};
  })));await tester.pumpAndSettle();
  await tester.tap(find.text('Clock in'));await tester.pumpAndSettle();
  await tester.tap(find.text('Confirm'));await tester.pumpAndSettle();
  expect(commands.single['p_action'],'clock_in');expect(commands.single['p_id'],isNull);
  expect(commands.single['p_version'],isNull);expect(commands.single['p_data'],isEmpty);
 });
 testWidgets('history selects events for the requested record only',(tester)async{
  wide(tester);
  await tester.pumpWidget(host(CafePeopleWorkspace(kind:'feedback',rpc:(name,params)async=>data([feedback()],events:[
   {'entity_id':'feedback-1','action':'resolved','created_at':'2026-10-17T10:05:00Z','current':{'resolution':'Tea replaced'}},
   {'entity_id':'other','action':'resolved','created_at':'2026-10-17T10:05:00Z','current':{'resolution':'Other private record'}},
  ]))));
  await tester.pumpAndSettle();await tester.tap(find.text('History'));await tester.pumpAndSettle();
  expect(find.textContaining('Tea replaced'),findsOneWidget);
  expect(find.textContaining('Other private record'),findsNothing);
 });
 testWidgets('feedback form and attendance fit a 390-pixel RTL screen',(tester)async{
  tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  for(final kind in ['feedback','attendance']){
   await tester.pumpWidget(const SizedBox());
   await tester.pumpWidget(host(Directionality(textDirection:TextDirection.rtl,child:
    CafePeopleWorkspace(kind:kind,rpc:(name,params)async=>data(kind=='feedback'?[feedback()]:[attendance()])))));
   await tester.pumpAndSettle();expect(tester.takeException(),isNull);
   if(kind=='feedback'){
    await tester.tap(find.text('Record feedback'));await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
    await tester.tap(find.text('Cancel'));await tester.pumpAndSettle();
   }
  }
 });
 testWidgets('four Dashboard routes connect only after their card permission',(tester)async{
  wide(tester);
  for(final title in ['Customer Feedback','Feedback','Employee Attendance','Attendance']){
   await tester.pumpWidget(const SizedBox());
   final slug=title.toLowerCase().replaceAll(' ','_');
   await tester.pumpWidget(MaterialApp(home:StaffDashboardPage(email:'test@example.com',role:'staff',
    grantedPermissions:{'dashboard:$slug'})));
   await tester.pumpAndSettle();
   await tester.enterText(find.byKey(const ValueKey('dashboard-search')),title);await tester.pumpAndSettle();
   final card=find.byKey(ValueKey('dashboard-card-$slug'));
   await tester.ensureVisible(card);await tester.tap(card);await tester.pumpAndSettle();
   expect(tester.widget<CafePeopleWorkspace>(find.byType(CafePeopleWorkspace)).kind,
     title.contains('Feedback')?'feedback':'attendance');
   expect(tester.takeException(),isNull);
  }
 });
}
