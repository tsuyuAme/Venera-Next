import 'package:flutter/material.dart';
import 'package:venera_next/components/gesture.dart';
import 'package:venera_next/components/scroll.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';
import 'package:venera_next/features/search/artist_favorites_page.dart';
import 'package:venera_next/features/search/search_shortcuts.dart';

/// Home page summary card for favorited artists.
class ArtistFavoritesSummary extends StatefulWidget {
  const ArtistFavoritesSummary({super.key});

  @override
  State<ArtistFavoritesSummary> createState() => _ArtistFavoritesSummaryState();
}

class _ArtistFavoritesSummaryState extends State<ArtistFavoritesSummary> {
  int _count = 0;

  void _refresh() {
    var names = <String>{};
    for (var shortcut in SearchShortcutManager.instance.all) {
      if (shortcut.kind == SearchShortcutKind.author) {
        names.add(shortcut.value);
      }
    }
    setState(() {
      _count = names.length;
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

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.6,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClickInkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            context.to(() => const ArtistFavoritesPage());
          },
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                Center(child: Text('Artist favorites'.tl, style: ts.s18)),
                const Spacer(),
                if (_count > 0)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_count',
                      style: ts.s14.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                const Icon(Icons.chevron_right).paddingRight(8),
              ],
            ).paddingHorizontal(12),
          ),
        ),
      ),
    );
  }
}
