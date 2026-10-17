import 'package:flutter/material.dart';

import 'favorites_page.dart';
import 'cafe_language.dart';

List<String> orderedCafeCards(List<String> saved, List<String> permitted) {
  final allowed = permitted.toSet();
  return {...saved.where(allowed.contains), ...permitted}.toList();
}

/// Reorder only the visible slots, retaining filtered/permission-hidden entries.
List<String> mergeCafeCardOrder(
  List<String> saved,
  List<String> defaults,
  List<String> visibleOrder,
) {
  final all = {...saved, ...defaults}.toList();
  final visible = visibleOrder.toSet();
  var index = 0;
  return [
    for (final id in all) visible.contains(id) ? visibleOrder[index++] : id,
  ];
}

class CafeCardOrder extends StatefulWidget {
  const CafeCardOrder({
    super.key,
    required this.account,
    required this.scope,
    required this.titles,
    required this.builder,
    this.storage,
  });
  final String account, scope;
  final List<String> titles;
  final Widget Function(List<String>) builder;
  final FavoritesStorage? storage;
  @override
  State<CafeCardOrder> createState() => _CafeCardOrderState();
}

class _CafeCardOrderState extends State<CafeCardOrder> {
  late FavoritesStorage _storage;
  List<String> _saved = [];
  bool _loading = true, _saving = false, _editing = false;
  String? _error;
  int _generation = 0;
  String get _key => '${widget.account}:card-order:v1:${widget.scope}';
  bool get _blocked => _loading || _saving || _error != null;
  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? LocalFavoritesStorage();
    _load();
  }

  @override
  void didUpdateWidget(CafeCardOrder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account != widget.account ||
        oldWidget.scope != widget.scope ||
        oldWidget.storage != widget.storage) {
      _storage = widget.storage ?? LocalFavoritesStorage();
      _editing = false;
      _saving = false;
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation, key = _key;
    final storage = _storage;
    setState(() {
      _loading = true;
      _saved = [];
      _error = null;
    });
    try {
      final saved = await storage.read(key);
      if (mounted && generation == _generation) {
        setState(() => _saved = saved.toSet().toList());
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = 'Could not load card order. Default order is shown. Retry before arranging.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save(List<String> order, {bool reset = false}) async {
    if (_blocked) return;
    final generation = _generation, key = _key, storage = _storage;
    final defaults = List<String>.from(widget.titles);
    setState(() => _saving = true);
    try {
      final latest = (await storage.read(key)).toSet().toList();
      if (!mounted || generation != _generation) return;
      // If access or filtering changed while storage was loading, abandon this gesture.
      if (defaults.length != widget.titles.length ||
          !defaults.toSet().containsAll(widget.titles)) {
        return;
      }
      final next = reset
          ? <String>[]
          : mergeCafeCardOrder(latest, defaults, order);
      await storage.write(key, next);
      if (mounted && generation == _generation) setState(() => _saved = next);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () =>
              _error = 'Could not confirm the saved order. Retry to reload it.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _saving = false);
    }
  }

  Future<void> _move(int oldIndex, int newIndex) async {
    if (_blocked) return;
    final order = orderedCafeCards(_saved, widget.titles);
    
    if (oldIndex < 0 ||
        oldIndex >= order.length ||
        newIndex < 0 ||
        newIndex >= order.length ||
        oldIndex == newIndex) {
      return;
    }
    order.insert(newIndex, order.removeAt(oldIndex));
    await _save(order);
  }

  Future<void> _reset() async {
    final generation = _generation;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const CafeText('Reset card order?'),
        content: const CafeText(
          'Restore the default order for this category on this device, including currently hidden cards. Other categories and favorites stay unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const CafeText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const CafeText('Reset order'),
          ),
        ],
      ),
    );
    if (yes == true && mounted && generation == _generation) {
      await _save([], reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = orderedCafeCards(_saved, widget.titles);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              key: ValueKey('arrange-cards-${widget.scope}'),
              onPressed: _blocked || order.length < 2
                  ? null
                  : () => setState(() => _editing = !_editing),
              icon: Icon(_editing ? Icons.done : Icons.drag_indicator),
              label: CafeText(_editing ? 'Done arranging' : 'Arrange cards'),
            ),
            if (_editing)
              TextButton(
                onPressed: _blocked ? null : _reset,
                child: const CafeText('Reset order'),
              ),
            if (_saving) const CafeText('Saving order…'),
          ],
        ),
        if (_error != null) ...[
          CafeText(_error!),
          TextButton(
            onPressed: _saving ? null : _load,
            child: const CafeText('Retry card order'),
          ),
        ],
        if (_editing) ...[
          const CafeText(
            'Drag the handle or use the arrows. Order is saved for this account on this browser/device, within this category.',
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: order.length,
            onReorderItem: _blocked ? (_, _) {} : _move,
            itemBuilder: (context, index) => Card(
              key: ValueKey('order-card-${order[index]}'),
              color: const Color(0xFF162A43),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      enabled: !_blocked,
                      child: Semantics(
                        label: 'Drag ${order[index]}',
                        button: true,
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.drag_indicator,
                            color: Color(0xFFD6AA57),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        order[index],
                        style: const TextStyle(color: Color(0xFFF6F2E9)),
                      ),
                    ),
                    IconButton(
                      key: ValueKey('card-earlier-${order[index]}'),
                      tooltip: 'Move ${order[index]} earlier',
                      onPressed: _blocked || index == 0
                          ? null
                          : () => _move(index, index - 1),
                      icon: const Icon(
                        Icons.arrow_upward,
                        color: Color(0xFFD6AA57),
                      ),
                    ),
                    IconButton(
                      key: ValueKey('card-later-${order[index]}'),
                      tooltip: 'Move ${order[index]} later',
                      onPressed: _blocked || index == order.length - 1
                          ? null
                          : () => _move(index, index + 1),
                      icon: const Icon(
                        Icons.arrow_downward,
                        color: Color(0xFFD6AA57),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else
          widget.builder(order),
      ],
    );
  }
}
