import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'station_device_session_service.dart';
import 'station_print_worker.dart';

/// Resolver uses the authenticated station token, never an employee login.
class SecureStationTicketResolver {
  SecureStationTicketResolver(this.session);
  final StationDeviceSessionService session;

  Future<StationPrintTicket> resolveRevision(Map<String,dynamic> claim) =>
    _resolve(claim,'resolve_revision_print');

  Future<StationPrintTicket> resolve(Map<String, dynamic> claim) =>
    _resolve(claim,'resolve_print');

  Future<StationPrintTicket> _resolve(Map<String, dynamic> claim,String action) async {
    final ticketId = claim['ticket_id'];
    final attempt = claim['attempt'];
    if (ticketId is! int || ticketId <= 0 || attempt is! int || attempt <= 0 ||
        claim['order_id'] is! int || (claim['order_id'] as int) <= 0 ||
        claim['station_key'] is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(claim['station_key'] as String)) {
      throw StateError('Invalid ticket claim');
    }
    final token = await session.deviceTokenForStationRequest();
    final response = await Supabase.instance.client.functions.invoke(
      'station-device-auth', body: {
        'action':action,'token':token,
        'ticket_id':ticketId,'attempt':attempt,
      },
    );
    final raw = response.data;
    if (raw is! Map || raw['ticket'] is! Map) {
      throw StateError('No authorized immutable ticket snapshot');
    }
    final payload = Map<String, dynamic>.from(raw['ticket'] as Map);
    return parseSnapshot(claim, payload);
  }

  /// Pure parser: rejects malformed snapshots before the physical printer runs.
  /// Keeping this separate from network I/O permits deterministic Dart tests.
  static StationPrintTicket parseSnapshot(
      Map<String, dynamic> claim, Map<String, dynamic> payload) {
    final ticketId = claim['ticket_id'];
    final attempt = claim['attempt'];
    final orderId = claim['order_id'];
    final station = claim['station_key'];
    if (ticketId is! int || ticketId <= 0 || attempt is! int || attempt <= 0 ||
        orderId is! int || orderId <= 0 || station is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(station) ||
        payload['ticket_id'] != ticketId || payload['attempt'] != attempt ||
        payload['order_id'] != orderId || payload['station'] != station) {
      throw StateError('Station print payload mismatch');
    }
    final rows = payload['items'];
    if (rows is! List || rows.isEmpty || rows.length > 500) {
      throw StateError('Invalid immutable ticket items');
    }
    final items = <StationPrintItem>[];
    for (final entry in rows) {
      if (entry is! Map) throw StateError('Invalid ticket item');
      final item = Map<String, dynamic>.from(entry);
      final product = item['product'];
      final quantity = item['quantity'];
      final customerName = item['customer_name'];
      final guestNumber = item['guest_number'];
      final note = item['note'];
      if (product is! String || product.trim().isEmpty || product.length > 256 ||
          quantity is! int || quantity <= 0 || quantity > 100000 ||
          (customerName != null && (customerName is! String || customerName.length > 128)) ||
          (guestNumber != null && (guestNumber is! int || guestNumber <= 0)) ||
          (note != null && (note is! String || note.length > 2048))) {
        throw StateError('Invalid immutable ticket item fields');
      }
      items.add(StationPrintItem(
        product: product, quantity: quantity,
        customerName: customerName as String?,
        guestNumber: guestNumber as int?,
        note: (note as String?) ?? '',
      ));
    }
    final tableLabel = payload['table_label'];
    final kind = payload['kind'];
    final note = payload['note'];
    // Reject unsupported ticket kinds at the immutable snapshot boundary,
    // rather than waiting until the physical printing worker formats them.
    const supportedKinds = <String>{
      'ORDER', 'CORRECTION', 'REPLACEMENT', 'CANCELLATION',
    };
    if ((tableLabel != null && (tableLabel is! String || tableLabel.length > 128)) ||
        (kind != null && (kind is! String || !supportedKinds.contains(kind.toUpperCase()))) ||
        (note != null && (note is! String || note.length > 2048))) {
      throw StateError('Invalid immutable ticket metadata');
    }
    // Formatting is the final bound on the total printable text size.
    // Validate here too so all resolver callers receive a safe snapshot.
    final ticket = StationPrintTicket(
      ticketId: ticketId, attempt: attempt, station: station,
      orderId: orderId, items: List.unmodifiable(items),
      tableLabel: (tableLabel as String?) ?? '',
      kind: (kind as String?) ?? 'ORDER',
      note: (note as String?) ?? '',
    );
    try {
      StationTicketFormatter.format(ticket);
    } on ArgumentError catch (error) {
      throw StateError('Invalid printable snapshot: $error');
    } on StateError catch (error) {
      throw StateError('Invalid printable snapshot: $error');
    }
    return ticket;
  }
}

