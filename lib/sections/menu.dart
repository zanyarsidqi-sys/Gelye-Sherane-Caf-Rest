import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/employee_permission_service.dart';
import '../services/menu_management_service.dart';
import '../shared/section_shell.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => SectionShell(
        title: 'Menu',
        description: 'Approved products, pricing and availability',
        sectionId: 'menu',
        compact: compact,
        authorizedContent: _MenuWorkspace(),
      );
}

class _MenuWorkspace extends StatefulWidget {
  const _MenuWorkspace();
  @override
  State<_MenuWorkspace> createState() => _MenuWorkspaceState();
}

class _MenuWorkspaceState extends State<_MenuWorkspace> {
  final MenuManagementService _service = MenuManagementService();
  late Future<void> _loading;
  List<MenuProduct> _products = [];
  List<MenuCategorySummary> _categories = [];
  List<MenuPreparationStation> _stations = [];
  List<MenuRevision> _pending = [];
  String _query = '';
  String _category = 'All items';
  String _status = 'all';
  int _page = 0;
  bool _busy = false;
  bool _isOwner = false;
  bool _canCreate = false;
  bool _canEdit = false;
  Object? _loadError;
  DateTime? _lastConfirmedAt;
  String? _lastRevisionFingerprint;
  String? _lastRevisionRequestId;
  static const int _pageSize = 24;

  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  Future<void> _load() async {
    try {
      final permissionService = EmployeePermissionService();
      final profile = await permissionService.getActiveEmployee();
      final permissions = await permissionService.getSectionPermissions();
      final menuPermission = permissions['menu'];
      final isOwner = '${profile?['role'] ?? ''}'.trim().toLowerCase() == 'owner';
      final results = await Future.wait<Object>([
        _service.loadProducts(),
        _service.loadCategories(),
        _service.loadStations(),
        if (isOwner && menuPermission?.canEdit == true)
          _service.loadPendingRevisions()
        else
          Future.value(<MenuRevision>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _isOwner = isOwner;
        _canCreate = menuPermission?.canCreate == true;
        _canEdit = menuPermission?.canEdit == true;
        _products = results[0] as List<MenuProduct>;
        _categories = results[1] as List<MenuCategorySummary>;
        _stations = results[2] as List<MenuPreparationStation>;
        _pending = results[3] as List<MenuRevision>;
        _lastConfirmedAt = DateTime.now();
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
      rethrow;
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loadError = null;
      _loading = _load();
    });
    try {
      await _loading;
    } catch (_) {}
  }

  Future<void> _availability(MenuProduct product, bool active) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(active ? 'Put ${product.name} on the menu?' : 'Mark ${product.name} out of stock?'),
        content: Text(active
            ? 'New orders will be able to select this product after the server confirms.'
            : 'New orders will stop offering this product. Existing orders, recipes and stock records will not change.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(active ? 'Make available' : 'Mark unavailable')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final version = await _service.setProductAvailability(
        product: product,
        isActive: active,
        requestId: MenuManagementService.newRequestId(),
      );
      if (!mounted) return;
      setState(() {
        _products = _products.map((item) => item.id == product.id
            ? _copyProduct(item, isActive: active, version: version)
            : item).toList();
      });
      _notice('Availability updated and recorded.');
    } catch (error) {
      if (!mounted) return;
      _notice(_actionableError(error, action: 'Availability was not changed.'));
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEditor({MenuProduct? product}) async {
    if (product == null && !_canCreate || product != null && !_canEdit) {
      _notice('Your Menu permissions do not allow this change.');
      return;
    }
    final saved = await showDialog<MenuProductDraft>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ProductRevisionDialog(
        service: _service,
        stations: _stations,
        categories: _categories.map((e) => e.name).toList(),
        product: product,
      ),
    );
    if (saved == null) return;
    await _submitDraft(saved, product);
  }

  Future<void> _submitDraft(MenuProductDraft draft, MenuProduct? product) async {
    final fingerprint = jsonEncode(<String, dynamic>{
      'product_id': product?.id,
      'expected_version': product?.version,
      'payload': draft.toJson(),
    });
    if (_lastRevisionFingerprint != fingerprint || _lastRevisionRequestId == null) {
      _lastRevisionFingerprint = fingerprint;
      _lastRevisionRequestId = MenuManagementService.newRequestId();
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final revisionId = await _service.submitProductRevision(
        draft: draft,
        idempotencyKey: _lastRevisionRequestId!,
        productId: product?.id,
        expectedVersion: product?.version,
      );
      if (!mounted) return;
      _lastRevisionFingerprint = null;
      _lastRevisionRequestId = null;
      _notice('Revision submitted for owner review · ${_shortId(revisionId)}');
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      final detail = error.toString().toLowerCase();
      if (detail.contains('version') ||
          detail.contains('stale') ||
          detail.contains('conflict')) {
        _lastRevisionFingerprint = null;
        _lastRevisionRequestId = null;
        await _refresh();
        if (mounted) {
          _notice('The latest menu is loaded. Reopen this product and submit against its current version.');
        }
      } else if (detail.contains('duplicate') ||
          detail.contains('unique') ||
          detail.contains('barcode')) {
        _notice('That barcode is already in use. Change it before submitting.');
      } else if (detail.contains('permission') ||
          detail.contains('denied') ||
          detail.contains('401') ||
          detail.contains('403')) {
        _notice(_actionableError(error, action: 'Revision was not submitted.'));
      } else {
        _notice(
          _actionableError(error, action: 'Revision was not confirmed.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _submitDraft(draft, product),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(MenuRevision revision, String decision) async {
    final note = TextEditingController();
    String? noteError;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(decision == 'approve' ? 'Approve revision?' : 'Reject revision?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Revision ${_shortId(revision.id)} · base version ${revision.baseVersion ?? 'new product'}'),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLength: 300,
                maxLines: 2,
                onChanged: (_) => setDialogState(() => noteError = null),
                decoration: InputDecoration(
                  labelText: decision == 'reject' ? 'Rejection reason' : 'Review note (optional)',
                  errorText: noteError,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              const Text('Approval publishes the submitted product content. Availability remains a separate audited control.'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (decision == 'reject' && note.text.trim().isEmpty) {
                  setDialogState(() => noteError = 'A reason is required to reject a revision.');
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: Text(decision == 'approve' ? 'Approve' : 'Reject'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      note.dispose();
      return;
    }
    if (!mounted) {
      note.dispose();
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await _service.reviewProductRevision(
        revisionId: revision.id,
        decision: decision,
        expectedVersion: revision.baseVersion,
        note: note.text.trim().isEmpty ? null : note.text.trim(),
      );
      if (!mounted) return;
      final status = '${result['status'] ?? ''}';
      if (status == 'conflict') {
        _notice('This revision is stale. The live product was not changed; refresh and submit it again.');
      } else if (status == 'approved') {
        _notice('Revision approved and published to the menu.');
      } else if (status == 'rejected') {
        _notice('Revision rejected.');
      } else {
        _notice('The server returned an unrecognized review result. Refresh before taking another action.');
      }
      await _refresh();
    } catch (error) {
      if (mounted) {
        _notice(_actionableError(error, action: 'Review was not confirmed.'));
        await _refresh();
      }
    } finally {
      note.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), action: action));
  }

  @override
  Widget build(BuildContext context) {
    final matching = _products.where((product) {
      final matchesQuery = '${product.name} ${product.barcode} ${product.description}'
          .toLowerCase().contains(_query.trim().toLowerCase());
      final matchesCategory =
          _category == 'All items' || product.category == _category;
      final matchesStatus = _status == 'all' ||
          (_status == 'available' ? product.isActive : !product.isActive);
      return matchesQuery && matchesCategory && matchesStatus;
    }).toList();
    final pageCount = matching.isEmpty ? 0 : (matching.length / _pageSize).ceil();
    final currentPage =
        pageCount == 0 ? 0 : _page.clamp(0, pageCount - 1).toInt();
    final shown = matching.skip(currentPage * _pageSize).take(_pageSize).toList();
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 660;
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.fromLTRB(narrow ? 14 : 28, 18, narrow ? 14 : 28, 40),
          children: [
            _MenuMasthead(
              count: _products.length,
              active: _products.where((e) => e.isActive).length,
              pending: _pending.length,
              lastConfirmedAt: _lastConfirmedAt,
              onRefresh: _busy ? null : _refresh,
              canAdd: _canCreate,
              onAdd: _busy || !_canCreate ? null : () => _openEditor(),
            ),
            if (_isOwner && _pending.isNotEmpty) ...[
              const SizedBox(height: 20),
              _ReviewQueue(revisions: _pending, products: _products, onReview: _review, busy: _busy),
            ],
            const SizedBox(height: 18),
            _MenuTools(
              query: _query,
              category: _category,
              status: _status,
              categories: _categories,
              onQuery: (value) => setState(() { _query = value; _page = 0; }),
              onCategory: (value) => setState(() { _category = value; _page = 0; }),
              onStatus: (value) => setState(() { _status = value; _page = 0; }),
            ),
            const SizedBox(height: 14),
            if (_loadError != null)
              _StatusPanel(
                icon: Icons.cloud_off_outlined,
                title: 'Menu could not be loaded',
                body: _actionableError(_loadError!, action: 'Check the connection and your menu access, then retry.'),
                actionLabel: 'Retry',
                onAction: _refresh,
              )
            else
              FutureBuilder<void>(
                future: _loading,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done && _products.isEmpty) {
                    return const _MenuSkeleton();
                  }
                  if (shown.isEmpty) {
                    return _StatusPanel(
                      icon: _products.isEmpty ? Icons.restaurant_menu_outlined : Icons.search_off,
                      title: _products.isEmpty ? 'Your approved menu is quiet' : 'No matches found',
                      body: _products.isEmpty
                          ? 'Approved products will appear here. Create a product revision to begin; it stays out of the live menu until an owner approves it.'
                          : 'Try another name, barcode or category.',
                      actionLabel: _products.isEmpty && _canCreate
                          ? 'Add product revision'
                          : _products.isEmpty ? null : 'Clear filters',
                      onAction: _products.isEmpty && _canCreate
                          ? () => _openEditor()
                          : _products.isEmpty
                              ? null
                              : () => setState(() {
                                    _query = '';
                                    _category = 'All items';
                                    _status = 'all';
                                    _page = 0;
                                  }),
                    );
                  }
                  final width = constraints.maxWidth;
                  final columns = width >= 1100 ? 4 : width >= 790 ? 3 : width >= 520 ? 2 : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: shown.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: narrow ? 248 : 274,
                    ),
                    itemBuilder: (context, index) => _ProductCard(
                      product: shown[index],
                      service: _service,
                      busy: _busy,
                      canEdit: _canEdit,
                      onEdit: _canEdit ? () => _openEditor(product: shown[index]) : null,
                      onAvailability: _canEdit
                          ? (active) => _availability(shown[index], active)
                          : null,
                      onHistory: () => _showHistory(shown[index]),
                    ),
                  );
                },
              ),
            if (pageCount > 1) ...[
              const SizedBox(height: 14),
              _MenuPagination(
                page: currentPage,
                pageCount: pageCount,
                total: matching.length,
                onPage: (value) => setState(() => _page = value),
              ),
            ],
            const SizedBox(height: 20),
            const _GuardrailNote(),
          ],
        ),
      );
    });
  }

  Future<void> _showHistory(MenuProduct product) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _ProductHistoryDialog(service: _service, product: product),
    );
  }
}

