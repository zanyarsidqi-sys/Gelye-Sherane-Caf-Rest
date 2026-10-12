import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_cafe_rest/services/secure_station_ticket_resolver.dart';
import 'package:gelye_cafe_rest/services/station_print_worker.dart';

class _Driver implements StationPrinterDriver {
  final first = Completer<StationPrintOutcome>();
  final calls = <String>[];
  bool failFirst = false;
  @override
  Future<bool> get isConfigured async => true;
  @override
  Future<StationPrintOutcome> printAndConfirm(String text) async {
    calls.add(text);
    if (calls.length == 1) return first.future;
    return StationPrintOutcome.printed;
  }
}

void main() {
  test('shared printer serializes original and revision jobs', () async {
    final driver = _Driver();
    final adapter = SerializedStationPrinterAdapter(driver);
    final a = adapter.print('original');
    final b = adapter.print('revision');
    await Future<void>.delayed(Duration.zero);
    expect(driver.calls, ['original']);
    driver.first.complete(StationPrintOutcome.printed);
    expect(await a, StationPrintOutcome.printed);
    expect(await b, StationPrintOutcome.printed);
    expect(driver.calls, ['original', 'revision']);
  });

  test('closing queue prevents queued second physical print', () async {
    final driver = _Driver();
    final adapter = SerializedStationPrinterAdapter(driver);
    final first = adapter.print('original');
    final second = adapter.print('revision');
    await Future<void>.delayed(Duration.zero);
    expect(driver.calls, ['original']);
    adapter.close();
    driver.first.complete(StationPrintOutcome.printed);
    expect(await first, StationPrintOutcome.printed);
    expect(await second, StationPrintOutcome.uncertain);
    expect(driver.calls, ['original']);
  });

  test('closed queue refuses new physical print requests', () async {
    final driver = _Driver();
    final adapter = SerializedStationPrinterAdapter(driver);
    adapter.close();
    expect(await adapter.print('after logout'), StationPrintOutcome.uncertain);
    expect(driver.calls, isEmpty);
  });

  test('failed physical print does not block next queued print', () async {
    final driver = _Driver();
    final adapter = SerializedStationPrinterAdapter(driver);
    final a = adapter.print('first');
    final b = adapter.print('second');
    driver.first.completeError(StateError('printer offline'));
    await expectLater(a, throwsStateError);
    expect(await b, StationPrintOutcome.printed);
    expect(driver.calls, ['first', 'second']);
  });
}
