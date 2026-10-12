import 'package:flutter/material.dart';
import 'guest_engagement_review_models.dart';

/// Local filtering of already-authorized records only. No client-side review
/// action is permitted: assignment/approval requires audited server RPCs.
class GuestEngagementReviewPanel extends StatefulWidget {
  const GuestEngagementReviewPanel({super.key, required this.feedback,
    required this.suggestions});
  final List<GuestFeedbackReview> feedback;
  final List<ProductSuggestionReview> suggestions;

  @override
  State<GuestEngagementReviewPanel> createState() =>
      _GuestEngagementReviewPanelState();
}

class _GuestEngagementReviewPanelState extends State<GuestEngagementReviewPanel> {
  String query = '';
  bool urgentOnly = false;
  bool unresolvedOnly = false;
  bool pendingSuggestionsOnly = false;
  bool unassignedOnly = false;

  void _showFeedback(GuestFeedbackReview item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Guest feedback', style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: 12),
          SelectableText('Record ID: ${item.id}'),
          Text('Status: ${item.status.name}'),
          Text('Priority: ${item.urgent ? 'Urgent' : 'Normal'}'),
          Text('Assignment: ${item.assignedEmployeeId == null ? 'Unassigned' : 'Assigned to employee'}'),
          if (item.resolutionNote != null && item.resolutionNote!.trim().isNotEmpty)
            Text('Resolution: ${item.resolutionNote}'),
          if (item.validateResolution() != null)
            Text(item.validateResolution()!, style: TextStyle(color: Theme.of(sheetContext).colorScheme.error)),
          const SizedBox(height: 16),
          const Text('Read-only: changes require authorized server-side approval.'),
        ]),
      )),
    );
  }

  void _showSuggestion(ProductSuggestionReview item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Product recommendation', style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: 12),
          SelectableText('Record ID: ${item.id}'),
          Text('Status: ${item.status.name}'),
          if (item.decisionReason != null && item.decisionReason!.trim().isNotEmpty)
            Text('Decision reason: ${item.decisionReason}'),
          if (item.validateDecision() != null)
            Text(item.validateDecision()!, style: TextStyle(color: Theme.of(sheetContext).colorScheme.error)),
          const SizedBox(height: 16),
          const Text('Read-only: approval and rejection require an audited server operation.'),
        ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final term = query.trim().toLowerCase();
    final feedback = widget.feedback.where((item) {
      if (urgentOnly && !item.urgent) return false;
      if (unassignedOnly && item.assignedEmployeeId != null) return false;
      if (unresolvedOnly && (item.status == GuestFeedbackStatus.resolved ||
          item.status == GuestFeedbackStatus.closed)) return false;
      return item.id.toLowerCase().contains(term) ||
          item.status.name.toLowerCase().contains(term);
    }).toList()
      ..sort((a, b) {
        if (a.urgent != b.urgent) return a.urgent ? -1 : 1;
        return a.id.compareTo(b.id);
      });
    final suggestions = widget.suggestions.where((item) {
      if (pendingSuggestionsOnly && item.status != ProductSuggestionStatus.pending) {
        return false;
      }
      return item.id.toLowerCase().contains(term) ||
          item.status.name.toLowerCase().contains(term);
    }).toList();

    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Guest & product reviews', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Chip(avatar: const Icon(Icons.priority_high, size: 18),
          label: Text('Urgent: ${widget.feedback.where((f) => f.urgent && f.status != GuestFeedbackStatus.closed && f.status != GuestFeedbackStatus.resolved).length}')),
        Chip(avatar: const Icon(Icons.assignment_late_outlined, size: 18),
          label: Text('Unassigned: ${widget.feedback.where((f) => f.assignedEmployeeId == null && f.status != GuestFeedbackStatus.closed && f.status != GuestFeedbackStatus.resolved).length}')),
        Chip(avatar: const Icon(Icons.pending_actions, size: 18),
          label: Text('Pending recommendations: ${widget.suggestions.where((r) => r.status == ProductSuggestionStatus.pending).length}')),
      ]),
      const SizedBox(height: 12),
      TextField(
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search),
          labelText: 'Search record ID or status', border: OutlineInputBorder()),
        onChanged: (value) => setState(() => query = value),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 4, children: [
        FilterChip(label: const Text('Urgent feedback'), selected: urgentOnly,
          onSelected: (v) => setState(() => urgentOnly = v)),
        FilterChip(label: const Text('Unassigned feedback'), selected: unassignedOnly,
          onSelected: (v) => setState(() => unassignedOnly = v)),
        FilterChip(label: const Text('Unresolved feedback'), selected: unresolvedOnly,
          onSelected: (v) => setState(() => unresolvedOnly = v)),
        FilterChip(label: const Text('Pending suggestions'),
          selected: pendingSuggestionsOnly,
          onSelected: (v) => setState(() => pendingSuggestionsOnly = v)),
      ]),
      const SizedBox(height: 16),
      Text('Guest feedback (${feedback.length})',
          style: Theme.of(context).textTheme.titleMedium),
      if (feedback.isEmpty) const ListTile(title: Text('No matching feedback')),
      for (final item in feedback)
        Card(child: ListTile(
          leading: Icon(item.urgent ? Icons.priority_high : Icons.rate_review_outlined),
          title: Text('Feedback ${item.id}'),
          onTap: () => _showFeedback(item),
          subtitle: Text('Status: ${item.status.name}${item.assignedEmployeeId == null ? '' : ' • Assigned'}${item.validateResolution() == null ? '' : ' • Missing resolution note'}'),
          trailing: const Icon(Icons.visibility_outlined),
        )),
      const SizedBox(height: 20),
      Text('Product recommendations (${suggestions.length})',
          style: Theme.of(context).textTheme.titleMedium),
      if (suggestions.isEmpty) const ListTile(title: Text('No matching recommendations')),
      for (final item in suggestions)
        Card(child: ListTile(
          leading: const Icon(Icons.lightbulb_outline),
          title: Text('Recommendation ${item.id}'),
          onTap: () => _showSuggestion(item),
          subtitle: Text('Status: ${item.status.name}${item.validateDecision() == null ? '' : ' • Missing rejection reason'}'),
          trailing: const Icon(Icons.visibility_outlined),
        )),
      const SizedBox(height: 12),
      const Text('Read-only. Server permissions, audit logging, and approval functions must be verified before review actions are enabled.'),
    ]);
  }
}
