import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_customer_number.dart';
import 'package:gelye_sherane_cafe/cafe_operations_workspace.dart';
import 'package:gelye_sherane_cafe/cafe_table_overview.dart';
import 'package:gelye_sherane_cafe/staff_dashboard_page.dart';

final day = DateTime.utc(2026, 10, 17);
final now = DateTime.utc(2026, 10, 17, 12);
Map<String,dynamic> table(String id, int? guests) => {
  'id': id, 'name': 'Table $id', 'visit_id': 'visit-$id',
  'guest_count': guests, 'started_at': '2026-10-16T22:00:00Z',
  'payment_status': 'Paid — Still Seated',
};
Map<String,dynamic> reservation(String id, int guests, {
  String status = 'confirmed', String? arrived,
  String starts = '2026-10-17T15:00:00Z', String ends = '2026-10-17T16:00:00Z',
}) => {'id': id, 'table_id': '1', 'party_size': guests, 'status': status,
  'arrived_at': arrived, 'starts_at': starts, 'ends_at': ends};
Map<String,dynamic> history(List<List<dynamic>> rows) => {
  'columns': ['Table','Visit','Guests','Started (Baghdad)','Closed (Baghdad)','Minutes in selected period'],
  'rows': rows,
};
Map<String,dynamic> get completed => history([
  ['Table 2','closed-2',16,'2026-10-16 23:00','2026-10-17 10:00',660],
  ['Table 3','still-open',9,'2026-10-17 10:00',null,60],
  ['Table 4','next-day',3,'2026-10-17 10:00','2026-10-18 00:00',840],
]);

void main() {
  test('10 seated, 6 expected, 16 finished counts people and keeps paid guests seated', () {
    final result = summarizeCustomers(tables: [table('1',10),table('1',10)],
      reservations: [reservation('r1',6),reservation('r1',6),
        reservation('arrived',5,arrived:'2026-10-17T11:00:00Z'),
        reservation('cancelled',4,status:'cancelled'),
        reservation('expired',8,ends:'2026-10-17T11:00:00Z')],
      report: completed, from:day, to:day, now:now);
    expect(CustomerGuestSummary.knownCount(result.seated),10);
    expect(CustomerGuestSummary.knownCount(result.expected),6);
    expect(CustomerGuestSummary.knownCount(result.finished),16);
  });
  test('missing guest count stays unknown rather than a complete zero', () {
    final result = summarizeCustomers(tables:[table('1',null)],
      reservations:[], report:history([]),from:day,to:day,now:now);
    expect(CustomerGuestSummary.missingCount(result.seated),1);
    expect(result.seated.single.guests,isNull);
  });
  test('Baghdad midnight and selected departure date use half-open day boundaries', () {
    expect(customerDay(customerBaghdadDay(DateTime.utc(2026,10,16,21))), '2026-10-17');
    final result = summarizeCustomers(tables:[], reservations:[
      reservation('midnight',2,starts:'2026-10-16T21:00:00Z'),
      reservation('tomorrow',9,starts:'2026-10-17T21:00:00Z'),
    ],report:history([
      ['T','a',3,'2026-10-16 12:00','2026-10-17 00:00',0],
      ['T','b',8,'2026-10-17 12:00','2026-10-18 00:00',0],
    ]),from:day,to:day,now:now);
    expect(CustomerGuestSummary.knownCount(result.expected),2);
    expect(CustomerGuestSummary.knownCount(result.finished),3);
  });
  test('unexpected report schema is rejected instead of showing fabricated totals', () {
    expect(() => summarizeCustomers(tables:[], reservations:[],
      report:{'columns':['Guests'],'rows':[]},from:day,to:day,now:now), throwsFormatException);
  });
  testWidgets('mobile RTL shows counts and clears them on failed refresh', (tester) async {
    tester.view.physicalSize = const Size(390,1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var fail = false;
    final today = customerBaghdadDay(DateTime.now());
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(
      child:Directionality(textDirection:TextDirection.rtl,child:CafeCustomerNumber(
        rpc:(name,params) async {
          if (fail) throw StateError('Offline');
          if (name == 'get_cafe_table_overview') return {
            'server_time':DateTime.now().toUtc().toIso8601String(),'tables':[table('1',10)]};
          expect(params['p_card'],'guests_today');
          return history([['Table 2','done',16,'${customerDay(today)} 00:00','${customerDay(today)} 01:00',60]]);
        },
        reservations:(from,to) async => [reservation('r',6,
          starts:'${customerDay(today)}T18:00:00Z',ends:'${customerDay(today.add(const Duration(days:1)))}T20:00:00Z')],
      ))))));
    await tester.pumpAndSettle();
    expect(find.text('10 guests'),findsOneWidget);
    expect(find.text('6 guests'),findsOneWidget);
    expect(find.text('16 guests'),findsOneWidget);
    expect(tester.takeException(),isNull);
    fail = true;
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('10 guests'),findsNothing);
    expect(find.textContaining('Could not load customer counts'),findsOneWidget);
  });

  Future<void> open(WidgetTester tester,String title,{bool admin=true}) async {
    tester.view.physicalSize=const Size(1440,1800);
    tester.view.devicePixelRatio=1;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home:StaffDashboardPage(
      email:'review@example.com',role:admin?'admin':'staff',
      grantedPermissions: admin ? const {} : {
        'dashboard:customer_number','dashboard:customer_requests','dashboard:kitchen_live_board',
      })));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('dashboard-search')),title);
    await tester.pumpAndSettle();
    final entry=find.byKey(ValueKey('dashboard-card-${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'),'_')}'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
  }

  testWidgets('new card and remaining workflow routes open actual widgets', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester,'Customer Number');
    expect(find.byType(CafeCustomerNumber),findsOneWidget);
    await open(tester,'Customer Requests');
    expect(tester.widget<CafeTableOverview>(find.byType(CafeTableOverview)).requestsOnly,isTrue);
    await open(tester,'Kitchen Live Board');
    expect(tester.widget<CafeOperationsWorkspace>(find.byType(CafeOperationsWorkspace)).source,'all');
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('dashboard-only permissions cannot enter underlying workflows', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester,'Customer Number',admin:false);
    expect(find.byType(CafeCustomerNumber),findsNothing);
    expect(find.textContaining('Customer counts require'),findsOneWidget);
    await open(tester,'Customer Requests',admin:false);
    expect(find.byType(CafeTableOverview),findsNothing);
    await open(tester,'Kitchen Live Board',admin:false);
    expect(find.byType(CafeOperationsWorkspace),findsNothing);
  });
}
