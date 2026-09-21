import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/app_page_route.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/comic_details/comic_details.dart';

void handleLinks() {
  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) {
    handleAppLink(uri);
  });
}

/// Close comment sidebars / dialogs pushed on the root navigator.
void closeRootOverlays() {
  final nav = App.rootNavigatorKey.currentState;
  if (nav == null) return;
  // Pop every route above MainPage (SideBarRoute, dialogs, …).
  while (nav.canPop()) {
    nav.pop();
  }
}

/// Navigator that should receive in-app comic opens from comment links, etc.
NavigatorState? navigatorForAppLinks() {
  final main = App.mainNavigatorKey?.currentState;
  final secondary = App.secondaryNavigatorKey?.currentState;

  // Search tab visible → its nested stack.
  if (App.secondaryNavigatorActive && secondary != null) {
    return secondary;
  }
  // Prefer the navigator that already has a comic (or other page) open.
  if (main != null && main.canPop()) {
    return main;
  }
  if (secondary != null && secondary.canPop()) {
    return secondary;
  }
  return main ?? secondary;
}

Future<bool> handleAppLink(Uri uri) async {
  for (var source in ComicSource.all()) {
    if (source.linkHandler != null) {
      if (source.linkHandler!.domains.contains(uri.host)) {
        var id = source.linkHandler!.linkToId(uri.toString());
        if (id != null) {
          if (App.mainNavigatorKey == null) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
          final nav = navigatorForAppLinks();
          if (nav == null) {
            return false;
          }
          // IMPORTANT: do NOT await push — the Future completes only when the
          // new route is popped, which delayed closing the comments sidebar
          // and made navigation feel like a no-op.
          nav.push(
            AppPageRoute(
              preventRebuild: false,
              builder: (context) {
                return ComicPage(id: id, sourceKey: source.key);
              },
            ),
          );
          return true;
        }
        return false;
      }
    }
  }
  return false;
}
