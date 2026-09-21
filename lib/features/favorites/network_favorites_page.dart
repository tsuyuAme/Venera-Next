import 'package:flutter/material.dart';
import 'package:venera_next/components/appbar.dart';
import 'package:venera_next/components/button.dart';
import 'package:venera_next/components/gesture.dart';
import 'package:venera_next/components/layout.dart';
import 'package:venera_next/components/loading.dart';
import 'package:venera_next/components/menu.dart';
import 'package:venera_next/components/message.dart';
import 'package:venera_next/components/scroll.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/comic_widgets/comic_widgets.dart';
import 'package:venera_next/features/favorites/favorite_actions.dart';
import 'package:venera_next/features/favorites/favorites_constants.dart';
import 'package:venera_next/features/favorites/favorites_display.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/consts.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/res.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';
import 'package:venera_next/network/cache.dart';


bool _sourceSupportsDateSeek(String sourceKey) => sourceKey == 'ehentai';

String _formatDateSeek(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

Future<bool> _deleteComic(
  String cid,
  String? fid,
  String sourceKey,
  String? favId,
) async {
  var source = ComicSource.find(sourceKey);
  if (source == null) {
    return false;
  }

  var result = false;

  await showDialog(
    context: App.rootContext,
    builder: (context) {
      bool loading = false;
      return StatefulBuilder(
        builder: (context, setState) {
          return ContentDialog(
            title: "Remove".tl,
            content: Text(
              "Remove comic from favorite?".tl,
            ).paddingHorizontal(16),
            actions: [
              Button.filled(
                isLoading: loading,
                color: context.colorScheme.error,
                onPressed: () async {
                  setState(() {
                    loading = true;
                  });
                  var res = await source.favoriteData!.addOrDelFavorite!(
                    cid,
                    fid ?? '',
                    false,
                    favId,
                  );
                  if (res.success) {
                    // Invalidate network cache so next loads fetch fresh data
                    NetworkCacheManager().clear();
                    context.showMessage(message: "Deleted".tl);
                    result = true;
                    context.pop();
                  } else {
                    setState(() {
                      loading = false;
                    });
                    context.showMessage(message: res.errorMessage!);
                  }
                },
                child: Text("Confirm".tl),
              ),
            ],
          );
        },
      );
    },
  );

  return result;
}

class NetworkFavoritePage extends StatelessWidget {
  const NetworkFavoritePage(this.data, {super.key, required this.showFolders});

  final FavoriteData data;
  final VoidCallback showFolders;

  @override
  Widget build(BuildContext context) {
    return data.multiFolder
        ? _MultiFolderFavoritesPage(data, showFolders: showFolders)
        : _NormalFavoritePage(data, showFolders: showFolders);
  }
}

class _NormalFavoritePage extends StatefulWidget {
  const _NormalFavoritePage(this.data, {required this.showFolders});

  final FavoriteData data;
  final VoidCallback showFolders;

  @override
  State<_NormalFavoritePage> createState() => _NormalFavoritePageState();
}

class _NormalFavoritePageState extends State<_NormalFavoritePage> {
  final comicListKey = GlobalKey<ComicListState>();

  String? dateSeek;

  Future<void> _pickSeekDate() async {
    if (!_sourceSupportsDateSeek(widget.data.key)) return;
    final now = DateTime.now();
    final initial =
        dateSeek != null ? (DateTime.tryParse(dateSeek!) ?? now) : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(2007),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      dateSeek = _formatDateSeek(picked);
    });
    NetworkCacheManager().clear();
    comicListKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ComicList(
      key: comicListKey,
      leadingSliver: SliverAppbar(
        style: context.width < changePoint
            ? AppbarStyle.shadow
            : AppbarStyle.blur,
        leading: Tooltip(
          message: "Folders".tl,
          child: context.width <= favoritesTwoPanelChangeWidth
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  color: context.colorScheme.primary,
                  onPressed: widget.showFolders,
                )
              : null,
        ),
        title: GestureDetector(
          onTap: context.width < favoritesTwoPanelChangeWidth
              ? widget.showFolders
              : null,
          child: Text(widget.data.title),
        ),
        actions: [
          const FavoriteDisplayButton(),
          if (_sourceSupportsDateSeek(widget.data.key))
            Tooltip(
              message: "Jump to page".tl,
              child: IconButton(
                icon: const Icon(Icons.calendar_month),
                onPressed: _pickSeekDate,
              ),
            ),
          Tooltip(
            message: "Refresh".tl,
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                // Force refresh bypassing cache
                NetworkCacheManager().clear();
                comicListKey.currentState!.refresh();
              },
            ),
          ),
          MenuButton(
            entries: [
              MenuEntry(
                icon: Icons.sync,
                text: "Convert to local".tl,
                onClick: () {
                  importNetworkFolder(widget.data.key, 9999999, null, null);
                },
              ),
            ],
          ),
        ],
      ),
      errorLeading: Appbar(
        leading: Tooltip(
          message: "Folders".tl,
          child: context.width <= favoritesTwoPanelChangeWidth
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  color: context.colorScheme.primary,
                  onPressed: widget.showFolders,
                )
              : null,
        ),
        title: GestureDetector(
          onTap: context.width < favoritesTwoPanelChangeWidth
              ? widget.showFolders
              : null,
          child: Text(widget.data.title),
        ),
      ),
      loadPage: widget.data.loadComic == null
          ? null
          : (i) => widget.data.loadComic!(i),
      loadNext: widget.data.loadNext == null
          ? null
          : (next) {
              var token = next;
              if (token == null && dateSeek != null) {
                token = '__seek__:$dateSeek';
              }
              return widget.data.loadNext!(token);
            },
      menuBuilder: (comic) {
        return [
          MenuEntry(
            icon: Icons.delete_outline,
            text: "Remove".tl,
            onClick: () async {
              var res = await _deleteComic(
                comic.id,
                null,
                comic.sourceKey,
                comic.favoriteId,
              );
              if (res) {
                comicListKey.currentState!.remove(comic);
              }
            },
          ),
        ];
      },
      enablePageStorage: true,
      useFavoriteDisplaySettings: true,
    );
  }
}

