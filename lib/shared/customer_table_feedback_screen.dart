import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Customer-facing feedback draft. No personal identity required.
/// Intentionally does NOT submit: a verified visit-scoped session, anti-spam
/// controls and a secure write RPC must be implemented first.
class CustomerTableFeedbackScreen extends StatefulWidget {
  const CustomerTableFeedbackScreen({super.key, required this.token, this.visitSessionToken, required this.products});
  final String token;
  final String? visitSessionToken;
  final List<Map<String, dynamic>> products;

  @override
  State<CustomerTableFeedbackScreen> createState() => _CustomerTableFeedbackScreenState();
}

class _CustomerTableFeedbackScreenState extends State<CustomerTableFeedbackScreen> {
  final _comment = TextEditingController();
  final _requestedProduct = TextEditingController();
  String _kind = 'survey';
  String? _productId;
  int _rating = 0;
  String? _validationMessage;
  bool _sending = false;
  bool _sent = false;

  bool get _isValidDraft {
    if (_kind == 'survey') return _rating >= 1 && _rating <= 5;
    if (_kind == 'rating') {
      return _rating >= 1 && _rating <= 5 &&
          _productId != null &&
          widget.products.any((p) => p['product_id'].toString() == _productId);
    }
    return _kind == 'new_product' ? _requestedProduct.text.trim().isNotEmpty : _comment.text.trim().isNotEmpty;
  }

  void _validateDraft() {
    setState(() {
      if (_isValidDraft) {
        _validationMessage =
            'Your feedback is ready, but secure submission is not yet enabled. '
            'Nothing has been sent.';
      } else if (_kind == 'rating') {
        _validationMessage = 'Choose a menu product and a rating from 1 to 5.';
      } else if (_kind == 'survey') {
        _validationMessage = 'Choose an experience rating from 1 to 5.';
      } else {
        _validationMessage = _kind == 'new_product'
            ? 'Enter the new product you would like us to add.'
            : 'Describe your recommendation or improvement.';
      }
    });
  }

  Future<void> _submit() async {
    if (_sending || _sent) return;
    if (!_isValidDraft) { _validateDraft(); return; }
    final session = widget.visitSessionToken;
    if (session == null || session.isEmpty || _kind == 'rating') {
      setState(() => _validationMessage = _kind == 'rating'
          ? 'Item ratings require product verification and are not available yet.'
          : 'Ask an employee to authorize this table visit before sending feedback.');
      return;
    }
    setState(() { _sending = true; _validationMessage = null; });
    try {
      await Supabase.instance.client.rpc('gs_customer_submit_visit_feedback', params: {
        'p_session_token': session,
        'p_kind': _kind,
        'p_rating': _kind == 'survey' ? _rating : null,
        'p_comment': _comment.text.trim(),
        'p_requested_product': _kind == 'new_product' ? _requestedProduct.text.trim() : null,
      });
      if (mounted) setState(() { _sent = true; _validationMessage = 'Feedback submitted successfully.'; });
    } catch (_) {
      if (mounted) setState(() => _validationMessage =
          'Could not submit. Your visit may have expired or reached the feedback limit. Please ask an employee.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    _requestedProduct.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback & Suggestions')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Help us improve your experience. No customer name is required.'),
        const Text('Choose Survey, Rate Item, Suggest, or New Product. Each type is tracked separately.'),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'survey', label: Text('Survey')),
            ButtonSegment(value: 'rating', label: Text('Rate Item')),
            ButtonSegment(value: 'suggestion', label: Text('Suggest')),
            ButtonSegment(value: 'new_product', label: Text('New Product')),
          ],
          selected: {_kind},
          onSelectionChanged: (value) => setState(() {
            _kind = value.first;
            _rating = 0;
            _productId = null;
            _validationMessage = null;
          }),
        ),
        const SizedBox(height: 16),
        if (_kind == 'rating') ...[
          DropdownButtonFormField<String>(
            value: _productId,
            decoration: const InputDecoration(labelText: 'Menu product', border: OutlineInputBorder()),
            items: widget.products.map((item) => DropdownMenuItem<String>(
              value: item['product_id'].toString(),
              child: Text(item['product_name']?.toString() ?? 'Product'),
            )).toList(),
            onChanged: (value) => setState(() { _productId = value; _validationMessage = null; }),
          ),
          const SizedBox(height: 12),
        ],
        if (_kind == 'survey' || _kind == 'rating') ...[
          Text(_kind == 'survey' ? 'How was your experience?' : 'Rate this product'),
          Wrap(children: [for (var i = 1; i <= 5; i++) IconButton(
            tooltip: '$i stars',
            icon: Icon(i <= _rating ? Icons.star : Icons.star_border),
            onPressed: () => setState(() { _rating = i; _validationMessage = null; }),
          )]),
        ],
        if (_kind == 'new_product') ...[
          TextField(
            controller: _requestedProduct,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Name of requested new menu product',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _comment,
          maxLength: 1000,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: _kind == 'suggestion' ? 'Your recommendation (required)' : 'Your comments (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Feedback requires a staff-authorized current table visit. Item ratings remain unavailable until product verification is added.'),
        const SizedBox(height: 8),
        if (_validationMessage != null)
          Text(_validationMessage!, style: TextStyle(
            color: _sent ? Colors.green : Theme.of(context).colorScheme.onSurface,
          )),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _sending || _sent ? null : _submit,
          child: Text(_sent ? 'Submitted' : _sending ? 'Submitting…' : 'Send feedback'),
        ),
      ]),
    );
  }
}
