/// Review-state models; no client-side approval is authorized by these models.
enum GuestFeedbackStatus { newRequest, assigned, inProgress, resolved, closed }
enum ProductSuggestionStatus { pending, approved, rejected }

class GuestFeedbackReview {
  const GuestFeedbackReview({required this.id, required this.status,
    required this.urgent, this.assignedEmployeeId, this.resolutionNote});
  final String id;
  final GuestFeedbackStatus status;
  final bool urgent;
  final String? assignedEmployeeId;
  final String? resolutionNote;

  String? validateResolution() {
    if (status == GuestFeedbackStatus.resolved &&
        (resolutionNote == null || resolutionNote!.trim().isEmpty)) {
      return 'A resolution note is required';
    }
    return null;
  }
}

class ProductSuggestionReview {
  const ProductSuggestionReview({required this.id, required this.status,
    this.decisionReason});
  final String id;
  final ProductSuggestionStatus status;
  final String? decisionReason;

  String? validateDecision() {
    if (status == ProductSuggestionStatus.rejected &&
        (decisionReason == null || decisionReason!.trim().isEmpty)) {
      return 'A rejection reason is required';
    }
    return null;
  }
}
