import 'station_device_session_service.dart';
import 'secure_station_ticket_resolver.dart';
import 'station_print_worker.dart';

/// Separate workers/queues; a revision ID cannot collide with an original ID.
/// No automatic retry of unknown outcomes; operator must inspect physical output.
class StationRevisionPrintLifecycle {
  StationRevisionPrintLifecycle(this.session,this.printer);
  final StationDeviceSessionService session;
  final StationPrinterAdapter printer;
  StationPrintWorker? _worker;

  void start({void Function(Object)? onError}) {
    if (_worker!=null) return;
    final resolver=SecureStationTicketResolver(session);
    final worker=StationPrintWorker(
      session:session,printer:printer,queueName:'revision',
      claimTicket:session.claimRevisionPrintTicket,
      ackTicket:session.acknowledgeRevisionPrintTicket,
      resolveTicket:resolver.resolveRevision,onError:onError);
    _worker=worker;
    worker.start();
  }
  void stop() { _worker?.stop(); _worker=null; }
}
