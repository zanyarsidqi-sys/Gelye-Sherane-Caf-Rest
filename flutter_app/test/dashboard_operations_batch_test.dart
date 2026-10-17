import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_service_speed.dart';
import 'package:gelye_sherane_cafe/cafe_reservation_filters.dart';
import 'package:gelye_sherane_cafe/cafe_table_reservation_repository.dart';
import 'package:gelye_sherane_cafe/cafe_dashboard_tables.dart';
import 'package:gelye_sherane_cafe/cafe_dashboard_fulfilment.dart';
import 'package:gelye_sherane_cafe/cafe_operations_workspace.dart';
import 'package:gelye_sherane_cafe/cafe_station_workspace.dart';
import 'package:gelye_sherane_cafe/cafe_operational_report.dart';
import 'package:gelye_sherane_cafe/staff_dashboard_page.dart';

Map<String,dynamic> timing(List<List<dynamic>> rows)=> {
  'columns':['Order','Created (Baghdad)','Source','Table / destination','Status','Minutes to ready'],
  'rows':rows,'from':'2026-10-17','to':'2026-10-17',
};
List<dynamic> timed(String id,String status,dynamic minutes)=>[id,'2026-10-17 10:00','table','Table 1',status,minutes];
CafeTableReservation booking(String start,String end)=>CafeTableReservation(
  id:'r',requestId:'rq',tableId:'t',customerName:'Family',contact:'12345',partySize:4,
  startsAt:DateTime.parse(start),endsAt:DateTime.parse(end),status:'confirmed',notes:'',
  createdAt:DateTime.utc(2026,10,16),
);
Widget host(Widget child)=>MaterialApp(home:Scaffold(body:SingleChildScrollView(child:child)));

void main() {
  test('timing excludes cancelled and missing values without substituting zeros',(){
    final result=cafeServiceSpeedReport(timing([
      timed('1','ready',10),timed('2','served',20),timed('3','ready',30),
      timed('4','cancelled',100),timed('5','received',null),timed('6','ready',-2),
    ]));
    expect(result['rows'],hasLength(5));
    expect(result['note'],contains('3 measured orders'));
    expect(result['note'],contains('2 without usable timing'));
    expect(result['note'],contains('Average: 20.0 min'));
    expect(result['note'],contains('Median: 20.0 min'));
    expect((result['rows'] as List).last.last,isNull);
  });
  test('no timing is not a zero-minute performance result',(){
    final result=cafeServiceSpeedReport(timing([timed('1','received',null)]));
    expect(result['note'],contains('Average: Not recorded'));
    expect(()=>cafeServiceSpeedReport({'columns':['Order'],'rows':[]}),throwsFormatException);
  });
  test('reservation date scope follows Baghdad midnight and overlaps',(){
    final now=DateTime.utc(2026,10,16,22);
    final crossing=booking('2026-10-16T20:30:00Z','2026-10-16T22:30:00Z');
    final ended=booking('2026-10-16T19:00:00Z','2026-10-16T21:00:00Z');
    final tomorrow=booking('2026-10-17T21:00:00Z','2026-10-17T22:00:00Z');
    expect(cafeReservationInPeriod(crossing,'Today',now),isTrue);
    expect(cafeReservationInPeriod(ended,'Today',now),isFalse);
    expect(cafeReservationInPeriod(ended,'Past',now),isTrue);
    expect(cafeReservationInPeriod(tomorrow,'Upcoming',now),isTrue);
    expect(cafeReservationInPeriod(tomorrow,'Today',now),isFalse);
  });
  test('tourism guests requires active visit and actual tourism mode',(){
    expect(dashboardTableMatches('Tourism Customers',{'visit_id':'v','pricing_mode':'tourism'}),isTrue);
    expect(dashboardTableMatches('Tourism Customers',{'visit_id':null,'pricing_mode':'tourism','status':'available'}),isFalse);
    expect(dashboardTableMatches('Tourism Customers',{'visit_id':'v','pricing_mode':'normal'}),isFalse);
  });
  testWidgets('fulfilment exposes only authorized source and switches real source query',(tester) async {
    final sources=<String>[];
    Future<dynamic> rpc(String name,Map<String,dynamic> params)async {
      sources.add(params['p_source'] as String);return [];
    }
    await tester.pumpWidget(host(CafeDashboardFulfilment(online:true,walkIn:true,rpc:rpc)));
    await tester.pumpAndSettle();
    expect(sources,['online']);
    await tester.tap(find.widgetWithText(ChoiceChip,'Walk-in orders'));await tester.pumpAndSettle();
    expect(sources,['online','walk_in']);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host(CafeDashboardFulfilment(online:false,walkIn:true,rpc:rpc)));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip,'Online orders'),findsNothing);
    expect(sources.last,'walk_in');
  });
  testWidgets('order refresh failure removes stale orders',(tester) async {
    var fail=false;
    await tester.pumpWidget(host(CafeOperationsWorkspace(source:'online',canCreate:false,
      rpc:(name,params)async {
        if(fail)throw StateError('Offline');
        return [{'id':'order-1','table_name':'Pickup A','source':'online','status':'received',
          'total_iqd':1000,'items':[],'notes':''}];
      })));
    await tester.pumpAndSettle();
    expect(find.text('Order order-1'),findsOneWidget);
    fail=true;await tester.tap(find.text('Refresh'));await tester.pumpAndSettle();
    expect(find.text('Order order-1'),findsNothing);
    expect(find.textContaining('Could not load records'),findsOneWidget);
  });
  testWidgets('station refresh failure clears prior station and disables test print',(tester) async {
    var fail=false;
    await tester.pumpWidget(host(CafeStationWorkspace(rpc:(name,params)async {
      if(fail)throw StateError('Offline');
      if(name=='get_cafe_print_stations')return {'stations':[{'id':'s','name':'Drinks','active':true}],'can_manage':true};
      return {'tickets':[],'unrouted_products':0};
    })));
    await tester.pumpAndSettle();
    expect(find.text('Drinks'),findsOneWidget);
    fail=true;await tester.tap(find.text('Refresh'));await tester.pumpAndSettle();
    expect(find.text('Drinks'),findsNothing);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton,'Test printer')).onPressed,isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('dashboard new routes preserve underlying permissions',(tester) async {
    tester.view.physicalSize=const Size(1440,1800);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    for(final admin in [true,false]) {
      for(final title in ['Station Printers','Service Speed','Takeaway & Delivery']) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(MaterialApp(home:StaffDashboardPage(email:'test@example.com',role:admin?'admin':'staff',
          grantedPermissions:const {'dashboard:station_printers','dashboard:service_speed','dashboard:takeaway_delivery'})));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('dashboard-search')),title);await tester.pumpAndSettle();
        final entry=find.byKey(ValueKey('dashboard-card-${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'),'_')}'));
        await tester.ensureVisible(entry);await tester.tap(entry);await tester.pumpAndSettle();
        final view= title=='Station Printers'?find.byType(CafeStationWorkspace):
          title=='Service Speed'?find.byType(CafeOperationalReport):find.byType(CafeOperationsWorkspace);
        expect(view,admin?findsOneWidget:findsNothing);
        expect(tester.takeException(),isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
  });
}