class _MenuMasthead extends StatelessWidget {
  const _MenuMasthead({
    required this.count,
    required this.active,
    required this.pending,
    required this.lastConfirmedAt,
    required this.canAdd,
    required this.onRefresh,
    required this.onAdd,
  });
  final int count;
  final int active;
  final int pending;
  final DateTime? lastConfirmedAt;
  final bool canAdd;
  final VoidCallback? onRefresh;
  final VoidCallback? onAdd;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF102C44),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF28445A)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 48, width: 48,
            decoration: BoxDecoration(color: const Color(0xFFD9A744).withValues(alpha: .16), borderRadius: BorderRadius.circular(15)),
            child: const Icon(Icons.restaurant_menu_rounded, color: Color(0xFFF1CD7B)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Menu management', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -.4)),
            const SizedBox(height: 4),
            Text('The approved catalog for service. Product edits are reviewed before they go live.', style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFC6D2DC))),
          ])),
          IconButton(onPressed: onRefresh, tooltip: 'Refresh menu', icon: const Icon(Icons.refresh, color: Colors.white)),
        ]),
        const SizedBox(height: 19),
        Wrap(spacing: 9, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _MetricTag(icon: Icons.inventory_2_outlined, label: '$count products'),
          _MetricTag(icon: Icons.check_circle_outline, label: '$active available', tint: const Color(0xFF92D5AE)),
          if (pending > 0) _MetricTag(icon: Icons.pending_actions, label: '$pending awaiting review', tint: const Color(0xFFF1CD7B)),
          if (lastConfirmedAt != null)
            _MetricTag(
              icon: Icons.cloud_done_outlined,
              label: 'Verified ${_timeLabel(lastConfirmedAt!)}',
              tint: const Color(0xFFB7E3C5),
            ),
          const SizedBox(width: 4),
          if (canAdd)
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 19),
              label: const Text('New revision'),
            ),
        ]),
      ]),
    );
  }
}

