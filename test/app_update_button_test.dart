import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_cafe_rest/shared/app_update_button.dart';

void main() {
  testWidgets('confirms before starting a web app update', (tester) async {
    var updateStarted = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppUpdateButton(
          onUpdate: () async {
            updateStarted = true;
          },
        ),
      ),
    ));

    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Save your work before continuing.'),
      findsOneWidget,
    );
    expect(updateStarted, isFalse);

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Update now'),
    ));
    await tester.pumpAndSettle();
    expect(updateStarted, isTrue);
  });

  testWidgets('cancel keeps the current app open', (tester) async {
    var updateStarted = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppUpdateButton(
          onUpdate: () async {
            updateStarted = true;
          },
        ),
      ),
    ));

    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(updateStarted, isFalse);
    expect(find.text('Update now'), findsOneWidget);
  });
}
