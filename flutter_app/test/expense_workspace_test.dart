import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_expense_workspace.dart';
import 'package:gelye_sherane_cafe/expense_evidence.dart';

class EvidenceFake implements ExpenseEvidence {
  int uploads=0;
  @override Future<bool> upload(String expenseId) async {expect(expenseId,'expense-1');uploads++;return true;}
  @override Future<void> download(Map<String,dynamic> evidence)async{}
}
void main(){
 testWidgets('evidence upload leaves purchase unpaid; payment is separate', (tester)async{
  tester.view.physicalSize=const Size(600,1400);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  final evidence=EvidenceFake();var paid=0;final calls=<String>[];
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:CafeExpenseWorkspace(title:'Unpaid Expenses',evidence:evidence,rpc:(name,p)async{
   calls.add(name);
   if(name=='pay_cafe_expense'){expect(p['p_expense_id'],'expense-1');expect(p['p_amount'],400);paid+=400;return 'payment-1';}
   return {'can_create':true,'can_pay':true,'expenses':[{'id':'expense-1','supplier':'Tea supplier','description':'Tea bought on credit','invoice_reference':'INV1','amount_iqd':1000,'paid_iqd':paid,'purchased_on':'2026-10-17','due_on':'2026-10-24','evidence':[],'payments':[]}]};
  })))));
  await tester.pumpAndSettle();
  expect(find.text('Total unpaid: 1000 IQD'),findsOneWidget);
  await tester.tap(find.text('Upload evidence'));await tester.pumpAndSettle();
  expect(evidence.uploads,1);expect(calls.where((c)=>c=='pay_cafe_expense'),isEmpty);
  expect(find.text('Total unpaid: 1000 IQD'),findsOneWidget);
  expect(find.text('Evidence uploaded. Payment status is unchanged.'),findsOneWidget);
  await tester.tap(find.text('Record expense payment'));await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField,'Payment amount IQD'),'400');
  await tester.tap(find.text('Confirm payment'));await tester.pumpAndSettle();
  expect(find.text('Total unpaid: 600 IQD'),findsOneWidget);
  expect(find.textContaining('Partially paid · Paid 400 · Remaining 600'),findsOneWidget);
  expect(tester.takeException(),isNull);
 });
}
