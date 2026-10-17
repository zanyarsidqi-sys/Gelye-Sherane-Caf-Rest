import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_customer_activity.dart';
import 'package:gelye_sherane_cafe/cafe_dashboard_alerts.dart';
import 'package:gelye_sherane_cafe/cafe_events.dart';
import 'package:gelye_sherane_cafe/staff_dashboard_page.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);
Map<String, dynamic> overview() => {
  'server_time': '2026-10-17T10:00:00Z',
  'tables': [
    {
      'id': 't',
      'name': 'Table 1',
      'area': 'Garden',
      'status': 'occupied',
      'visit_id': 'v',
      'customer_name': 'Zana',
      'guest_count': 10,
      'started_at': '2026-10-17T08:00:00Z',
      'payment_status': 'Paid — Still Seated',
      'pricing_mode': 'normal',
      'maintenance_blocked': true,
      'requests': [
        {
          'id': 'q',
          'kind': 'bill',
          'message': 'Individual bill',
          'status': 'open',
          'created_at': '2026-10-17T09:00:00Z',
        },
        {'id': 'done', 'kind': 'waiter', 'status': 'completed'},
      ],
      'reservation': {
        'id': 'r',
        'party_size': 6,
        'starts_at': '2026-10-17T12:00:00Z',
        'ends_at': '2026-10-17T13:00:00Z',
        'arrived_at': null,
      },
    },
  ],
};
Map<String, dynamic> values() => eventValues(
  title: 'Dinner',
  start: '2026-10-17 13:00',
  end: '2026-10-17 14:00',
  location: 'Garden',
  host: 'Manager',
  guests: '12',
  notes: 'Family event',
);
Map<String, dynamic> event() => {
  ...values(),
  'id': 'e',
  'status': 'open',
  'updated_at': '2026-10-17T09:00:00Z',
};

class FakeEvents implements CafeEventStore {
  List<Map<String, dynamic>> rows = [event()];
  final commands = <Map<String, dynamic>>[];
  bool failRead = false, ambiguous = false;
  @override
  Future<List<Map<String, dynamic>>> load() async {
    if (failRead) throw Exception('offline');
    return rows;
  }

  @override
  Future<void> save(Map<String, dynamic> command) async {
    commands.add(command);
    if (ambiguous) {
      ambiguous = false;
      throw TimeoutException('lost response');
    }
    rows = [
      {
        ...command['values'] as Map<String, dynamic>,
        'id': command['id'],
        'updated_at': '2026-10-17T11:00:00Z',
      },
    ];
  }
}

