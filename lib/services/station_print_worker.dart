import 'dart:async';
import 'station_device_session_service.dart';

/// A formatted, station-scoped ticket. The trusted resolver must validate
/// station ownership and supply immutable item snapshots, not mutable menu data.
class StationPrintTicket {
  const StationPrintTicket({required this.ticketId, required this.attempt,
    required this.station, required this.orderId, required this.items,
    this.tableLabel = '', this.kind = 'ORDER', this.note = ''});
  final int ticketId, attempt, orderId;
  final String station, tableLabel, kind, note;
  final List<StationPrintItem> items;
}
class StationPrintItem {
  const StationPrintItem({required this.product, required this.quantity,
    this.customerName, this.guestNumber, this.note = ''});
  final String product, note;
  final int quantity;
  final String? customerName;
  final int? guestNumber;
  String get customerLabel {
    final name = customerName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (guestNumber != null && guestNumber! > 0) return 'Guest $guestNumber';
    return 'Table Order';
  }
}

/// Human-readable receipt text, also suitable as input to a future ESC/POS
/// adapter. No amounts are recalculated or changed by printing.
class StationTicketFormatter {
  // Never allow product, guest or notes to inject extra printer commands,
  // forged totals, or additional lines into station output.
  static String _safe(String value) => value
      .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  static String format(StationPrintTicket ticket) {
    if (ticket.ticketId <= 0 || ticket.attempt <= 0 || ticket.orderId <= 0 ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(ticket.station) ||
        ticket.items.isEmpty) {
      throw ArgumentError('Invalid station ticket metadata');
    }
    final kind = ticket.kind.toUpperCase();
    final allowed = {'ORDER', 'CORRECTION', 'REPLACEMENT', 'CANCELLATION'};
    if (!allowed.contains(kind)) throw ArgumentError('Unsupported ticket kind');
    // Validate sizes before allocating or joining large, untrusted receipt text.
    if (ticket.items.length > 500) throw ArgumentError('Too many printable items');
    if (ticket.station.length > 128 || ticket.tableLabel.length > 128 ||
        ticket.note.length > 2048) {
      throw ArgumentError('Ticket metadata exceeds print limits');
    }
    final lines = <String>[
      'GELYE SHERANE CAFE & REST',
      '*** $kind ***',
      'Station: ${_safe(ticket.station)}',
      'Table: ${ticket.tableLabel.isEmpty ? 'N/A' : _safe(ticket.tableLabel)}',
      'Order #${ticket.orderId}  Ticket #${ticket.ticketId}',
      '--------------------------------',
    ];
    for (final item in ticket.items) {
      if (item.quantity <= 0 || item.quantity > 100000 ||
          item.product.length > 256 || item.note.length > 2048 ||
          (item.customerName?.length ?? 0) > 128 ||
          _safe(item.product).isEmpty) {
        throw ArgumentError('Invalid printable item');
      }
      lines.add('${item.quantity} x ${_safe(item.product)}');
      lines.add('  Customer: ${_safe(item.customerLabel)}');
      if (item.note.trim().isNotEmpty) lines.add('  Note: ${_safe(item.note)}');
    }
    if (ticket.note.trim().isNotEmpty) lines.add('Reason: ${_safe(ticket.note)}');
    lines.add('Attempt: ${ticket.attempt}');
    lines.add('Powered By Zanyar Sidqi');
    final output = lines.join('\n');
    if (output.length > 16000) throw StateError('Ticket exceeds print size limit');
    return output;
  }
}

enum StationPrintOutcome { printed, definitelyFailed, uncertain }

/// Device-specific implementation must provide reliable status or return
/// uncertain; a write to a socket is NOT evidence of paper printing.
abstract class StationPrinterAdapter {
  Future<StationPrintOutcome> print(String ticketText);
}

typedef StationTicketClaim = Future<Map<String,dynamic>?> Function();
typedef StationTicketAck = Future<void> Function({required int ticketId,
  required int attempt,required String result,String? error});

typedef StationTicketResolver = Future<StationPrintTicket> Function(
  Map<String, dynamic> claimedTicket);

/// Polls once per tick; do not run two workers for the same POS process.
/// Uncertain outcomes are held for operator review, never auto-reprinted.
class StationPrintWorker {
  StationPrintWorker({required this.session, required this.resolveTicket,
    required this.printer, this.onError,this.claimTicket,this.ackTicket,this.queueName = "original"});
  final StationDeviceSessionService session;
  final StationTicketResolver resolveTicket;
  final StationTicketClaim? claimTicket;
  final StationTicketAck? ackTicket;
  final String queueName;
  final StationPrinterAdapter printer;
  final void Function(Object error)? onError;
  bool _busy = false;
  bool _stopped = false;
  int _lifecycleEpoch = 0;
  Timer? _timer;
  final Set<String> _uncertain = <String>{};
  // A server retry of an already printed attempt must not produce another
  // physical ticket in this process, even when its ACK was lost.
  final Set<String> _printedAttempts = <String>{};
  Set<String> get uncertainTicketIds => Set.unmodifiable(_uncertain);

