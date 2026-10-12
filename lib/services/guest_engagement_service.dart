import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/dashboard/guest_engagement_models.dart';

/// Writes through RLS-protected tables. Server policies decide authorization.
/// Guest-facing anonymous QR submissions need a separate rate-limited endpoint.
class GuestEngagementService {
  GuestEngagementService(this.client);
  final SupabaseClient client;

  Future<String> submitStaffRecordedFeedback(GuestFeedbackDraft draft) async {
    final error = draft.validate();
    if (error != null) throw ArgumentError(error);
    if (client.auth.currentUser == null) throw StateError('Sign in required');
    final rows = await client.from('gs_guest_feedback')
        .insert(draft.toPayload()).select('id').single();
    return rows['id'] as String;
  }

  Future<String> submitRecommendation(ProductRecommendationDraft draft) async {
    final error = draft.validate();
    if (error != null) throw ArgumentError(error);
    if (client.auth.currentUser == null) throw StateError('Sign in required');
    final rows = await client.from('gs_product_recommendations')
        .insert(draft.toPayload()).select('id').single();
    return rows['id'] as String;
  }
}
