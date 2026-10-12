import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_cafe_rest/services/station_print_worker.dart';
import 'package:gelye_cafe_rest/services/station_device_session_service.dart';

class _FakePrinter implements StationPrinterAdapter {
  int calls = 0;
  StationPrintOutcome result = StationPrintOutcome.printed;
  @override
  Future<StationPrintOutcome> print(String text) async {
    calls++;
    return result;
  }
}

class _DeferredPrinter implements StationPrinterAdapter {
  final started = Completer<void>();
  final outcome = Completer<StationPrintOutcome>();
  int calls = 0;
  @override
  Future<StationPrintOutcome> print(String text) {
    calls++;
    if (!started.isCompleted) started.complete();
    return outcome.future;
  }
}

StationPrintTicket _ticket() => const StationPrintTicket(
  ticketId: 12, attempt: 1, station: 'kitchen', orderId: 99,
  items: [StationPrintItem(product: 'Tea', quantity: 2)],
);
Map<String, dynamic> _claim() => {
  'ticket_id': 12, 'attempt': 1, 'station_key': 'kitchen', 'order_id': 99,
};

void main() {
  test('confirmed print is acknowledged once', () async {
    final printer = _FakePrinter();
    final results = <String>[];
    final worker = StationPrintWorker(
      session: StationDeviceSessionService(), printer: printer,
      resolveTicket: (_) async => _ticket(), claimTicket: () async => _claim(),
      ackTicket: ({required ticketId, required attempt, required result, error}) async {
        expect(ticketId, 12);
        expect(attempt, 1);
        results.add(result);
      },
    );
    await worker.pollOnce();
    expect(printer.calls, 1);
    expect(results, ['printed']);
    expect(worker.uncertainTicketIds, isEmpty);
  });

  test('uncertain print is never acknowledged or printed again', () async {
    final printer = _FakePrinter()..result = StationPrintOutcome.uncertain;
    var acknowledgments = 0;
    final worker = StationPrintWorker(
      session: StationDeviceSessionService(), printer: printer,
      resolveTicket: (_) async => _ticket(), claimTicket: () async => _claim(),
      ackTicket: ({required ticketId, required attempt, required result, error}) async {
        acknowledgments++;
      },
    );
    await worker.pollOnce();
    await worker.pollOnce();
    expect(printer.calls, 1);
    expect(acknowledgments, 0);
    expect(worker.uncertainTicketIds, contains('original:12'));
  });

  test('shutdown during server claim prevents resolver and physical print', () async {
    final pendingClaim = Completer<Map<String, dynamic>?>();
    final printer = _FakePrinter();
    var resolutions = 0;
    final worker = StationPrintWorker(
      session: StationDeviceSessionService(), printer: printer,
      claimTicket: () => pendingClaim.future,
      resolveTicket: (_) async { resolutions++; return _ticket(); },
    );
    final poll = worker.pollOnce();
    worker.stop();
    pendingClaim.complete(_claim());
    await poll;
    expect(resolutions, 0);
    expect(printer.calls, 0);
    expect(worker.uncertainTicketIds, contains('original:12'));
  });

  test('malformed station claim never reaches resolver or printer', () async {
    final printer = _FakePrinter();
    var resolutions = 0;
    final worker = StationPrintWorker(
      session: StationDeviceSessionService(), printer: printer,
      claimTicket: () async => {..._claim(), 'station_key': ''},
      resolveTicket: (_) async { resolutions++; return _ticket(); },
    );
    await worker.pollOnce();
    expect(resolutions, 0);
    expect(printer.calls, 0);
  });

  test('formatter rejects control characters as ticket metadata', () {
    expect(StationTicketFormatter.format(_ticket()), contains('2 x Tea'));
    expect(() => StationTicketFormatter.format(const StationPrintTicket(
      ticketId: 0, attempt: 1, station: 'kitchen', orderId: 99,
      items: [StationPrintItem(product: 'Tea', quantity: 1)],
    )), throwsArgumentError);
  });

  test('mismatched resolved ticket is held without printing', () async {
    final printer = _FakePrinter();
    final worker = StationPrintWorker(
      session: StationDeviceSessionService(), printer: printer,
      claimTicket: () async => _claim(),
      resolveTicket: (_) async => const StationPrintTicket(
        ticketId: 13, attempt: 1, station: 'kitchen', orderId: 99,
        items: [StationPrintItem(product: 'Tea', quantity: 1)],
      ),
    );
    await worker.pollOnce();
    expect(printer.calls, 0);
    expect(worker.uncertainTicketIds, contains('original:12'));
  });

  test('acknowledgment failure never allows an automatic second print', () async {
    final printer = _FakePrinter();
    var ackCalls = 0;
    final worker = StationPrintWorker(
      session: StationDeviceSessionService(), printer: printer,
      claimTicket: () async => _claim(), resolveTicket: (_) async => _ticket(),
      ackTicket: ({required ticketId, required attempt, required result, error}) async {
        ackCalls++;
        throw StateError('connection dropped after print');
      },
    );
    await worker.pollOnce();
    await worker.pollOnce();
    expect(printer.calls, 1);
    expect(ackCalls, 1);
    expect(worker.uncertainTicketIds, contains('original:12'));
  });

  test('stop during physical printing holds ticket without ACK', () async {
    final printer = _DeferredPrinter();
    var ackCalls = 0;
    final worker = StationPrintWorker(
      session: StationDeviceSessionService(), printer: printer,
      claimTicket: () async => _claim(), resolveTicket: (_) async => _ticket(),
      ackTicket: ({required ticketId, required attempt, required result, error}) async {
        ackCalls++;
      },
    );
    final pending = worker.pollOnce();
    await printer.started.future;
    worker.stop();
    printer.outcome.complete(StationPrintOutcome.printed);
    await pending;
    expect(printer.calls, 1);
    expect(ackCalls, 0);
    expect(worker.uncertainTicketIds, contains('original:12'));
  });

  test('confirmed print during logout remains protected after worker restart', () async {
    final printer = _DeferredPrinter();
    var acknowledgments = 0;
    final worker = StationPrintWorker(
      session: StationDeviceSessionService(), printer: printer,
      claimTicket: () async => _claim(), resolveTicket: (_) async => _ticket(),
      ackTicket: ({required ticketId, required attempt, required result, error}) async {
        acknowledgments++;
      },
    );
    final pending = worker.pollOnce();
    await printer.started.future;
    worker.stop();
    printer.outcome.complete(StationPrintOutcome.printed);
    await pending;
    expect(acknowledgments, 0);
    // Simulate reactivating the same worker; no repeated physical print.
    worker.start(interval: const Duration(hours: 1));
    await Future<void>.delayed(Duration.zero);
    await worker.pollOnce();
    worker.stop();
    expect(printer.calls, 1);
    expect(worker.uncertainTicketIds, contains('original:12'));
  });

  test('stop during confirmed printer failure also holds ticket', () async {
    final printer = _DeferredPrinter();
    var ackCalls = 0;
    final worker = StationPrintWorker(
      session: StationDeviceSessionService(), printer: printer,
      claimTicket: () async => _claim(), resolveTicket: (_) async => _ticket(),
      ackTicket: ({required ticketId, required attempt, required result, error}) async {
        ackCalls++;
      },
    );
    final pending = worker.pollOnce();
    await printer.started.future;
    worker.stop();
    printer.outcome.complete(StationPrintOutcome.definitelyFailed);
    await pending;
    expect(ackCalls, 0);
    expect(worker.uncertainTicketIds, contains('original:12'));
  });

  test('stop during ticket resolution prevents printing', () async {
    final pendingTicket = Completer<StationPrintTicket>();
    final printer = _FakePrinter();
    final worker = StationPrintWorker(
      session: StationDeviceSessionService(), printer: printer,
      claimTicket: () async => _claim(), resolveTicket: (_) => pendingTicket.future,
    );
    final poll = worker.pollOnce();
    await Future<void>.delayed(Duration.zero);
    worker.stop();
    pendingTicket.complete(_ticket());
    await poll;
    expect(printer.calls, 0);
    expect(worker.uncertainTicketIds, contains('original:12'));
  });
  test('malformed claimed station is held for manual review', () async {
    final printer = _FakePrinter();
    var resolved = false;
    final worker = StationPrintWorker(
      session: StationDeviceSessionService(), printer: printer,
      claimTicket: () async => {..._claim(), 'station_key': 'kitchen\nFAKE'},
      resolveTicket: (_) async { resolved = true; return _ticket(); },
    );
    await worker.pollOnce();
    expect(resolved, isFalse);
    expect(printer.calls, 0);
    expect(worker.uncertainTicketIds, contains('original:12'));
  });

  test('invalid attempt retains valid claim identity for review', () async {
    final printer = _FakePrinter();
    final worker = StationPrintWorker(
      session: StationDeviceSessionService(), printer: printer,
      claimTicket: () async => {..._claim(), 'attempt': 0},
      resolveTicket: (_) async => _ticket(),
    );
    await worker.pollOnce();
    expect(printer.calls, 0);
    expect(worker.uncertainTicketIds, contains('original:12'));
  });

  test('formatter rejects oversized item lists before building receipt', () {
    final manyItems = List<StationPrintItem>.filled(
      501, const StationPrintItem(product: 'Tea', quantity: 1));
    expect(() => StationTicketFormatter.format(StationPrintTicket(
      ticketId: 12, attempt: 1, station: 'kitchen', orderId: 99,
      items: manyItems,
    )), throwsArgumentError);
  });


  test('unsafe queue identifiers are rejected before polling', () {
    final worker = StationPrintWorker(
      session: StationDeviceSessionService(), printer: _FakePrinter(),
      queueName: 'original\nother', resolveTicket: (_) async => _ticket(),
    );
    expect(() => worker.start(), throwsArgumentError);
  });

  test('overlong item notes are rejected before printer output', () {
    final ticket = StationPrintTicket(
      ticketId: 12, attempt: 1, station: 'kitchen', orderId: 99,
      items: [StationPrintItem(product: 'Tea', quantity: 1,
        note: List<String>.filled(2049, 'x').join())],
    );
    expect(() => StationTicketFormatter.format(ticket), throwsArgumentError);
  });

  test('overlong station metadata is rejected', () {
    final ticket = StationPrintTicket(
      ticketId: 12, attempt: 1, station: List<String>.filled(129, 'x').join(), orderId: 99,
      items: const [StationPrintItem(product: 'Tea', quantity: 1)],
    );
    expect(() => StationTicketFormatter.format(ticket), throwsArgumentError);
  });


  test('direct polling rejects unsafe queue before server claim', () async {
    var claims = 0;
    final worker = StationPrintWorker(
      session: StationDeviceSessionService(), printer: _FakePrinter(),
      queueName: 'bad\nqueue',
      claimTicket: () async { claims++; return _claim(); },
      resolveTicket: (_) async => _ticket(),
    );
    await expectLater(worker.pollOnce(), throwsArgumentError);
    expect(claims, 0);
  });

  test('claim with invisible station character is held without printing', () async {
    final printer = _FakePrinter();
    final worker = StationPrintWorker(
      session: StationDeviceSessionService(), printer: printer,
      claimTicket: () async => {..._claim(), 'station_key': 'kit\u200bchen'},
      resolveTicket: (_) async => _ticket(),
    );
    await worker.pollOnce();
    expect(printer.calls, 0);
    expect(worker.uncertainTicketIds, contains('original:12'));
  });

  test('formatter rejects ambiguous station identifiers', () {
    expect(() => StationTicketFormatter.format(const StationPrintTicket(
      ticketId: 12, attempt: 1, station: 'kitchen\u200b', orderId: 99,
      items: [StationPrintItem(product: 'Tea', quantity: 1)],
    )), throwsArgumentError);
  });
  test('duplicate server claim after printed ACK does not print twice', () async {
    final printer = _FakePrinter();
    var acks = 0;
    final worker = StationPrintWorker(
      session: StationDeviceSessionService(), printer: printer,
      claimTicket: () async => _claim(), resolveTicket: (_) async => _ticket(),
      ackTicket: ({required ticketId, required attempt, required result, error}) async {
        acks++;
      },
    );
    await worker.pollOnce();
    await worker.pollOnce();
    expect(printer.calls, 1);
    expect(acks, 1);
    expect(worker.uncertainTicketIds, contains('original:12'));
  });

  test('confirmed failure ACK is not repeated for duplicate claim', () async {
    final printer = _FakePrinter()..result = StationPrintOutcome.definitelyFailed;
    var acks = 0;
    final worker = StationPrintWorker(
      session: StationDeviceSessionService(), printer: printer,
      claimTicket: () async => _claim(), resolveTicket: (_) async => _ticket(),
      ackTicket: ({required ticketId, required attempt, required result, error}) async {
        acks++;
      },
    );
    await worker.pollOnce();
    await worker.pollOnce();
    expect(printer.calls, 1);
    expect(acks, 1);
  });


  test('missing order identity cannot reach resolver or physical printer', () async {
    final printer = _FakePrinter();
    var resolved = 0;
    final worker = StationPrintWorker(
      session: StationDeviceSessionService(), printer: printer,
      claimTicket: () async => {..._claim()}..remove('order_id'),
      resolveTicket: (_) async { resolved++; return _ticket(); },
    );
    await worker.pollOnce();
    expect(resolved, 0);
    expect(printer.calls, 0);
    expect(worker.uncertainTicketIds, contains('original:12'));
  });

  test('noninteger order identity is rejected before resolution', () async {
    final printer = _FakePrinter();
    var resolved = 0;
    final worker = StationPrintWorker(
      session: StationDeviceSessionService(), printer: printer,
      claimTicket: () async => {..._claim(), 'order_id': '99'},
      resolveTicket: (_) async { resolved++; return _ticket(); },
    );
    await worker.pollOnce();
    expect(resolved, 0);
    expect(printer.calls, 0);
    expect(worker.uncertainTicketIds, contains('original:12'));
  });

  test('claimed order mismatch cannot print even when ticket id matches', () async {
    final printer = _FakePrinter();
    final worker = StationPrintWorker(
      session: StationDeviceSessionService(), printer: printer,
      claimTicket: () async => {..._claim(), 'order_id': 100},
      resolveTicket: (_) async => _ticket(),
    );
    await worker.pollOnce();
    expect(printer.calls, 0);
    expect(worker.uncertainTicketIds, contains('original:12'));
  });
}