class _MetricTag extends StatelessWidget {
  const _MetricTag({required this.icon, required this.label, this.tint = const Color(0xFFE6EDF2)});
  final IconData icon;
  final String label;
  final Color tint;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .07), borderRadius: BorderRadius.circular(11)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: tint), const SizedBox(width: 7),
      Text(label, style: TextStyle(color: tint, fontSize: 12, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _MenuTools extends StatelessWidget {
  const _MenuTools({
    required this.query,
    required this.category,
    required this.status,
    required this.categories,
    required this.onQuery,
    required this.onCategory,
    required this.onStatus,
  });
  final String query;
  final String category;
  final String status;
  final List<MenuCategorySummary> categories;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onStatus;
  @override
  Widget build(BuildContext context) {
    final options = ['All items', ...categories.map((e) => e.name).where((e) => e.isNotEmpty)];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        onChanged: onQuery,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded),
          hintText: 'Search name, description or barcode',
          suffixIcon: query.isEmpty ? null : IconButton(onPressed: () => onQuery(''), icon: const Icon(Icons.close), tooltip: 'Clear search'),
        ),
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final value in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(value == 'All items' ? 'All items' : '$value  ·  ${categories.firstWhere((e) => e.name == value).productCount}'),
                selected: category == value,
                onSelected: (_) => onCategory(value),
                showCheckmark: false,
              ),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        children: [
          for (final item in const <(String, String)>[
            ('all', 'All statuses'),
            ('available', 'On menu'),
            ('unavailable', 'Out of menu'),
          ])
            ChoiceChip(
              label: Text(item.$2),
              selected: status == item.$1,
              onSelected: (_) => onStatus(item.$1),
              showCheckmark: false,
            ),
        ],
      ),
    ]);
  }
}

