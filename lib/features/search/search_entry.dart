import 'package:flutter/material.dart';
import 'package:venera_next/components/gesture.dart';
import 'package:venera_next/components/navigation_bar.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';

/// Opens the primary Search tab (index 1) instead of pushing a disposable route,
/// so previous search results remain when returning later.
class SearchEntry extends StatelessWidget {
  const SearchEntry({super.key});

  static const int searchTabIndex = 1;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        height: App.isMobile ? 52 : 46,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Material(
          color: context.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(32),
          child: ClickInkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: () {
              // Prefer tab switch so nested SearchResultPage stays mounted.
              final navi = context.findAncestorStateOfType<NaviPaneState>();
              if (navi != null) {
                navi.updatePage(searchTabIndex);
              }
            },
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.search),
                const SizedBox(width: 8),
                Text('Search'.tl, style: ts.s16),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

