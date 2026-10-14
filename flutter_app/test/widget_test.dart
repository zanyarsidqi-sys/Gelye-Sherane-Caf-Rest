import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/main.dart';

void main() {
  testWidgets('shows the cafe landing page without the management showcase', (
    tester,
  ) async {
    await tester.pumpWidget(const CafeApp());
    await tester.pumpAndSettle();

    expect(find.text('Gelye Sherane'), findsNWidgets(2));
    expect(find.text('Gelye Sherane\nCafé & Restaurant'), findsOneWidget);
    expect(find.text('A taste to look forward to'), findsOneWidget);
    expect(find.text('Dashboard Management'), findsNothing);
    expect(find.text('BUILT AROUND HOSPITALITY'), findsNothing);
    expect(find.text('A thoughtful cafe, well run'), findsNothing);
  });

  testWidgets('menu link scrolls to the menu section', (tester) async {
    await tester.pumpWidget(const CafeApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explore menu'));
    await tester.pumpAndSettle();

    expect(find.text('A taste to look forward to'), findsOneWidget);
    expect(find.text('Coffee & tea'), findsOneWidget);
  });

  testWidgets('reservation form validates required contact details', (
    tester,
  ) async {
    await tester.pumpWidget(const CafeApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Book a table').first);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Plan your visit'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.text('Enter a valid phone number'), findsOneWidget);
  });

  testWidgets('staff sign-in explains when Supabase is not configured', (
    tester,
  ) async {
    await tester.pumpWidget(const CafeApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Staff sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Staff sign in'), findsOneWidget);
    expect(
      find.textContaining('not configured for this deployment'),
      findsOneWidget,
    );
  });

  testWidgets('staff sign-in rejects a mismatched Supabase configuration', (
    tester,
  ) async {
    await tester.pumpWidget(const CafeApp(supabaseConfigurationProvided: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Staff sign in'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('incomplete or does not match the approved project'),
      findsOneWidget,
    );
    expect(find.text('Sign in'), findsNothing);
  });
}