class _MenuPagination extends StatelessWidget {
  const _MenuPagination({
    required this.page,
    required this.pageCount,
    required this.total,
    required this.onPage,
  });

  final int page;
  final int pageCount;
  final int total;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              '$total products · Page ${page + 1} of $pageCount',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            tooltip: 'Previous page',
            onPressed: page == 0 ? null : () => onPage(page - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: page + 1 >= pageCount ? null : () => onPage(page + 1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.service,
    required this.busy,
    required this.canEdit,
    required this.onEdit,
    required this.onAvailability,
    required this.onHistory,
  });
  final MenuProduct product;
  final MenuManagementService service;
  final bool busy;
  final bool canEdit;
  final VoidCallback? onEdit;
  final ValueChanged<bool>? onAvailability;
  final VoidCallback onHistory;
  @override
  Widget build(BuildContext context) {
    final image = service.publicImageUrl(product.imagePath);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            if (image != null)
              Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const _ImageFallback())
            else
              const _ImageFallback(),
            Positioned(
              top: 10, left: 10,
              child: _AvailabilityPill(active: product.isActive),
            ),
            Positioned(
              top: 5, right: 5,
              child: PopupMenuButton<String>(
                tooltip: 'Product actions',
                onSelected: (choice) {
                  if (choice == 'edit') onEdit?.call();
                  if (choice == 'history') onHistory();
                },
                itemBuilder: (_) => [
                  if (canEdit)
                    const PopupMenuItem(value: 'edit', child: Text('Submit product revision')),
                  const PopupMenuItem(value: 'history', child: Text('View product history')),
                ],
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 3),
            Text('${product.category}  ·  ${product.barcode}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 5),
            Text(
              'Normal ${_formatIqd(product.normalPriceIqd)} · Tourism ${_formatIqd(product.tourismPriceIqd)}'
              '${product.ownerPriceIqd == null ? '' : ' · Owner ${_formatIqd(product.ownerPriceIqd!)}'} IQD',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 9),
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: busy || onAvailability == null
                      ? null
                      : () => onAvailability!(!product.isActive),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                    decoration: BoxDecoration(
                      color: product.isActive ? const Color(0xFFE8F4EC) : const Color(0xFFF8ECE8),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(product.isActive ? Icons.toggle_on : Icons.toggle_off, size: 17, color: product.isActive ? const Color(0xFF39784E) : const Color(0xFF99564B)),
                      const SizedBox(width: 4),
                      Flexible(child: Text(product.isActive ? 'Available' : 'Out of menu', maxLines: 1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: product.isActive ? const Color(0xFF39784E) : const Color(0xFF99564B)))),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              if (canEdit)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Submit a product revision',
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 19),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFE9E3D7),
    child: const Center(child: Icon(Icons.restaurant_rounded, size: 38, color: Color(0xFF9A8660))),
  );
}

