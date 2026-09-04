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

/// Navigator that should receive in-app comic opens from comment links, etc.
NavigatorState? _navigatorForAppLinks() {
  final main = App.mainNavigatorKey?.currentState;
  final secondary = App.secondaryNavigatorKey?.currentState;

  // Search tab is visible → open on its nested stack (keeps back stack correct).
  if (App.secondaryNavigatorActive && secondary != null) {
    return secondary;
  }
  // History / Favorites / Home: comic is on the main shell stack.
  if (main != null) {
    return main;
  }
  return secondary;
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
          final nav = _navigatorForAppLinks();
          if (nav == null) {
            return false;
          }
          // Push on NavigatorState directly — more reliable than
          // GlobalKey.currentContext?.to() after tab switches.
          await nav.push(
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
