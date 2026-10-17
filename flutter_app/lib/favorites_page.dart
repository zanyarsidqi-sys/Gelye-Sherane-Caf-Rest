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
  });
  final String account;
  final List<FavoriteCardEntry> cards;
  final ValueChanged<FavoriteCardEntry> onOpen;
  final FavoritesStorage? storage;
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late final _storage = widget.storage ?? LocalFavoritesStorage();
  Set<String> _ids = {};
  bool _loading = true, _saving = false, _adding = false;
  String _query = '';
  String? _error;
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ids = await _storage.read(widget.account);
      if (mounted) setState(() => _ids = ids.toSet());
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not load favorites on this device. Retry to avoid replacing your saved list.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(FavoriteCardEntry card) async {
    if (_saving || _loading || _error != null) return;
    setState(() => _saving = true);
    try {
      // Reload before changing one entry so another tab's recent stars survive.
      final updated = (await _storage.read(widget.account)).toSet();
      if (!updated.add(card.id)) updated.remove(card.id);
      await _storage.write(widget.account, updated.toList()..sort());
      if (mounted) setState(() => _ids = updated);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not confirm the change. Retry to reload your favorites.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleFavorites = widget.cards
        .where((card) => _ids.contains(card.id))
        .toList();
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
        const Text(
          'Favorites',
          style: TextStyle(
            color: Color(0xFFF6F2E9),
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
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
                      _query = '';
                      _search.clear();
                    }),
              icon: Icon(_adding ? Icons.done : Icons.add),
              label: Text(_adding ? 'Done adding cards' : 'Add cards'),
            ),
            Text(
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
            child: const Text(
              'Retry',
              style: TextStyle(color: Color(0xFFD6AA57)),
            ),
          ),
        ] else ...[
          TextField(
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
                      onTap: _adding ? null : () => widget.onOpen(card),
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