class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(color: active ? const Color(0xFF39784E) : const Color(0xFF8C5148), borderRadius: BorderRadius.circular(20)),
    child: Text(active ? 'ON MENU' : 'OUT OF MENU', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .5)),
  );
}

class _ReviewQueue extends StatelessWidget {
  const _ReviewQueue({required this.revisions, required this.products, required this.onReview, required this.busy});
  final List<MenuRevision> revisions;
  final List<MenuProduct> products;
  final Future<void> Function(MenuRevision, String) onReview;
  final bool busy;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: const Color(0xFFFFF8E8), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFEBD6A5))),
    child: ExpansionTile(
      initiallyExpanded: true,
      leading: const Icon(Icons.rule_folder_outlined, color: Color(0xFF725416)),
      title: Text('Owner review · ${revisions.length} pending', style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: const Text('Only an owner can approve or reject.'),
      children: [
        for (final revision in revisions)
          Builder(builder: (context) {
            MenuProduct? product;
            for (final candidate in products) {
              if (candidate.id == revision.productId) {
                product = candidate;
                break;
              }
            }
            final payload = revision.payload;
            return ListTile(
              title: Text('${payload['name'] ?? product?.name ?? 'New product'}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${product == null ? 'New product' : 'Product #${product.id}'} · ${payload['category'] ?? 'Uncategorized'} · ${revision.createdAt?.toLocal().toString().substring(0, 16) ?? 'Recently submitted'}'),
              trailing: Wrap(spacing: 3, children: [
                IconButton(tooltip: 'Reject revision', onPressed: busy ? null : () => onReview(revision, 'reject'), icon: const Icon(Icons.close, color: Color(0xFF9B5148))),
                IconButton(tooltip: 'Approve revision', onPressed: busy ? null : () => onReview(revision, 'approve'), icon: const Icon(Icons.check_circle_outline, color: Color(0xFF39784E))),
              ]),
            );
          }),
      ],
    ),
  );
}

class _ProductRevisionDialog extends StatefulWidget {
  const _ProductRevisionDialog({required this.service, required this.stations, required this.categories, this.product});
  final MenuManagementService service;
  final List<MenuPreparationStation> stations;
  final List<String> categories;
  final MenuProduct? product;
  @override
  State<_ProductRevisionDialog> createState() => _ProductRevisionDialogState();
}