/// Hardware integrations must implement this interface. Until configured,
/// fail closed and never claim/print a ticket.
abstract class StationPrinterDriver {
  Future<StationPrintOutcome> printAndConfirm(String formattedTicket);
  Future<bool> get isConfigured;
}

class StationPrinterDriverAdapter implements StationPrinterAdapter {
  StationPrinterDriverAdapter(this.driver);
  final StationPrinterDriver driver;
  @override
  Future<StationPrintOutcome> print(String ticketText) =>
      driver.printAndConfirm(ticketText);
}

/// Serialize physical output across original and revision queues sharing one device.
/// A failed write must not block subsequent queued writes.
class SerializedStationPrinterAdapter implements StationPrinterAdapter {
  SerializedStationPrinterAdapter(this.driver);
  final StationPrinterDriver driver;
  Future<void> _tail = Future<void>.value();
  bool _closed = false;

  /// Retire this device queue on logout or session replacement. An active
  /// hardware write cannot be recalled, but queued writes must never start.
  void close() { _closed = true; }

  @override
  Future<StationPrintOutcome> print(String ticketText) {
    if (_closed) return Future.value(StationPrintOutcome.uncertain);
    final result = Completer<StationPrintOutcome>();
    final previous = _tail;
    _tail = () async {
      try {
        await previous;
      } catch (_) {
        // A previous print failure must not poison the queue.
      }
      if (_closed) {
        result.complete(StationPrintOutcome.uncertain);
        return;
      }
      try {
        result.complete(await driver.printAndConfirm(ticketText));
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    }();
    return result.future;
  }
}

/// Start only once a real driver is configured and a station session is active.
/// stop() on logout, disposal, or loss of printing permission.
class StationPrintLifecycle {
  StationPrintLifecycle(this.session, this.driver);
  final StationDeviceSessionService session;
  final StationPrinterDriver driver;
  StationPrintWorker? _worker;
  StationPrintWorker? _revisionWorker;
  SerializedStationPrinterAdapter? _sharedPrinter;
  bool _starting = false;
  int _startEpoch = 0;
  bool get running => _worker != null && _revisionWorker != null;

  Future<void> start({void Function(Object)? onError}) async {
    if (_worker != null || _starting) return;
    _starting = true;
    final epoch = ++_startEpoch;
    try {
      if (!await driver.isConfigured) {
        throw StateError('No configured station printer driver');
      }
      // A logout/stop during the asynchronous configuration check must not
      // resurrect a retired station printing session.
      if (epoch != _startEpoch) return;
      final resolver = SecureStationTicketResolver(session);
      final sharedPrinter = SerializedStationPrinterAdapter(driver);
      _sharedPrinter = sharedPrinter;
    final worker = StationPrintWorker(
      session:session,resolveTicket:resolver.resolve,
      printer:sharedPrinter,onError:onError,
    );
    final revisionWorker = StationPrintWorker(
      session:session,resolveTicket:resolver.resolveRevision,
      printer:sharedPrinter,onError:onError,
      queueName:'revision',
      claimTicket:session.claimRevisionPrintTicket,
      ackTicket:session.acknowledgeRevisionPrintTicket,
    );
    _worker=worker;
    _revisionWorker=revisionWorker;
    worker.start();
    revisionWorker.start();
    } catch (_) {
      stop();
      rethrow;
    } finally {
      _starting = false;
    }
  }
  void stop() {
    _startEpoch++;
    _sharedPrinter?.close();
    _sharedPrinter = null;
    _worker?.stop(); _revisionWorker?.stop();
    _worker=null; _revisionWorker=null;
  }
}