void main() {
  test('customer parties retain paid seated guests, deduplicate visits, and distinguish reservations', () {
    final data = overview();
    (data['tables'] as List).add(Map<String, dynamic>.from(data['tables'][0]));
    final rows = customerActivityRows(data);
    expect(rows, hasLength(2));
    expect(rows.first['status'], 'At table');
    expect(rows.first['guests'], 10);
    expect(rows.last['status'], 'Expected');
    data['tables'][0]['reservation']['arrived_at'] = '2026-10-17T09:00:00Z';
    expect(customerActivityRows(data).last['status'], 'Arrived');
    data['server_time'] = '2026-10-17T14:00:00Z';
    expect(customerActivityRows(data), hasLength(1));
  });
  test('alerts exclude completed requests and retain maintenance and cleaning conditions', () {
    final data = overview();
    data['tables'][0]['status'] = 'cleaning';
    final rows = tableAttentionRows(data);
    expect(
      rows.map((r) => r['kind']),
      containsAll(['Maintenance', 'Cleaning', 'Service request']),
    );
    expect(rows, hasLength(3));
    expect(rows.any((r) => r['id'] == 'request:done'), isFalse);
  });
  test('event times reject normalized invalid dates and enforce duration and quantities', () {
    expect(eventBaghdadInput('2026-02-30 12:00'), isNull);
    expect(eventBaghdadInput('2026-10-17 24:00'), isNull);
    expect(
      eventBaghdadInput('2026-10-17 00:30'),
      DateTime.utc(2026, 10, 16, 21, 30),
    );
    expect(
      () => eventValues(
        title: 'x',
        start: '2026-10-17 12:00',
        end: '2026-10-17 11:00',
        location: '',
        host: '',
        guests: '3',
        notes: '',
      ),
      throwsFormatException,
    );
    expect(
      () => eventValues(
        title: 'x',
        start: '2026-10-17 12:00',
        end: '2026-10-17 13:00',
        location: '',
        host: '',
        guests: '0',
        notes: '',
      ),
      throwsFormatException,
    );
  });
  test(
    'event day overlap uses Baghdad midnight and preserves unscheduled records',
    () {
      final row = event();
      row['metadata']['starts_at'] = '2026-10-16T20:30:00Z';
      row['metadata']['ends_at'] = '2026-10-16T22:30:00Z';
      expect(
        eventInPeriod(row, 'Today', DateTime.utc(2026, 10, 16, 22)),
        isTrue,
      );
      expect(
        eventInPeriod(row, 'Past', DateTime.utc(2026, 10, 16, 22)),
        isFalse,
      );
      expect(
        eventInPeriod({'metadata': {}}, 'Unscheduled', DateTime.now()),
        isTrue,
      );
      expect(eventInPeriod({'metadata': {}}, 'Today', DateTime.now()), isFalse);
    },
  );
  testWidgets('customer search and failed refresh remove prior personal data', (
    tester,
  ) async {
    var fail = false;
    await tester.pumpWidget(
      host(
        CafeCustomerActivity(
          rpc: (_, _) async {
            if (fail) throw Exception('denied');
            return overview();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Zana'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'garden');
    await tester.pumpAndSettle();
    expect(find.text('Zana'), findsOneWidget);
    fail = true;
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Zana'), findsNothing);
    expect(
      find.textContaining('Could not load customer activity'),
      findsOneWidget,
    );
  });
  testWidgets(
    'alert source failure is partial, and losing access removes previously loaded alerts',
    (tester) async {
      Future<dynamic> rpc(String name, Map<String, dynamic> params) async {
        if (name == 'get_cafe_table_overview') return overview();
        throw Exception('inventory denied');
      }

      await tester.pumpWidget(
        host(CafeDashboardAlerts(tables: true, inventory: true, rpc: rpc)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Inventory unavailable'), findsOneWidget);
      expect(find.text('Table 1 · Maintenance blocked'), findsOneWidget);
      await tester.pumpWidget(
        host(CafeDashboardAlerts(tables: false, inventory: true, rpc: rpc)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Table 1 · Maintenance blocked'), findsNothing);
      expect(
        find.text('No matching alerts in the available results.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('event command retry keeps exact identity and conflict version', (
    tester,
  ) async {
    final store = FakeEvents()..ambiguous = true;
    await tester.pumpWidget(host(CafeEvents(store: store, actor: 'staff')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start event'));
    await tester.tap(find.text('Start event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(store.commands, hasLength(1));
    await tester.ensureVisible(find.text('Retry same change'));
    await tester.tap(find.text('Retry same change'));
    await tester.pumpAndSettle();
    expect(store.commands, hasLength(2));
    expect(store.commands[0], equals(store.commands[1]));
    expect(store.commands[0]['expected'], '2026-10-17T09:00:00Z');
    expect(find.text('Retry same change'), findsNothing);
  });
  testWidgets(
    'events preserve legacy records, disclose truncation and clear on read failure',
    (tester) async {
      final store = FakeEvents()
        ..rows = List.generate(
          501,
          (i) => {
            'id': '$i',
            'title': 'Legacy $i',
            'details': '',
            'status': 'open',
            'metadata': <String, dynamic>{},
            'updated_at': '2026-10-17T09:00:00Z',
          },
        );
      await tester.pumpWidget(host(CafeEvents(store: store, actor: 'staff')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Only the 500'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Unscheduled'));
      await tester.pumpAndSettle();
      expect(find.text('Legacy 0'), findsOneWidget);
      expect(find.text('Edit event'), findsNothing);
      store.failRead = true;
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      expect(find.text('Legacy 0'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Plan event'),
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'three dashboard routes use dedicated views and preserve table permissions',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final admin in [true, false]) {
        for (final title in ['Customers', 'Notifications & Alerts', 'Events']) {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            MaterialApp(
              home: StaffDashboardPage(
                email: 'test@example.com',
                role: admin ? 'admin' : 'staff',
                grantedPermissions: const {
                  'dashboard:customers',
                  'dashboard:notifications_alerts',
                  'dashboard:events',
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('dashboard-search')),
            title,
          );
          await tester.pumpAndSettle();
          final entry = find.byKey(
            ValueKey(
              'dashboard-card-${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
            ),
          );
          await tester.ensureVisible(entry);
          await tester.tap(entry);
          await tester.pumpAndSettle();
          if (title == 'Customers') {
            expect(
              find.byType(CafeCustomerActivity),
              admin ? findsOneWidget : findsNothing,
            );
          }
          if (title == 'Events') {
            expect(find.byType(CafeEvents), findsOneWidget);
          }
          if (title == 'Notifications & Alerts') {
            final alert = tester.widget<CafeDashboardAlerts>(
              find.byType(CafeDashboardAlerts),
            );
            expect(alert.tables, admin);
            expect(alert.inventory, admin);
          }
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
  testWidgets('mobile RTL customer and alert cards fit without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final view in [
      CafeCustomerActivity(rpc: (_, _) async => overview()),
      CafeDashboardAlerts(
        tables: true,
        inventory: false,
        rpc: (_, _) async => overview(),
      ),
    ]) {
      await tester.pumpWidget(
        host(Directionality(textDirection: TextDirection.rtl, child: view)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