class _ProductRevisionDialogState extends State<_ProductRevisionDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _description;
  late final TextEditingController _category;
  late final TextEditingController _normal;
  late final TextEditingController _tourism;
  late final TextEditingController _owner;
  late final TextEditingController _minutes;
  late final TextEditingController _order;
  late final TextEditingController _tags;
  String? _imagePath;
  String? _station;
  bool _uploading = false;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _barcode = TextEditingController(text: product?.barcode ?? '');
    _description = TextEditingController(text: product?.description ?? '');
    _category = TextEditingController(text: product?.category ?? '');
    _normal = TextEditingController(text: product?.normalPriceIqd.toString() ?? '');
    _tourism = TextEditingController(text: product?.tourismPriceIqd.toString() ?? '');
    _owner = TextEditingController(text: product?.ownerPriceIqd?.toString() ?? '');
    _minutes = TextEditingController(text: product?.preparationMinutes?.toString() ?? '');
    _order = TextEditingController(text: product?.displayOrder.toString() ?? '0');
    _tags = TextEditingController(text: product?.dietaryTags.join(', ') ?? '');
    _imagePath = product?.imagePath;
    _station = product?.stationKey;
  }

  @override
  void dispose() {
    for (final controller in [_name, _barcode, _description, _category, _normal, _tourism, _owner, _minutes, _order, _tags]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return 'Enter $label.';
    return null;
  }

  String? _price(String? value) {
    final amount = int.tryParse(value?.trim() ?? '');
    if (amount == null || amount < 0 || amount > 1000000000) return 'Use a whole IQD amount from 0 to 1,000,000,000.';
    return null;
  }

  Future<void> _pickImage() async {
    setState(() { _uploading = true; _uploadError = null; });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      _imagePath = await widget.service.uploadProductImage(result.files.single);
    } catch (error) {
      _uploadError = _actionableError(error, action: 'Photo upload failed.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final tags = _tags.text.split(',').map((tag) => tag.trim().toLowerCase().replaceAll(' ', '_')).where((tag) => tag.isNotEmpty).toSet().toList();
    final allowed = MenuManagementService.allowedDietaryTags;
    if (tags.any((tag) => !allowed.contains(tag))) {
      setState(() => _uploadError = 'Dietary tags accepted: vegetarian, vegan, gluten_free, spicy, halal.');
      return;
    }
    final minutes = _minutes.text.trim().isEmpty ? null : int.tryParse(_minutes.text.trim());
    final orderText = _order.text.trim();
    final order = orderText.isEmpty ? 0 : int.tryParse(orderText);
    if ((_minutes.text.trim().isNotEmpty && (minutes == null || minutes < 0 || minutes > 600)) || order == null || order < 0) {
      setState(() => _uploadError = 'Preparation time must be 0–600 minutes and display order must be a non-negative whole number.');
      return;
    }
    if (_station != null &&
        !widget.stations.any((station) => station.key == _station && station.enabled)) {
      setState(() => _uploadError = 'Choose an active preparation station or select No station.');
      return;
    }
    Navigator.pop(context, MenuProductDraft(
      name: _name.text.trim(),
      barcode: _barcode.text.trim(),
      description: _description.text.trim(),
      category: _category.text.trim().isEmpty ? 'Uncategorized' : _category.text.trim(),
      normalPriceIqd: int.parse(_normal.text.trim()),
      tourismPriceIqd: int.parse(_tourism.text.trim()),
      ownerPriceIqd: _owner.text.trim().isEmpty ? null : int.tryParse(_owner.text.trim()),
      imagePath: _imagePath,
      preparationMinutes: minutes,
      dietaryTags: tags,
      displayOrder: order,
      stationKey: _station,
    ));
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 690, maxHeight: 760),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 17, 10, 10),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.product == null ? 'Propose a new product' : 'Propose product changes', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const Text('This becomes live only after owner approval.'),
            ])),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), tooltip: 'Close'),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFF7F2E9), borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    const Icon(Icons.pending_actions_outlined, color: Color(0xFF735C31)),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Submitting creates a revision, not a live edit. Existing orders, recipes and stock links are preserved.')),
                  ]),
                ),
                const SizedBox(height: 18),
                Wrap(spacing: 16, runSpacing: 13, children: [
                  _field(
                    _name,
                    'Product name',
                    required: true,
                    width: 300,
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Enter product name.';
                      if (text.length > 150) return 'Use 150 characters or fewer.';
                      return null;
                    },
                  ),
                  _field(
                    _barcode,
                    'Barcode',
                    required: true,
                    width: 230,
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Enter barcode.';
                      if (text.length > 80) return 'Use 80 characters or fewer.';
                      return null;
                    },
                  ),
                  _field(
                    _category,
                    'Category',
                    width: 240,
                    hint: 'e.g. Breakfast',
                    validator: (value) => (value?.trim().length ?? 0) > 80
                        ? 'Use 80 characters or fewer.'
                        : null,
                  ),
                  _field(_normal, 'Normal price · IQD', required: true, width: 190, validator: _price, numeric: true),
                  _field(_tourism, 'Tourism price · IQD', required: true, width: 190, validator: _price, numeric: true),
                  _field(_owner, 'Owner price · IQD', width: 190, validator: (v) => v == null || v.trim().isEmpty ? null : _price(v), numeric: true, hint: 'Optional'),
                  _field(_minutes, 'Preparation · minutes', width: 190, numeric: true),
                  _field(_order, 'Display order', width: 150, numeric: true),
                ]),
                if (widget.categories.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 7, runSpacing: 7, children: [
                    for (final category in widget.categories)
                      ActionChip(
                        label: Text(category),
                        onPressed: () => setState(() => _category.text = category),
                      ),
                  ]),
                ],
                const SizedBox(height: 13),
                TextFormField(controller: _description, minLines: 2, maxLines: 4, maxLength: 1200, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 13),
                TextFormField(controller: _tags, decoration: const InputDecoration(labelText: 'Dietary tags', hintText: 'vegetarian, spicy', helperText: 'Allowed: vegetarian, vegan, gluten_free, spicy, halal')),
                const SizedBox(height: 13),
                DropdownButtonFormField<String>(
                  value: _station,
                  decoration: const InputDecoration(
                    labelText: 'Preparation station',
                    helperText: 'Optional routing label for staff. Disabled stations cannot be saved.',
                  ),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('No station')),
                    for (final station in widget.stations)
                      if (station.enabled || station.key == _station)
                        DropdownMenuItem(
                          value: station.key,
                          enabled: station.enabled,
                          child: Text(station.enabled ? station.name : '${station.name} (disabled)'),
                        ),
                  ],
                  onChanged: (value) => setState(() => _station = value),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  OutlinedButton.icon(onPressed: _uploading ? null : _pickImage, icon: const Icon(Icons.add_photo_alternate_outlined), label: Text(_uploading ? 'Uploading photo…' : _imagePath == null ? 'Upload product photo' : 'Replace product photo')),
                  if (_imagePath != null) const Padding(padding: EdgeInsets.only(left: 10), child: Icon(Icons.check_circle, color: Color(0xFF39784E))),
                ]),
                if (_uploadError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_uploadError!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                const SizedBox(height: 10),
                const Text('Discounts are calculated by the existing server discount engine. No per-product discount price is stored here.'),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton.icon(onPressed: _uploading ? null : _submit, icon: const Icon(Icons.send_outlined), label: const Text('Submit for review')),
          ]),
        ),
      ]),
    ),
  );

  Widget _field(TextEditingController controller, String label, {bool required = false, bool numeric = false, double width = 210, String? hint, String? Function(String?)? validator}) =>
    SizedBox(width: width, child: TextFormField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: numeric ? [] : null,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: validator ?? (required ? (value) => _required(value, label.toLowerCase()) : null),
    ));
}

