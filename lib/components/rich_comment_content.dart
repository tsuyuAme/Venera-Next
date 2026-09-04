import 'dart:collection';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/image_provider/cached_image.dart';
import 'package:venera_next/routing/app_links.dart';
import 'package:venera_next/foundation/extensions.dart';
import 'package:venera_next/foundation/widget_utils.dart';

import 'gesture.dart';

/// A widget that displays comment content with support for rich text formatting.
///
/// This widget intelligently decides whether to use simple text or rich formatting
/// based on the content. It supports HTML tags and auto-linking of URLs.
class CommentContent extends StatelessWidget {
  const CommentContent({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (!text.contains('<') && !text.contains('http')) {
      return SelectableText(text);
    } else {
      return RichCommentContent(text: text);
    }
  }
}

class _Tag {
  final String name;
  final Map<String, String> attributes;

  const _Tag(this.name, this.attributes);

  TextSpan merge(TextSpan s, BuildContext context) {
    var style = s.style ?? ts;
    style = switch (name) {
      'b' => style.bold,
      'i' => style.italic,
      'u' => style.underline,
      's' => style.lineThrough,
      'a' => style.withColor(context.colorScheme.primary),
      'strong' => style.bold,
      'span' => () {
        if (attributes.containsKey('style')) {
          var s = attributes['style']!;
          var css = s.split(';');
          for (var c in css) {
            var kv = c.split(':');
            if (kv.length == 2) {
              var key = kv[0].trim();
              var value = kv[1].trim();
              switch (key) {
                case 'color':
                  break;
                case 'font-weight':
                  if (value == 'bold') {
                    style = style.bold;
                  } else if (value == 'lighter') {
                    style = style.light;
                  }
                  break;
                case 'font-style':
                  if (value == 'italic') {
                    style = style.italic;
                  }
                  break;
                case 'text-decoration':
                  if (value == 'underline') {
                    style = style.underline;
                  } else if (value == 'line-through') {
                    style = style.lineThrough;
                  }
                  break;
                case 'font-size':
                  break;
              }
            }
          }
        }
        return style;
      }(),
      _ => style,
    };
    if (style.color != null) {
      style = style.copyWith(decorationColor: style.color);
    }
    // Link taps are applied in writeBuffer via WidgetSpan — do not use
    // TapGestureRecognizer here (unreliable inside horizontal ListViews).
    return TextSpan(text: s.text, style: style);
  }

  /// Turn EH-style relative / protocol-relative hrefs into absolute https URLs.
  static String? resolveHref(String? href) {
    if (href == null) return null;
    var link = href.trim();
    if (link.isEmpty ||
        link.startsWith('#') ||
        link.toLowerCase().startsWith('javascript:')) {
      return null;
    }
    if (link.startsWith('//')) {
      link = 'https:$link';
    } else if (link.startsWith('/')) {
      link = 'https://e-hentai.org$link';
    }
    if (link.isURL) return link;
    if (RegExp(
      r'^https?://(e-|ex)hentai\.org/',
      caseSensitive: false,
    ).hasMatch(link)) {
      return link;
    }
    return null;
  }

  static Future<void> handleLink(String link) async {
    final resolved = resolveHref(link) ?? (link.isURL ? link : null);
    if (resolved == null) return;
    final uri = Uri.tryParse(resolved);
    if (uri == null) return;
    if (await handleAppLink(uri)) {
      // Close comments side sheet / dialog if one is open on root.
      Navigator.of(App.rootContext).maybePop();
      return;
    }
    try {
      await launchUrlString(resolved);
    } catch (_) {}
  }

  /// Tappable link that wins against parent horizontal scroll gestures.
  static InlineSpan linkSpan(String text, String url, TextStyle style) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          handleLink(url);
        },
        child: Text(
          text,
          style: style.copyWith(
            color: style.color,
            decoration: TextDecoration.underline,
            decorationColor: style.color,
          ),
        ),
      ),
    );
  }
}

class _CommentImage {
  final String url;
  final String? link;

  const _CommentImage(this.url, this.link);
}

class RichCommentContent extends StatefulWidget {
  const RichCommentContent({
    super.key,
    required this.text,
    this.showImages = true,
    this.selectable = true,
  });

  final String text;

  final bool showImages;

  /// Prefer false inside horizontal lists so link taps are not stolen by
  /// [SelectableText] / parent scroll gesture arenas.
  final bool selectable;

  @override
  State<RichCommentContent> createState() => _RichCommentContentState();
}

class _RichCommentContentState extends State<RichCommentContent> {
  var textSpan = <InlineSpan>[];
  var images = <_CommentImage>[];
  bool isRendered = false;

  @override
  void didChangeDependencies() {
    if (!isRendered) {
      render();
      isRendered = true;
    }
    super.didChangeDependencies();
  }

  bool isValidUrlChar(String char) {
    return RegExp(r'[a-zA-Z0-9%:/.@\-_?&=#*!+;~]').hasMatch(char);
  }

