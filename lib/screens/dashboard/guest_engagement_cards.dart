import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/guest_engagement_service.dart';
import 'guest_engagement_models.dart';
import 'package:flutter/material.dart';

/// UI-only dashboard entry points. Counts and submission are intentionally not
/// simulated: secure persistence and role checks require backend integration.
class GuestEngagementCards extends StatelessWidget {
  const GuestEngagementCards({super.key, required this.onOpen});
  final void Function(GuestEngagementType type) onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Guest experience & employee suggestions',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 12, children: [
        _card(context, 'Guest Survey & Requests',
            'Concerns, service requests and suggestions',
            Icons.rate_review_outlined, GuestEngagementType.guestFeedback),
        _card(context, 'Product Recommendations',
            'Employee proposals for menu products',
            Icons.lightbulb_outline, GuestEngagementType.productRecommendation),
      ]),
    ],
  );

  Widget _card(BuildContext context, String title, String subtitle,
      IconData icon, GuestEngagementType type) => SizedBox(
    width: 320,
    child: Card(clipBehavior: Clip.antiAlias, child: InkWell(
      onTap: () => onOpen(type),
      child: Padding(padding: const EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 30),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(subtitle),
          const SizedBox(height: 8),
          const Text('Open details →'),
        ],
      )),
    )),
  );
}

enum GuestEngagementType { guestFeedback, productRecommendation }

class GuestEngagementDetails extends StatefulWidget {
  const GuestEngagementDetails({super.key, required this.type});
  final GuestEngagementType type;
  @override
  State<GuestEngagementDetails> createState() => _GuestEngagementDetailsState();
}

class _GuestEngagementDetailsState extends State<GuestEngagementDetails> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _product = TextEditingController();
  final _table = TextEditingController();
  final _contact = TextEditingController();
  // Enable only after migration, RLS, and permissions are verified on PC.
  static const _submissionEnabled = bool.fromEnvironment(
    'GS_GUEST_ENGAGEMENT_SUBMISSIONS', defaultValue: false);
  bool _submitting = false;
  bool _urgent = false;
  int _rating = 0;
  String _category = 'Concern';
  String _recommendation = 'Promote existing product';
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _product.dispose();
    _table.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_submissionEnabled || !_form.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final service = GuestEngagementService(Supabase.instance.client);
      if (widget.type == GuestEngagementType.guestFeedback) {
        await service.submitStaffRecordedFeedback(GuestFeedbackDraft(
          category: _category, message: _description.text,
          name: _name.text, contact: _contact.text,
          location: _table.text, rating: _rating == 0 ? null : _rating,
          urgent: _urgent));
      } else {
        await service.submitRecommendation(ProductRecommendationDraft(
          type: _recommendation, productName: _product.text,
          reason: _description.text));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submission received.')));
      Navigator.of(context).maybePop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:
        Text('Submission could not be saved. Please try again or contact a manager.')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final guest = widget.type == GuestEngagementType.guestFeedback;
    return Scaffold(
      appBar: AppBar(title: Text(guest ? 'Guest Survey & Requests' : 'Product Recommendations')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Card(child: Padding(padding: EdgeInsets.all(14), child: Text(
          'Submission remains disabled until the database migration, permissions and review workflow are verified. Draft validation is available.'))),
        const SizedBox(height: 16),
        Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (guest) ...[
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Feedback type'),
              items: ['Concern', 'Service request', 'Suggestion', 'Complaint', 'Compliment']
                  .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            TextFormField(controller: _name, maxLength: 100, decoration: const InputDecoration(
              labelText: 'Customer name (optional)')),
            TextFormField(controller: _table, maxLength: 40, decoration: const InputDecoration(
              labelText: 'Table or motel room (optional)')),
            TextFormField(controller: _contact, maxLength: 100, decoration: const InputDecoration(
              labelText: 'Contact information (optional)')),
            SwitchListTile(title: const Text('Urgent service request'),
              subtitle: const Text('For staff attention; not an emergency service'),
              value: _urgent, onChanged: (v) => setState(() => _urgent = v)),
            const Text('Guest rating (optional)'),
            Wrap(children: List.generate(5, (index) => IconButton(
              tooltip: '${index + 1} stars',
              icon: Icon(index < _rating ? Icons.star : Icons.star_border),
              onPressed: () => setState(() => _rating = index + 1)))),
          ] else ...[
            DropdownButtonFormField<String>(
              value: _recommendation,
              decoration: const InputDecoration(labelText: 'Recommendation type'),
              items: ['Promote existing product', 'Suggest new product', 'Improve existing product']
                  .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => _recommendation = v ?? _recommendation),
            ),
            TextFormField(controller: _product, maxLength: 160,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Product name is required' : null,
              decoration: const InputDecoration(labelText: 'Product name')),
          ],
          TextFormField(controller: _description, maxLines: 4, maxLength: 2000,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Please enter details' : null,
              decoration: InputDecoration(labelText: guest ? 'Concern or request' : 'Recommendation and reason')),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              if (_form.currentState!.validate()) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(
                  'Draft validated. Saving is unavailable until secure backend integration.')));
              }
            },
            child: const Text('Validate draft'),
          ),
          FilledButton(onPressed: _submissionEnabled && !_submitting ? _submit : null,
            child: Text(_submitting ? 'Submitting…' : 'Submit (requires verified backend)')),
        ])),
      ]),
    );
  }
}
