import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_table_overview.dart';

void main() {
  testWidgets('mode and status filters intersect without mutating tables', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <String>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: CafeTableOverview(onQr: (_) async {}, rpc: (name, params) async {
      calls.add(name);
      return {'server_time': DateTime.now().toUtc().toIso8601String(), 'capabilities': <String,dynamic>{}, 'tables': [
        {'id':'a','name':'Table 01','area':'Garden','seats':4,'status':'available','pricing_mode':'normal','requests':[]},
        {'id':'b','name':'Table 02','area':'Garden','seats':4,'status':'available','pricing_mode':'tourism','requests':[]},
        {'id':'c','name':'Table 03','area':'Hall','seats':4,'status':'cleaning','pricing_mode':'tourism','requests':[]},
      ]};
    })))));
    await tester.pumpAndSettle();
    expect(find.text('Table 01'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('Mode-All')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('tourism').last);
    await tester.pumpAndSettle();
    expect(find.text('Table 01'), findsNothing);
    expect(find.text('Table 02'), findsOneWidget);
    expect(find.text('Table 03'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('Status-All')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Available').last);
    await tester.pumpAndSettle();
    expect(find.text('Table 03'), findsNothing);
    expect(find.text('1 matching tables'), findsOneWidget);
    expect(calls.every((name) => name == 'get_cafe_table_overview'), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