  // Error reporting must never cause an unhandled Future error in a timer tick.
  void _reportError(Object error) {
    try {
      onError?.call(error);
    } catch (_) {
      // The callback is diagnostic only; printing state remains authoritative.
    }
  }

  void start({Duration interval = const Duration(seconds: 5)}) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(queueName)) {
      throw ArgumentError('Print queue name must be 1-64 safe identifier characters');
    }
    if (interval <= Duration.zero) throw ArgumentError('Print interval must be positive');
    if (_timer != null) return;
    if (_busy) throw StateError('Cannot restart print worker while an earlier poll is active');
    _lifecycleEpoch++;
    _stopped = false;
    _timer = Timer.periodic(interval, (_) => unawaited(pollOnce()));
    unawaited(pollOnce());
  }

  Future<void> pollOnce() async {
    if (_busy || _stopped) return;
    // pollOnce is public and can be called without start(); enforce the
    // same queue identity contract before claiming any server-side work.
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(queueName)) {
      throw ArgumentError('Print queue name must be 1-64 safe identifier characters');
    }
    _busy = true;
    final pollEpoch = _lifecycleEpoch;
    String? claimedIdentity;
    try {
      final claim = await (claimTicket?.call() ?? session.claimPrintTicket());
      if (claim == null) return;
      final id = claim['ticket_id'];
      final attempt = claim['attempt'];
      // Capture a valid claim identity before validating the rest of the
      // payload. Malformed claimed tickets still require manual review.
      if (id is int && id > 0) claimedIdentity = '$queueName:$id';
      final stationKey = claim['station_key'];
      final orderId = claim['order_id'];
      if (id is! int || attempt is! int || id <= 0 || attempt <= 0 ||
          stationKey is! String ||
          !RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(stationKey) ||
          orderId is! int || orderId <= 0) {
        throw StateError('Invalid ticket claim');
      }
      final identity = '$queueName:$id';
      final attemptIdentity = '$identity:$attempt';
      if (_uncertain.contains(identity)) return;
      if (_printedAttempts.contains(attemptIdentity)) {
        _uncertain.add(identity);
        _reportError(StateError('Previously printed ticket $id was reclaimed; manual review required'));
        return;
      }
      // Shutdown can occur while the server claim is in flight. Do not
      // resolve or print a ticket after shutdown; keep it for manual review.
      if (_stopped || pollEpoch != _lifecycleEpoch) {
        _uncertain.add(identity);
        _reportError(StateError('Ticket $id claimed during shutdown; review required'));
        return;
      }
      // A missing or unverified payload is uncertain. Never invent items.
      final ticket = await resolveTicket(claim);
      if (ticket.ticketId != id || ticket.attempt != attempt ||
          ticket.orderId != orderId ||
          ticket.station != claim['station_key'] || ticket.items.isEmpty ||
          ticket.items.any((item) => item.quantity <= 0 || item.product.trim().isEmpty)) {
        throw StateError('Ticket payload did not match the claim');
      }
      // Stop may happen while the asynchronous claim/resolver is running.
      // Do not initiate a physical print after shutdown; hold for review.
      if (_stopped || pollEpoch != _lifecycleEpoch) {
        _uncertain.add(identity);
        _reportError(StateError('Ticket $id claimed while printer worker stopped; review required'));
        return;
      }
      final output = StationTicketFormatter.format(ticket);
      final result = await printer.print(output);
      // Preserve confirmed physical success even if logout occurred during
      // printing. A later restart must never replay this attempt.
      if (result == StationPrintOutcome.printed) {
        _printedAttempts.add(attemptIdentity);
      }
      // The device write may finish after stop(). Do not send an ACK from
      // a retired worker: the physical outcome must be reviewed manually.
      if (_stopped || pollEpoch != _lifecycleEpoch) {
        _uncertain.add(identity);
        _reportError(StateError('Ticket $id completed after worker shutdown; review required'));
        return;
      }
      if (result == StationPrintOutcome.uncertain) {
        _uncertain.add(identity);
        _reportError(StateError('Ticket $id requires manual print review'));
        return;
      }
      try {
        await (ackTicket ?? session.acknowledgePrintTicket)(ticketId: id, attempt: attempt,
          result: result == StationPrintOutcome.printed ? 'printed' : 'failed',
          error: result == StationPrintOutcome.definitelyFailed
            ? 'Printer confirmed failure' : null);
        // A confirmed failure must also not be replayed for the same attempt
        // without an explicit server-issued new attempt.
        _printedAttempts.add(attemptIdentity);
      } catch (e) {
        // A successful physical print followed by a lost acknowledgment
        // MUST NOT trigger a blind second print.
        _uncertain.add(identity);
        rethrow;
      }
    } catch (e) {
      // The claim already moved to UNKNOWN on the server. A resolver,
      // formatter, adapter or ACK exception must not trigger blind retry.
      if (claimedIdentity != null) _uncertain.add(claimedIdentity);
      _reportError(e);
    } finally {
      _busy = false;
    }
  }

  void stop() { _stopped = true; _lifecycleEpoch++; _timer?.cancel(); _timer = null; }
}
