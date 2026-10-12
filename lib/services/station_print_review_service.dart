import 'package:supabase_flutter/supabase_flutter.dart';

/// Supervisor-only review. The database checks station assignment and lease.
/// This API never queues a second print automatically.
class StationPrintReviewService {
  StationPrintReviewService(this.client);
  final SupabaseClient client;

  Future<List<Map<String,dynamic>>> pendingReviews() async {
    final result = await client.rpc('gs_1237_list_uncertain_print_tickets');
    if (result is! List) throw StateError('Unexpected review response');
    return result.map((r)=>Map<String,dynamic>.from(r as Map)).toList();
  }

  Future<Map<String,dynamic>> submitReview({
    required String queueKind,
    required int ticketId,
    required int attempt,
    required bool physicallyConfirmedPrinted,
    required String explanation,
    required String uniqueRequestKey,
  }) async {
    if (!{'original', 'revision'}.contains(queueKind) || ticketId <= 0 ||
        attempt <= 0 || uniqueRequestKey.trim().isEmpty) {
      throw ArgumentError('Invalid print review identity');
    }
    if (explanation.trim().length < 10 || explanation.trim().length > 1000) {
      throw ArgumentError('Explain how the printer outcome was verified');
    }
    final result = await client.rpc('gs_1237_review_print_ticket',params:{
      'p_queue_kind':queueKind,
      'p_ticket_id':ticketId,
      'p_attempt':attempt,
      'p_decision':physicallyConfirmedPrinted
        ? 'confirmed_printed' : 'confirmed_not_printed',
      'p_explanation':explanation.trim(),
      'p_request_key':uniqueRequestKey,
    });
    return Map<String,dynamic>.from(result as Map);
  }
}