  void render() {
    var s = Queue<_Tag>();

    int i = 0;
    var buffer = StringBuffer();
    var text = widget.text;
    text = text.replaceAll('\r\n', '\n');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');

    void writeBuffer() {
      if (buffer.isEmpty) return;
      final raw = buffer.toString();
      buffer.clear();
      var span = TextSpan(text: raw);
      for (var tag in s) {
        span = tag.merge(span, context);
      }
      // If inside <a href=...>, emit a real GestureDetector (WidgetSpan).
      String? anchorUrl;
      for (final tag in s) {
        if (tag.name == 'a') {
          anchorUrl = _Tag.resolveHref(tag.attributes['href']);
        }
      }
      if (anchorUrl != null) {
        textSpan.add(
          _Tag.linkSpan(
            span.text ?? raw,
            anchorUrl,
            span.style ??
                DefaultTextStyle.of(context).style.copyWith(
                      color: context.colorScheme.primary,
                    ),
          ),
        );
      } else {
        textSpan.add(span);
      }
    }

    while (i < text.length) {
      if (text[i] == '<' && i != text.length - 1) {
        if (text[i + 1] != '/') {
          // open tag
          var j = i + 1;
          for (; j < text.length; j++) {
            if (text[j] == '>') break;
          }
          if (j == text.length) {
            buffer.write(text[i]);
            i++;
            continue;
          }
          var tagContent = text.substring(i + 1, j);
          var splits = tagContent.split(' ');
          var tagName = splits[0].toLowerCase();
          var attributes = <String, String>{};
          for (var k = 1; k < splits.length; k++) {
            var attr = splits[k];
            var kv = attr.split('=');
            if (kv.length == 2) {
              attributes[kv[0]] = kv[1].replaceAll('"', '').replaceAll("'", '');
            }
          }
          if (tagName == 'br') {
            writeBuffer();
            buffer.write('\n');
            i = j + 1;
            continue;
          }
          if (tagName == 'img') {
            writeBuffer();
            var url = attributes['src'];
            String? link;
            if (s.isNotEmpty && s.last.name == 'a') {
              link = s.last.attributes['href'];
            }
            if (url != null) {
              images.add(_CommentImage(url, link));
            }
            i = j + 1;
            continue;
          }
          writeBuffer();
          s.add(_Tag(tagName, attributes));
          i = j + 1;
          continue;
        } else {
          // close tag
          var j = i + 2;
          for (; j < text.length; j++) {
            if (text[j] == '>') break;
          }
          if (j != text.length) {
            var tagContent = text.substring(i + 2, j);
            var splits = tagContent.split(' ');
            var tagName = splits[0].toLowerCase();
            if (s.isNotEmpty && s.last.name == tagName) {
              writeBuffer();
              s.removeLast();
              i = j + 1;
              continue;
            }
            if (tagName == 'br') {
              i = j + 1;
              buffer.write('\n');
              continue;
            }
          }
        }
      } else if (text.length - i > 8 &&
          text.substring(i, i + 4).toLowerCase() == 'http' &&
          !s.any((e) => e.name == 'a')) {
        // auto link plain URLs
        int j = i;
        for (; j < text.length; j++) {
          if (!isValidUrlChar(text[j])) {
            break;
          }
        }
        // trim trailing punctuation often glued onto URLs
        while (j > i && '.,;:!?）)】》"\''.contains(text[j - 1])) {
          j--;
        }
        var url = text.substring(i, j);
        final resolved = _Tag.resolveHref(url) ?? (url.isURL ? url : null);
        if (resolved != null) {
          writeBuffer();
          textSpan.add(
            _Tag.linkSpan(
              url,
              resolved,
              ts.withColor(context.colorScheme.primary),
            ),
          );
          i = j;
          continue;
        }
      }
      buffer.write(text[i]);
      i++;
    }
    writeBuffer();
  }

  @override
  Widget build(BuildContext context) {
    final span = TextSpan(
      style: DefaultTextStyle.of(context).style,
      children: textSpan,
    );
    // WidgetSpan links do not work inside SelectableText — force Text.rich
    // whenever we might have links (non-selectable path always; selectable
    // only if no WidgetSpan children — we always use Text.rich for safety
    // when selectable is false).
    // SelectableText does not handle WidgetSpan taps; use Text.rich whenever
    // any link WidgetSpan is present (typical for EH gallery URLs).
    final hasLinkWidgets = textSpan.any((s) => s is WidgetSpan);
    Widget content = (widget.selectable && !hasLinkWidgets)
        ? SelectableText.rich(span)
        : Text.rich(span);
    if (images.isNotEmpty && widget.showImages) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          content,
          Wrap(
            runSpacing: 4,
            spacing: 4,
            children: images.map((e) {
              Widget image = Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                ),
                width: 100,
                height: 100,
                child: Image(
                  width: 100,
                  height: 100,
                  image: CachedImageProvider(e.url),
                ),
              );
              if (e.link != null) {
                image = ClickInkWell(
                  onTap: () {
                    _Tag.handleLink(e.link!);
                  },
                  child: image,
                );
              }
              return image;
            }).toList(),
          ),
        ],
      );
    }
    return content;
  }
}
