import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:venera_next/components/appbar.dart';
import 'package:venera_next/components/menu.dart';
import 'package:venera_next/components/message.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';
import 'package:venera_next/features/search/aggregated_search_page.dart';
import 'package:venera_next/features/search/search_shortcuts.dart';

/// Groups artist shortcuts by artist name, keeping the set of source keys
/// that contributed each name. Order follows the favorites insertion order.
Map<String, Set<String>> groupArtistShortcuts(
  List<SearchShortcut> shortcuts,
) {
  var artists = <String, Set<String>>{};
  for (var shortcut in shortcuts) {
    if (shortcut.kind != SearchShortcutKind.author) continue;
    artists.putIfAbsent(shortcut.value, () => <String>{}).add(
      shortcut.sourceKey,
    );
  }
  return artists;
}

/// Page that lists all favorited artists (author search shortcuts).
///
/// Artists are persisted by the existing [SearchShortcutManager] inside
/// appdata settings, so they are automatically covered by WebDAV data sync
/// and app data export/import. This page only renders and manages them:
/// - tap a row: aggregated search across all sources
/// - copy button: copy the artist name
/// - long press: delete the artist from all sources
class ArtistFavoritesPage extends StatefulWidget {
  const ArtistFavoritesPage({super.key});

  @override
  State<ArtistFavoritesPage> createState() => _ArtistFavoritesPageState();
}

class _ArtistFavoritesPageState extends State<ArtistFavoritesPage> {
  /// artist name -> source keys that contributed this artist
  Map<String, Set<String>> _artists = {};

  void _refresh() {
    var artists = groupArtistShortcuts(SearchShortcutManager.instance.all);
    setState(() {
      _artists = artists;
    });
  }

  @override
  void initState() {
    SearchShortcutManager.instance.addListener(_refresh);
    _refresh();
    super.initState();
  }

  @override
  void dispose() {
    SearchShortcutManager.instance.removeListener(_refresh);
    super.dispose();
  }

  void _openSearch(String name) {
    context.to(() => AggregatedSearchPage(keyword: name));
  }

  void _copyArtist(String name) {
    Clipboard.setData(ClipboardData(text: name));
    context.showMessage(message: 'Copied'.tl);
  }

  void _deleteArtist(String name) {
    showConfirmDialog(
      context: context,
      title: 'Delete artist'.tl,
      content: 'Delete "@name" from artist favorites?'.tlParams({
        'name': name,
      }),
      onConfirm: () {
        var manager = SearchShortcutManager.instance;
        for (var shortcut in manager.all) {
          if (shortcut.kind == SearchShortcutKind.author &&
              shortcut.value == name) {
            manager.remove(shortcut);
          }
        }
        context.showMessage(message: 'Deleted'.tl);
      },
      confirmText: 'Delete',
      btnColor: Theme.of(context).colorScheme.error,
    );
  }

  void _onLongPress(String name, BuildContext rowContext) {
    final renderBox = rowContext.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    showMenuX(
      context: rowContext,
      location: Offset(
        offset.dx + renderBox.size.width / 2 - 121,
        offset.dy + renderBox.size.height - 8,
      ),
      entries: [
        MenuEntry(
          icon: Icons.copy,
          text: 'Copy'.tl,
          onClick: () => _copyArtist(name),
        ),
        MenuEntry(
          icon: Icons.delete_outline,
          text: 'Delete'.tl,
          onClick: () => _deleteArtist(name),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var artists = _artists.entries.toList();
    return CustomScrollView(
      slivers: [
        SliverAppbar(title: Text('Favorite authors'.tl)),
        if (artists.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_add_alt,
                    size: 56,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No favorite artists yet'.tl,
                    style: ts.s16,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Long press the artist tag on comic page to add'.tl,
                    style: ts.s14.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: artists.length,
            itemBuilder: (context, index) {
              var entry = artists[index];
              var sources = entry.value;
              return Builder(
                builder: (rowContext) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(entry.key),
                  subtitle: Text(
                    'Sources: @count'.tlParams({
                      'count': sources.length,
                    }),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy_rounded),
                        tooltip: 'Copy'.tl,
                        onPressed: () => _copyArtist(entry.key),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search),
                        tooltip: 'Search'.tl,
                        onPressed: () => _openSearch(entry.key),
                      ),
                    ],
                  ),
                  onTap: () => _openSearch(entry.key),
                  onLongPress: () => _onLongPress(entry.key, rowContext),
                ),
              );
            },
          ),
      ],
    );
  }
}
