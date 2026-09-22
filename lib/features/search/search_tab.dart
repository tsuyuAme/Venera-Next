import 'package:flutter/material.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/app_page_route.dart';
import 'package:venera_next/features/search/search_page.dart';

/// Top-level search tab. Uses a nested [Navigator] so result pages stay on the
/// stack when the user switches to Home / Favorites / etc.
///
/// Combined with [IndexedStack] in [MainPage], this keeps search state alive.
///
/// [NavigatorPopHandler] wires Android/iOS system back into this nested stack
/// (desktop mouse-back / Esc already go through [App.pop]).
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

  @override
  void initState() {
    super.initState();
    // Register for mouse-back / Esc via [App.pop]
    App.secondaryNavigatorKey = navigatorKey;
  }

  @override
  void dispose() {
    if (App.secondaryNavigatorKey == navigatorKey) {
      App.secondaryNavigatorKey = null;
      App.secondaryNavigatorActive = false;
    }
    super.dispose();
  }

  /// Pop nested routes back to the search form (optional when re-tapping tab).
  void popToRoot() {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  bool get canPop => navigatorKey.currentState?.canPop() ?? false;

  void pop() {
    if (canPop) {
      navigatorKey.currentState!.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Without this, the system back button only consults the *main* shell
    // navigator (see NaviPane PopScope). Nested search result / source-result
    // routes would be ignored and Android would exit or no-op.
    return NavigatorPopHandler(
      onPopWithResult: (result) {
        navigatorKey.currentState?.pop(result);
      },
      child: Navigator(
        key: navigatorKey,
        onGenerateRoute: (settings) {
          return AppPageRoute(
            preventRebuild: false,
            builder: (context) => const SearchPage(),
          );
        },
      ),
    );
  }
}