class _ProductHistoryDialog extends StatelessWidget {
  const _ProductHistoryDialog({required this.service, required this.product});
  final MenuManagementService service;
  final MenuProduct product;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${product.name} · history'),
    content: SizedBox(
      width: 560,
      height: 440,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: service.loadProductHistory(product.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _StatusPanel(icon: Icons.error_outline, title: 'History unavailable', body: _actionableError(snapshot.error!, action: 'Check access or connection and reopen history.'));
          if (!snapshot.hasData) return const _MenuSkeleton(compact: true);
          if (snapshot.data!.isEmpty) return const _StatusPanel(icon: Icons.history, title: 'No recorded changes yet', body: 'Audited product and availability actions will appear here.');
          return ListView.separated(
            itemCount: snapshot.data!.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final event = snapshot.data![index];
              final date = DateTime.tryParse('${event['occurred_at'] ?? ''}')?.toLocal();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.history, size: 18)),
                title: Text('${event['action'] ?? 'Menu change'}'),
                subtitle: Text('${date?.toString().substring(0, 16) ?? 'Time unavailable'} · ${_shortId('${event['request_id'] ?? event['revision_id'] ?? event['id']}')}'),
              );
            },
          );
        },
      ),
    ),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
  );
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.icon, required this.title, required this.body, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE1E7EE))),
    child: Column(children: [
      Icon(icon, size: 32, color: const Color(0xFF8A7653)),
      const SizedBox(height: 12),
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
      const SizedBox(height: 6),
      ConstrainedBox(constraints: const BoxConstraints(maxWidth: 530), child: Text(body, textAlign: TextAlign.center)),
      if (actionLabel != null && onAction != null) ...[
        const SizedBox(height: 16),
        FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
      ],
    ]),
  );
}

