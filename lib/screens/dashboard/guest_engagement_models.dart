/// Validated draft models for the Dashboard guest and staff suggestion forms.
/// These objects do not submit payments, publish products or bypass RLS.
class GuestFeedbackDraft {
  const GuestFeedbackDraft({required this.category, required this.message,
    this.name, this.contact, this.location, this.rating, this.urgent = false});
  final String category;
  final String message;
  final String? name, contact, location;
  final int? rating;
  final bool urgent;

  String? validate() {
    const categories = {'Concern', 'Service request', 'Suggestion', 'Complaint', 'Compliment'};
    if (!categories.contains(category)) return 'Invalid feedback category';
    if (message.trim().isEmpty || message.trim().length > 2000) {
      return 'Message must contain 1–2000 characters';
    }
    if (rating != null && (rating! < 1 || rating! > 5)) return 'Rating must be 1–5';
    if ((name?.length ?? 0) > 100 || (contact?.length ?? 0) > 100 ||
        (location?.length ?? 0) > 40) return 'Optional field exceeds its limit';
    return null;
  }

  Map<String, dynamic> toPayload() => {
    'category': category, 'message': message.trim(),
    'customer_name': name?.trim(), 'contact': contact?.trim(),
    'location_label': location?.trim(), 'rating': rating, 'urgent': urgent,
  };
}

class ProductRecommendationDraft {
  const ProductRecommendationDraft({required this.type, required this.productName,
    required this.reason});
  final String type, productName, reason;
  String? validate() {
    const types = {'Promote existing product', 'Suggest new product', 'Improve existing product'};
    if (!types.contains(type)) return 'Invalid recommendation type';
    if (productName.trim().isEmpty || productName.trim().length > 150) {
      return 'Product name must contain 1–150 characters';
    }
    if (reason.trim().isEmpty || reason.trim().length > 2000) {
      return 'Reason must contain 1–2000 characters';
    }
    return null;
  }
  Map<String, dynamic> toPayload() => {
    'type': type, 'product_name': productName.trim(), 'reason': reason.trim(),
  };
}