class _MultiFolderFavoritesPage extends StatefulWidget {
  const _MultiFolderFavoritesPage(this.data, {required this.showFolders});

  final FavoriteData data;
  final VoidCallback showFolders;

  @override
  State<_MultiFolderFavoritesPage> createState() =>
      _MultiFolderFavoritesPageState();
}

class _MultiFolderFavoritesPageState extends State<_MultiFolderFavoritesPage> {
  bool _loading = true;

  String? _errorMessage;

  Map<String, String>? folders;

  void loadPage() async {
    var res = await widget.data.loadFolders!();
    _loading = false;
    if (res.error) {
      setState(() {
        _errorMessage = res.errorMessage;
      });
    } else {
      setState(() {
        folders = res.data;
      });
    }
  }

  void openFolder(String key, String title) {
    context.to(() => _FavoriteFolder(widget.data, key, title));
  }

  @override
  Widget build(BuildContext context) {
    var sliverAppBar = SliverAppbar(
      style: context.width < changePoint
          ? AppbarStyle.shadow
          : AppbarStyle.blur,
      leading: Tooltip(
        message: "Folders".tl,
        child: context.width <= favoritesTwoPanelChangeWidth
            ? IconButton(
                icon: const Icon(Icons.menu),
                color: context.colorScheme.primary,
                onPressed: widget.showFolders,
              )
            : null,
      ),
      title: GestureDetector(
        onTap: context.width < favoritesTwoPanelChangeWidth
            ? widget.showFolders
            : null,
        child: Text(widget.data.title),
      ),
    );

    var appBar = Appbar(
      leading: Tooltip(
        message: "Folders".tl,
        child: context.width <= favoritesTwoPanelChangeWidth
            ? IconButton(
                icon: const Icon(Icons.menu),
                color: context.colorScheme.primary,
                onPressed: widget.showFolders,
              )
            : null,
      ),
      title: GestureDetector(
        onTap: context.width < favoritesTwoPanelChangeWidth
            ? widget.showFolders
            : null,
        child: Text(widget.data.title),
      ),
    );

    if (_loading) {
      loadPage();
      return Column(
        children: [
          appBar,
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    } else if (_errorMessage != null) {
      return Column(
        children: [
          appBar,
          Expanded(
            child: NetworkError(
              message: _errorMessage!,
              withAppbar: false,
              retry: () {
                setState(() {
                  _loading = true;
                  _errorMessage = null;
                });
              },
            ),
          ),
        ],
      );
    } else {
      var length = folders!.length;
      if (widget.data.allFavoritesId != null) length++;
      final keys = folders!.keys.toList();

      return SmoothCustomScrollView(
        slivers: [
          sliverAppBar,
          SliverGridViewWithFixedItemHeight(
            delegate: SliverChildBuilderDelegate(childCount: length, (
              context,
              i,
            ) {
              if (widget.data.allFavoritesId != null) {
                if (i == 0) {
                  return _FolderTile(
                    name: "All".tl,
                    onTap: () =>
                        openFolder(widget.data.allFavoritesId!, "All".tl),
                  );
                } else {
                  i--;
                  return _FolderTile(
                    name: folders![keys[i]]!,
                    onTap: () => openFolder(keys[i], folders![keys[i]]!),
                    deleteFolder: widget.data.deleteFolder == null
                        ? null
                        : () => widget.data.deleteFolder!(keys[i]),
                    updateState: () => setState(() {
                      _loading = true;
                    }),
                  );
                }
              } else {
                return _FolderTile(
                  name: folders![keys[i]]!,
                  onTap: () => openFolder(keys[i], folders![keys[i]]!),
                  deleteFolder: widget.data.deleteFolder == null
                      ? null
                      : () => widget.data.deleteFolder!(keys[i]),
                  updateState: () => setState(() {
                    _loading = true;
                  }),
                );
              }
            }),
            maxCrossAxisExtent: 450,
            itemHeight: 52,
          ),
          if (widget.data.addFolder != null)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 60,
                width: double.infinity,
                child: Center(
                  child: TextButton(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Create a folder".tl),
                        const Icon(Icons.add, size: 18),
                      ],
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return _CreateFolderDialog(
                            widget.data,
                            () => setState(() {
                              _loading = true;
                            }),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      );
    }
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.name,
    required this.onTap,
    this.deleteFolder,
    this.updateState,
  });

  final String name;

  final Future<Res<bool>> Function()? deleteFolder;

  final void Function()? updateState;

  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: ClickInkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.folder,
                size: 28,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              if (deleteFolder != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onDeleteFolder(context),
                )
              else
                const Icon(Icons.arrow_right),
            ],
          ),
        ),
      ),
    );
  }

  void onDeleteFolder(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        bool loading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return ContentDialog(
              title: "Delete".tl,
              content: Text("Delete folder?".tl).paddingHorizontal(16),
              actions: [
                Button.filled(
                  isLoading: loading,
                  color: context.colorScheme.error,
                  onPressed: () async {
                    setState(() {
                      loading = true;
                    });
                    var res = await deleteFolder!();
                    if (res.success) {
                      context.showMessage(message: "Deleted".tl);
                      context.pop();
                      updateState?.call();
                    } else {
                      setState(() {
                        loading = false;
                      });
                      context.showMessage(message: res.errorMessage!);
                    }
                  },
                  child: Text("Confirm".tl),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CreateFolderDialog extends StatefulWidget {
  const _CreateFolderDialog(this.data, this.updateState);

  final FavoriteData data;

  final void Function() updateState;

  @override
  State<_CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<_CreateFolderDialog> {
  var controller = TextEditingController();
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: "Create a folder".tl,
      content: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: "name".tl,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
      actions: [
        Button.filled(
          isLoading: loading,
          onPressed: () {
            setState(() {
              loading = true;
            });
            widget.data.addFolder!(controller.text).then((b) {
              if (b.error) {
                context.showMessage(message: b.errorMessage!);
                setState(() {
                  loading = false;
                });
              } else {
                context.pop();
                context.showMessage(message: "Created successfully".tl);
                widget.updateState();
              }
            });
          },
          child: Text("Submit".tl),
        ),
      ],
    );
  }
}

class _FavoriteFolder extends StatefulWidget {
  const _FavoriteFolder(this.data, this.folderID, this.title);

  final FavoriteData data;

  final String folderID;

  final String title;

  @override
  State<_FavoriteFolder> createState() => _FavoriteFolderState();
}

class _FavoriteFolderState extends State<_FavoriteFolder> {
  final comicListKey = GlobalKey<ComicListState>();

  String? dateSeek;

  Future<void> _pickSeekDate() async {
    if (!_sourceSupportsDateSeek(widget.data.key)) return;
    final now = DateTime.now();
    final initial =
        dateSeek != null ? (DateTime.tryParse(dateSeek!) ?? now) : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(2007),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      dateSeek = _formatDateSeek(picked);
    });
    NetworkCacheManager().clear();
    comicListKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ComicList(
      key: comicListKey,
      enablePageStorage: true,
      leadingSliver: SliverAppbar(
        title: Text(widget.title),
        actions: [
          const FavoriteDisplayButton(),
          if (_sourceSupportsDateSeek(widget.data.key))
            Tooltip(
              message: "Jump to page".tl,
              child: IconButton(
                icon: const Icon(Icons.calendar_month),
                onPressed: _pickSeekDate,
              ),
            ),
          MenuButton(
            entries: [
              MenuEntry(
                icon: Icons.sync,
                text: "Convert to local".tl,
                onClick: () {
                  importNetworkFolder(
                    widget.data.key,
                    9999999,
                    widget.title,
                    widget.folderID,
                  );
                },
              ),
            ],
          ),
        ],
      ),
      errorLeading: Appbar(title: Text(widget.title)),
      loadPage: widget.data.loadComic == null
          ? null
          : (i) => widget.data.loadComic!(i, widget.folderID),
      loadNext: widget.data.loadNext == null
          ? null
          : (next) {
              var token = next;
              if (token == null && dateSeek != null) {
                token = '__seek__:$dateSeek';
              }
              return widget.data.loadNext!(token, widget.folderID);
            },
      menuBuilder: (comic) {
        return [
          MenuEntry(
            icon: Icons.delete_outline,
            text: "Remove".tl,
            onClick: () async {
              var res = await _deleteComic(
                comic.id,
                null,
                comic.sourceKey,
                comic.favoriteId,
              );
              if (res) {
                comicListKey.currentState!.remove(comic);
              }
            },
          ),
        ];
      },
      useFavoriteDisplaySettings: true,
    );
  }
}

