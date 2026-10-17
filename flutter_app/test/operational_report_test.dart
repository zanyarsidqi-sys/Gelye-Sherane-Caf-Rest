import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_operational_report.dart';

void main() {
  testWidgets('report displays server rows and sends exact card permission scope', (tester) async {
    final requests=<Map<String,dynamic>>[];
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:CafeOperationalReport(section:'payment_management',card:'today_revenue',title:'Today Revenue',rpc:(name,params) async {
      expect(name,'get_cafe_operational_report');requests.add(params);
      return {'columns':['Method','Net IQD'],'rows':[['cash',3500],['manual_card',2000]],'note':'Recorded receipts'};
    })))));
    await tester.pumpAndSettle();
    expect(requests.single['p_section'],'payment_management');
    expect(requests.single['p_card'],'today_revenue');
    expect(find.text('3500'),findsOneWidget);
    await tester.enterText(find.byType(TextField),'manual_card');
    await tester.pump();
    expect(find.text('3500'),findsNothing);
    expect(find.text('2000'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
