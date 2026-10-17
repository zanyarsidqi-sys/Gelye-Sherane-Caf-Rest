import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_cash_workspace.dart';
import 'package:gelye_sherane_cafe/cafe_expense_workspace.dart';
import 'package:gelye_sherane_cafe/cafe_finance_surface.dart';

Widget host(Widget child, {bool rtl = false}) => MaterialApp(home: Scaffold(
  body: Directionality(textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: SingleChildScrollView(child: child)),
));

Map<String,dynamic> cashData({bool approve = false}) => {
  'balance_iqd': 10000,
  'capabilities': {'approve': approve},
  'entries': [
    {'id':'out','kind':'cash_out','amount_iqd':500,'method':'cash','reason':'Owner handover','status':'pending','created_at':'2026-10-17T09:00:00Z'},
    {'id':'in','kind':'cash_in','amount_iqd':1500,'method':'cash','reason':'Opening float','status':'posted','created_at':'invalid'},
  ],
  'counts': [],
};
Map<String,dynamic> expense(String id, int paid, String? due) => {
  'id':id,'supplier':id,'description':'Purchase $id','invoice_reference':id,
  'amount_iqd':1000,'paid_iqd':paid,'purchased_on':'2026-10-01','due_on':due,
  'evidence':[],'payments':[],
};
Map<String,dynamic> expensesData({bool canPay = false}) => {
  'can_create':false,'can_pay':canPay,'expenses':[
    expense('Overdue supplier', 250, '2020-01-01'),
    expense('Future supplier', 0, '2099-01-01'),
    expense('Paid supplier', 1000, '2020-01-01'),
  ],
};

void main() {
  test('malformed timestamp is not represented as a current timestamp', () {
    expect(cafeFinanceTimestamp('not a timestamp'), '—');
    expect(cafeFinanceTimestamp('2026-10-17T22:00:00Z'), '2026-10-18 01:00:00');
  });

  testWidgets('owner withdrawal card filters journal without changing balance or permissions', (tester) async {
    final requests = <Map<String,dynamic>>[];
    await tester.pumpWidget(host(CafeCashWorkspace(
      section:'dashboard',card:'cash_out_owner',title:'Cash Out — Owner',
      rpc:(name,params) async {expect(name,'get_cafe_cash_workspace');requests.add(params);return cashData();},
    )));
    await tester.pumpAndSettle();
    expect(requests.single, {'p_section':'dashboard','p_card':'cash_out_owner'});
    expect(find.text('Owner handover'), findsOneWidget);
    expect(find.text('Opening float'), findsNothing);
    expect(find.text('Recorded cash balance: 10000 IQD'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();
    expect(find.text('Owner handover'), findsNothing);
    expect(find.text('Recorded cash balance: 10000 IQD'), findsOneWidget);
    expect(requests.length, 1);
  });

  testWidgets('cash reload failure removes stale balance and approval controls', (tester) async {
    var calls = 0;
    await tester.pumpWidget(host(CafeCashWorkspace(
      section:'dashboard',card:'cash_out_owner',title:'Cash Out — Owner',
      rpc:(name,params) async {
        if (++calls > 1) throw StateError('permission revoked');
        return cashData(approve:true);
      },
    )));
    await tester.pumpAndSettle();
    expect(find.text('Approve'), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Recorded cash balance: 10000 IQD'), findsNothing);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Owner handover'), findsNothing);
    expect(find.textContaining('Could not load the cash journal.'), findsOneWidget);
  });

  testWidgets('late cash response cannot replace newly selected card data', (tester) async {
    final earlier = Completer<dynamic>();
    final later = Completer<dynamic>();
    Future<dynamic> rpc(String name, Map<String,dynamic> params) =>
      params['p_card']=='cash_in'?earlier.future:later.future;
    await tester.pumpWidget(host(CafeCashWorkspace(section:'dashboard',card:'cash_in',title:'Cash In',rpc:rpc)));
    await tester.pumpWidget(host(CafeCashWorkspace(section:'dashboard',card:'cash_out_owner',title:'Cash Out — Owner',rpc:rpc)));
    later.complete(cashData());
    await tester.pumpAndSettle();
    final stale = cashData()..['balance_iqd']=999;
    earlier.complete(stale);
    await tester.pumpAndSettle();
    expect(find.text('Recorded cash balance: 10000 IQD'), findsOneWidget);
    expect(find.text('Recorded cash balance: 999 IQD'), findsNothing);
  });

  testWidgets('expense overview includes paid purchases and overdue filter excludes paid debt', (tester) async {
    tester.view.physicalSize=const Size(390,1400);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host(CafeExpenseWorkspace(title:'Expenses',
      rpc:(name,params) async {expect(name,'get_cafe_expenses');return expensesData();}),rtl:true));
    await tester.pumpAndSettle();
    expect(find.text('Purchase Paid supplier'), findsOneWidget);
    expect(find.text('Total unpaid: 1750 IQD'), findsOneWidget);
    await tester.ensureVisible(find.text('Overdue'));
    await tester.tap(find.text('Overdue'));
    await tester.pumpAndSettle();
    expect(find.text('Purchase Overdue supplier'), findsOneWidget);
    expect(find.text('Purchase Paid supplier'), findsNothing);
    expect(find.text('Purchase Future supplier'), findsNothing);
    expect(find.text('Matching unpaid: 750 IQD'), findsOneWidget);
    expect(find.text('Total unpaid: 1750 IQD'), findsOneWidget);
    expect(find.text('Record expense payment'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expense failure hides stale debt and payment actions, retry restores records', (tester) async {
    var calls=0;
    await tester.pumpWidget(host(CafeExpenseWorkspace(title:'Pending Expenses',
      rpc:(name,params) async {
        if(++calls==2)throw StateError('offline');
        return expensesData(canPay:true);
      })));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Total unpaid: 1750 IQD'), findsNothing);
    expect(find.text('Record expense payment'), findsNothing);
    expect(find.text('No matching expenses.'), findsNothing);
    expect(find.textContaining('Could not load expenses.'), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Total unpaid: 1750 IQD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
