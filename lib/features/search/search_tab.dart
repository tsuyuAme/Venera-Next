import 'package:flutter/material.dart';
import 'package:venera_next/foundation/app_page_route.dart';
import 'package:venera_next/features/search/search_page.dart';

/// Top-level search tab. Uses a nested [Navigator] so result pages stay on the
/// stack when the user switches to Home / Favorites / etc.
///
/// Combined with [IndexedStack] in [MainPage], this keeps search state alive.
class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => SearchTabState();
}

class SearchTabState extends State<SearchTab>
    with AutomaticKeepAliveClientMixin {
  final navigatorKey = GlobalKey<NavigatorState>();

  @override
  bool get wantKeepAlive => true;

  /// Pop nested routes back to the search form (optional when re-tapping tab).
  void popToRoot() {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  bool get canPop => navigatorKey.currentState?.canPop() ?? false;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        return AppPageRoute(
          preventRebuild: false,
          builder: (context) => const SearchPage(),
        );
      },
    );
  }
}
