import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_guest_page.dart';

class MemoryPending extends GuestPendingStore {
  String? value;
  bool fail = false;
  @override
  Future<String?> read(String key) async { if (fail) throw StateError('storage blocked'); return value; }
  @override
  Future<void> write(String key, String? data) async { value = data; }
}
Map<String,dynamic> portal() => {
  'table': {'name':'Table 2','area':'Garden','pricing_mode':'tourism'},
  'visit_id':'visit-2',
  'menu':[{'id':'tea','name':'Tea','description':'','category':'Drinks','price_iqd':3500}],
  'requests':[],
  'bill':{'orders':[], 'total_iqd':0,'paid_iqd':0,'balance_iqd':0},
};
void main() {
  testWidgets('QR page refreshes order status without exposing another visit', (tester) async {
    var status='received';
    await tester.pumpWidget(MaterialApp(home:CafeGuestPage(qrToken:'token',pendingStore:MemoryPending(),rpc:(name,params) async => {...portal(),'orders':[{'id':'01234567-order','status':status,'total_iqd':3500,'items':[{'name':'Tea','quantity':1}]}]})));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Received'),300,scrollable:find.descendant(of:find.byType(ListView),matching:find.byType(Scrollable)).first);
    expect(find.text('Received'),findsOneWidget);
    status='preparing';
    await tester.pump(const Duration(seconds:20));
    await tester.pumpAndSettle();
    expect(find.text('Preparing'),findsOneWidget);
    status='cancelled';
    await tester.pump(const Duration(seconds:20));
    await tester.pumpAndSettle();
    expect(find.text('Cancelled'),findsOneWidget);
    expect(find.text('This order is cancelled and excluded from your bill.'),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('QR order survives reload and retries the same quote', (tester) async {
    tester.view.physicalSize = const Size(500, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = MemoryPending();
    final submissions = <Map<String,dynamic>>[];
    Future<dynamic> rpc(String name, Map<String,dynamic> params) async {
      if (name == 'get_cafe_guest_portal') return portal();
      submissions.add(Map.of(params));
      if (submissions.length == 1) throw StateError('response lost');
      return {};
    }
    Widget page() => MaterialApp(home: CafeGuestPage(qrToken:'token',rpc:rpc,pendingStore:storage));
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add Tea'));
    await tester.pump();
    expect(find.text('Order total: 3500 IQD'), findsOneWidget);
    await tester.tap(find.text('Review and place order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm order'));
    await tester.pumpAndSettle();
    expect(storage.value, isNotNull);
    expect(submissions.single['p_expected_mode'], 'tourism');
    expect(submissions.single['p_visit_id'], 'visit-2');
    expect(submissions.single['p_expected_total'], 3500);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry pending request'));
    await tester.pumpAndSettle();
    expect(submissions[1], submissions[0]);
    expect(storage.value, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('storage failure cannot be bypassed by automatic refresh', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: CafeGuestPage(qrToken:'token', pendingStore:MemoryPending()..fail=true, rpc:(name,params) async { calls++; return portal(); })));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds:25));
    expect(calls, 0);
    expect(find.textContaining('Could not restore'), findsOneWidget);
    expect(find.text('Review and place order'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
