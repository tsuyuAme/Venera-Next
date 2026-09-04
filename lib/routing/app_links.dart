import 'package:app_links/app_links.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/comic_details/comic_details.dart';

void handleLinks() {
  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) {
    handleAppLink(uri);
  });
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
          // Prefer Search-tab nested navigator when active, else main shell.
          final ctx = (App.secondaryNavigatorActive
                  ? App.secondaryNavigatorKey?.currentContext
                  : null) ??
              App.mainNavigatorKey?.currentContext;
          if (ctx == null || !ctx.mounted) {
            return false;
          }
          ctx.to(() {
            return ComicPage(id: id, sourceKey: source.key);
          });
          return true;
        }
        return false;
      }
    }
  }
  return false;
}