class _MenuSkeleton extends StatelessWidget {
  const _MenuSkeleton({this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => compact
      ? Column(children: List.generate(4, (_) => Container(
          height: 58,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: const Color(0xFFE7E4DD), borderRadius: BorderRadius.circular(12)),
        )))
      : Wrap(spacing: 12, runSpacing: 12, children: List.generate(6, (_) => Container(
          width: 230,
          height: 245,
          decoration: BoxDecoration(color: const Color(0xFFE7E4DD), borderRadius: BorderRadius.circular(17)),
        )));
}

class _GuardrailNote extends StatelessWidget {
  const _GuardrailNote();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: const Color(0xFFF2F0EA), borderRadius: BorderRadius.circular(14)),
    child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.verified_user_outlined, size: 20, color: Color(0xFF715D37)),
      SizedBox(width: 10),
      Expanded(child: Text('Catalog edits remain pending until owner approval. Availability changes are separately audited and apply to new orders only; existing order, recipe and stock records are not rewritten.')),
    ]),
  );
}

MenuProduct _copyProduct(MenuProduct item, {required bool isActive, required int version}) => MenuProduct(
  id: item.id, name: item.name, barcode: item.barcode, description: item.description, category: item.category,
  normalPriceIqd: item.normalPriceIqd, tourismPriceIqd: item.tourismPriceIqd, ownerPriceIqd: item.ownerPriceIqd,
  isActive: isActive, imagePath: item.imagePath, preparationMinutes: item.preparationMinutes,
  dietaryTags: item.dietaryTags, displayOrder: item.displayOrder, version: version, stationKey: item.stationKey,
  createdAt: item.createdAt, updatedAt: item.updatedAt,
);

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _formatIqd(int value) => value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
String _shortId(String value) => value.length > 12 ? value.substring(0, 8) : value;

String _actionableError(Object error, {required String action}) {
  final text = error.toString().toLowerCase();
  if (text.contains('socket') || text.contains('network') || text.contains('offline') || text.contains('connection')) {
    return 'Connection unavailable. $action Reconnect and retry; no change was confirmed.';
  }
  if (text.contains('version') || text.contains('stale') || text.contains('conflict')) {
    return 'This product changed since it was loaded. Refresh the latest version before trying again. $action';
  }
  if (text.contains('permission') || text.contains('denied') || text.contains('401') || text.contains('403')) {
    return 'Your account cannot complete this action. Ask an owner to confirm permissions. $action';
  }
  return '$action Check access and connection, then retry. No success was confirmed.';
}
