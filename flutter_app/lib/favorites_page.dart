import 'cafe_language.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteCardEntry {
  const FavoriteCardEntry({
    required this.id,
    required this.section,
    required this.title,
  });
  final String id;
  final String section;
  final String title;
}

abstract class FavoritesStorage {
  Future<List<String>> read(String account);
  Future<void> write(String account, List<String> ids);
}

class LocalFavoritesStorage implements FavoritesStorage {
  final _preferences = SharedPreferencesAsync();
  String _key(String account) =>
      'cafe.favorite_cards.v1.${Uri.encodeComponent(account)}';
  @override
  Future<List<String>> read(String account) async =>
      await _preferences.getStringList(_key(account)) ?? [];
  @override
  Future<void> write(String account, List<String> ids) =>
      _preferences.setStringList(_key(account), ids);
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({
    super.key,
    required this.account,
    required this.cards,
    required this.onOpen,
    this.storage,
    this.cardBuilder,
    this.title = 'Favorites',
    this.manageInitially = false,
  });
  final String account;
  final String title;
  final bool manageInitially;
  final List<FavoriteCardEntry> cards;
  final ValueChanged<FavoriteCardEntry> onOpen;
  final FavoritesStorage? storage;
  final Widget Function(FavoriteCardEntry)? cardBuilder;
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late FavoritesStorage _storage;
  List<String> _ids = [];
  bool _loading = true, _saving = false, _adding = false, _arranging = false;
  int _generation = 0;
  String _query = '';
  String? _error;
  final _search = TextEditingController();
  bool get _blocked => _loading || _saving || _error != null;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? LocalFavoritesStorage();
    _adding = widget.manageInitially;
    _load();
  }

  @override
  void didUpdateWidget(covariant FavoritesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account != widget.account || oldWidget.storage != widget.storage) {
      _storage = widget.storage ?? LocalFavoritesStorage();
      _ids = [];
      _saving = false;
      _adding = widget.manageInitially;
      _arranging = false;
      _query = '';
      _search.clear();
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    _search.dispose();
    super.dispose();
  }

  bool _current(int generation) => mounted && generation == _generation;
  bool _permitted(String id) => widget.cards.any((card) => card.id == id);

  Future<void> _load() async {
    final generation = ++_generation;
    final account = widget.account;
    final storage = _storage;
    setState(() { _loading = true; _error = null; _ids = []; });
    try {
      final ids = await storage.read(account);
      if (_current(generation)) setState(() => _ids = ids.toSet().toList());
    } catch (_) {
      if (_current(generation)) { setState(() => _error =
        'Could not load favorites on this device. Retry to avoid replacing your saved list.'); }
    } finally {
      if (_current(generation)) setState(() => _loading = false);
    }
  }

  Future<void> _change(List<String> Function(List<String>) change) async {
    if (_blocked) return;
    final generation = _generation;
    final account = widget.account;
    final storage = _storage;
    setState(() => _saving = true);
    try {
      // Merge against a fresh read. Device storage is not an atomic multi-tab store.
      final latest = (await storage.read(account)).toSet().toList();
      if (!_current(generation)) return;
      final updated = change(latest);
      await storage.write(account, updated);
      if (_current(generation)) setState(() => _ids = updated);
    } catch (_) {
      if (_current(generation)) { setState(() => _error =
        'Could not confirm the change. Retry to reload your favorites.'); }
    } finally {
      if (_current(generation)) setState(() => _saving = false);
    }
  }

  Future<void> _toggle(FavoriteCardEntry card) async {
    if (!_permitted(card.id)) return;
    // Explicit desired state makes a stale view safe to retry after reload.
    final selected = _ids.contains(card.id);
    await _change((latest) {
      if (!_permitted(card.id)) return latest;
      if (selected) { latest.remove(card.id); }
      else if (!latest.contains(card.id)) { latest.add(card.id); }
      return latest;
    });
  }

  Future<void> _move(String id, int direction) async {
    await _change((latest) {
      if (!_permitted(id)) return latest;
      final visible = latest.where(_permitted).toList();
      final from = visible.indexOf(id);
      final to = from + direction;
      if (from < 0 || to < 0 || to >= visible.length) return latest;
      final a = latest.indexOf(id), b = latest.indexOf(visible[to]);
      latest[a] = visible[to]; latest[b] = id;
      return latest;
    });
  }

  Future<void> _reset() async {
    if (_blocked) return;
    final generation = _generation;
    final confirmed = await showDialog<bool>(context: context, builder: (context) =>
      AlertDialog(
        title: const CafeText('Reset favorites?'),
        content: const CafeText('Remove all saved favorites for this account on this device, including cards currently hidden by permissions? Your access permissions will not change.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const CafeText('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const CafeText('Reset favorites')),
        ],
      ));
    if (confirmed == true && _current(generation)) await _change((_) => []);
  }

  Widget _arrangeList(List<FavoriteCardEntry> cards) => Column(children: [
    const CafeText('Use the arrows to arrange your Favorites. This does not reorder the main Dashboard categories.',
      style: TextStyle(color: Color(0xFFB7C2D1))),
    for (var i = 0; i < cards.length; i++)
      Card(key: ValueKey('arrange-${cards[i].id}'), color: const Color(0xFF162A43),
        child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(cards[i].title, style: const TextStyle(color: Color(0xFFF6F2E9))),
            Text(cards[i].section, style: const TextStyle(color: Color(0xFFB7C2D1))),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              IconButton(key: ValueKey('move-up-${cards[i].id}'), tooltip: 'Move ${cards[i].title} earlier',
                onPressed: _blocked || i == 0 ? null : () => _move(cards[i].id, -1),
                icon: const Icon(Icons.arrow_upward, color: Color(0xFFD6AA57))),
              IconButton(key: ValueKey('move-down-${cards[i].id}'), tooltip: 'Move ${cards[i].title} later',
                onPressed: _blocked || i == cards.length - 1 ? null : () => _move(cards[i].id, 1),
                icon: const Icon(Icons.arrow_downward, color: Color(0xFFD6AA57))),
            ]),
          ]))),
  ]);

  @override
  Widget build(BuildContext context) {
    final byId = {for (final card in widget.cards) card.id: card};
    final visibleFavorites = [for (final id in _ids) if (byId.containsKey(id)) byId[id]!];
    final cards = (_adding ? widget.cards : visibleFavorites)
        .where(
          (card) => '${card.title} ${card.section}'.toLowerCase().contains(
            _query.trim().toLowerCase(),
          ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CafeText(
          widget.title,
          style: const TextStyle(
            color: Color(0xFFF6F2E9),
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        const CafeText(
          'Your cards from any section. Saved for this account on this browser or device.',
          style: TextStyle(color: Color(0xFFB7C2D1)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const ValueKey('favorites-picker'),
              onPressed: _loading || _saving || _error != null
                  ? null
                  : () => setState(() {
                      _adding = !_adding;
                      _arranging = false;
                      _query = '';
                      _search.clear();
                    }),
              icon: Icon(_adding ? Icons.done : Icons.add),
              label: Text(_adding ? 'Done adding cards' : 'Add cards'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('favorites-arrange'),
              onPressed: _blocked || visibleFavorites.isEmpty ? null : () => setState(() {
                _arranging = !_arranging; _adding = false; _query = ''; _search.clear();
              }),
              icon: const Icon(Icons.swap_vert),
              label: CafeText(_arranging ? 'Done arranging' : 'Arrange favorites'),
            ),
            TextButton(onPressed: _blocked ? null : _load, child: const CafeText('Refresh favorites')),
            TextButton(key: const ValueKey('favorites-reset'),
              onPressed: _blocked || _ids.isEmpty ? null : _reset, child: const CafeText('Reset favorites')),
            CafeText(
              '${visibleFavorites.length} favorite cards',
              style: const TextStyle(color: Color(0xFFB7C2D1)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Color(0xFFF6F2E9))),
          TextButton(
            onPressed: _saving ? null : _load,
            child: const CafeText(
              'Retry',
              style: TextStyle(color: Color(0xFFD6AA57)),
            ),
          ),
        ] else ...[
          if (!_arranging) TextField(
            key: const ValueKey('favorites-search'),
            controller: _search,
            style: const TextStyle(color: Color(0xFFF6F2E9)),
            decoration: InputDecoration(
              labelText: _adding
                  ? 'Find cards in any section'
                  : 'Search favorites',
              labelStyle: const TextStyle(color: Color(0xFFB7C2D1)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFB7C2D1)),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 12),
          if (cards.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                _adding || _query.isNotEmpty
                    ? 'No permitted cards match your search.'
                    : 'No favorites yet. Choose Add cards to get started.',
                style: const TextStyle(color: Color(0xFFB7C2D1)),
              ),
            )
          else if (_arranging)
            _arrangeList(visibleFavorites)
          else if (!_adding && widget.cardBuilder != null)
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1000 ? 4 : constraints.maxWidth >= 720 ? 3 : constraints.maxWidth >= 480 ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cards.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns, mainAxisExtent: 280,
                  crossAxisSpacing: 12, mainAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final card = cards[index];
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: Semantics(
                      button: true, label: '${card.title}, ${card.section}',
                      onTap: () => widget.onOpen(card),
                      child: GestureDetector(
                        key: ValueKey('favorite-open-${card.id}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onOpen(card),
                        child: ExcludeSemantics(child: IgnorePointer(child: widget.cardBuilder!(card))),
                      ),
                    )),
                    Row(children: [
                      Expanded(child: Text(card.section, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFFB7C2D1), fontSize: 12))),
                      IconButton(
                        key: ValueKey('favorite-${card.id}'),
                        tooltip: 'Remove ${card.title} from favorites',
                        onPressed: _saving ? null : () => _toggle(card),
                        icon: const Icon(Icons.star, color: Color(0xFFD6AA57)),
                      ),
                    ]),
                  ]);
                },
              );
            })
          else
            SizedBox(
              height: 440,
              child: ListView.builder(
                key: ValueKey('favorites-list-$_adding'),
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  final card = cards[index];
                  final selected = _ids.contains(card.id);
                  return Card(
                    color: const Color(0xFF162A43),
                    child: ListTile(
                      title: Text(
                        card.title,
                        style: const TextStyle(color: Color(0xFFF6F2E9)),
                      ),
                      subtitle: Text(
                        card.section,
                        style: const TextStyle(color: Color(0xFFB7C2D1)),
                      ),
                      onTap: () => widget.onOpen(card),
                      trailing: IconButton(
                        key: ValueKey('favorite-${card.id}'),
                        tooltip: selected
                            ? 'Remove ${card.title} from favorites'
                            : 'Add ${card.title} to favorites',
                        onPressed: _saving ? null : () => _toggle(card),
                        color: const Color(0xFFD6AA57),
                        icon: Icon(selected ? Icons.star : Icons.star_border),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ],
    );
  }
}
