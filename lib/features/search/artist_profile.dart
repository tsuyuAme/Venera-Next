import 'dart:async';
import 'dart:io';

import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/opencc.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';

/// Namespaces that identify a work rather than describe its content.
///
/// Tags like `artist:michiking`, `language:translated` or `group:xxx`
/// appear on almost every work by the same artist, so they carry no
/// information about the artist's style and are dropped during analysis.
const _kMetadataNamespaces = {
  'artist',
  'authors',
  'group',
  'language',
  'parody',
  'series',
  'character',
  'characters',
  'uploader',
  'tag',
  'tags',
  'source',
  'category',
  'categories',
  'year',
  'date',
  'time',
  'magazine',
  'publisher',
};

/// Format-like content tags that carry no artist-specific information.
///
/// These appear on nearly every work regardless of the artist, so they are
/// always dropped during analysis. Tune this list from the daily log.
const _kIgnoredContentTags = {
  '同人',
  '同人誌',
  'doujinshi',
  'doujin',
  'sole male',
  'sole female',
};

/// Synonym dictionary mapping foreign/raw tags to canonical Chinese words.
///
/// e-Hentai tags are English while other sources may give the same meaning
/// in Chinese; mapping them to one canonical word lets frequencies merge
/// instead of being diluted. Tune this list from the daily log.
/// Custom synonym overrides for tags the built-in translation database
/// (EhTagTranslation, ~34k entries loaded at startup) does not cover well.
///
/// This takes precedence over the translation database, so it is the place
/// for cross-source canonical words and better translations. Tune from the
/// daily analysis log.
const _kTagSynonyms = {
  'korean': '韓漫', // translation db says 韩语 (language); 韓漫 is the content sense
  'oneshot': '单本',
  'short story': '短篇',
  'school uniform': '校服',
  'tentacle': '触手',
  'pantyhose': '丝袜', // translation db value is a mixed-lang string
  'yaoi': '耽美',
};

String _normalizeTagSynonym(String tag, {String? namespace}) {
  var lowered = tag.toLowerCase();
  var custom = _kTagSynonyms[lowered];
  if (custom != null) return custom;
  if (namespace != null) {
    var translated = TagsTranslation.translationTagWithNamespace(
      lowered,
      namespace,
    );
    if (translated != lowered && translated.isNotEmpty) return translated;
  }
  var global = lowered.translateTagsToCN;
  return global == lowered ? tag : global;
}

/// Converts [text] to simplified Chinese when OpenCC is available.
///
/// Falls back to the original text when OpenCC has not been initialized
/// (e.g. in unit tests).
String _toSimplified(String text) {
  try {
    if (OpenCC.hasChineseTraditional(text)) {
      return OpenCC.traditionalToSimplified(text);
    }
  } catch (_) {
    // OpenCC not initialized yet; keep the original text.
  }
  return text;
}

/// Merges simplified/traditional variants of the same tag, keeping the
/// higher count only (counts are NOT summed).
///
/// Summing would double-count works that are present on several sources
/// in different script forms, inflating tag frequencies.
Map<String, int> mergeSimplifiedVariants(
  Map<String, int> counts,
  String Function(String) toSimplified,
) {
  var result = <String, int>{};
  counts.forEach((tag, count) {
    var key = _stripDecoration(tag);
    key = toSimplified(key);
    var existing = result[key];
    if (existing == null || count > existing) {
      result[key] = count;
    }
  });
  return result;
}

/// Removes emoji and decorative symbols from a tag.
///
/// The EhTagTranslation database decorates some entries with emoji (e.g.
/// `眼镜👓`), which would otherwise split a tag into two keys and break
/// simplified/traditional merging.
String _stripDecoration(String text) {
  var buffer = StringBuffer();
  for (var rune in text.runes) {
    var isDecoration = (rune >= 0x1F000 && rune <= 0x1FAFF) ||
        (rune >= 0x2600 && rune <= 0x27BF) ||
        (rune >= 0xFE00 && rune <= 0xFE0F) ||
        rune == 0x200D ||
        rune == 0x200B;
    if (isDecoration) continue;
    buffer.writeCharCode(rune);
  }
  return buffer.toString();
}

/// Normalizes one raw source tag for artist profile analysis.
///
/// - Trims and rejects empty, URL-like and over-long entries.
/// - Strips the namespace prefix (`female:big breasts` -> `big breasts`)
///   because the value alone reads better in the UI.
/// - Drops metadata namespaces defined in [_kMetadataNamespaces].
String? sanitizeArtistTag(String raw) {
  var t = raw.trim();
  if (t.isEmpty || t.length > 30 || t.contains('http')) return null;
  var colon = t.indexOf(':');
  if (colon > 0) {
    var ns = t.substring(0, colon).trim().toLowerCase();
    var value = t.substring(colon + 1).trim();
    if (value.isEmpty || value.length > 30) return null;
    if (_kMetadataNamespaces.contains(ns)) return null;
    // Check the ignored list against the value too: e-Hentai stores
    // `male:sole male`, and only after stripping the prefix does the
    // value match an ignored content tag.
    if (_kIgnoredContentTags.contains(value)) return null;
    return _normalizeTagSynonym(value, namespace: ns);
  }
  if (_kIgnoredContentTags.contains(t)) return null;
  return _normalizeTagSynonym(t);
}

/// Picks the most frequent content tags from search results.
///
/// Empty strings, URLs, metadata namespaces and over-long entries are
/// ignored. Ties are ordered alphabetically so the result is deterministic.
List<String> topArtistTags(List<Comic> comics, {int limit = 8}) {
  var counts = <String, int>{};
  for (var comic in comics) {
    for (var tag in comic.tags ?? const <String>[]) {
      var t = sanitizeArtistTag(tag);
      if (t == null) continue;
      counts[t] = (counts[t] ?? 0) + 1;
    }
  }
  return topArtistTagsFromCounts(counts, limit: limit);
}

/// Cached artist profile: top tags generated by [analyzeArtistProfile].
Map<String, dynamic>? getArtistProfile(String name) {
  var raw = appdata.settings['artistProfiles'];
  if (raw is! Map) return null;
  var value = raw[name];
  if (value is! Map) return null;
  return Map<String, dynamic>.from(value);
}

void setArtistProfile(String name, List<String> tags) {
  var raw = appdata.settings['artistProfiles'];
  var map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  map[name] = {
    'tags': tags,
    'updatedAt': DateTime.now().millisecondsSinceEpoch,
  };
  appdata.settings['artistProfiles'] = map;
  unawaited(appdata.saveData());
}

void removeArtistProfile(String name) {
  var raw = appdata.settings['artistProfiles'];
  if (raw is! Map) return;
  var map = Map<String, dynamic>.from(raw)..remove(name);
  appdata.settings['artistProfiles'] = map;
  unawaited(appdata.saveData());
}

/// Maximum number of pages fetched per source during profile analysis.
const _kMaxProfilePages = 5;

/// Extra attempts when a source returns nothing or throws (network hiccups).
const _kMaxAnalysisRetries = 2;

/// Maximum number of comics collected per source during analysis.
const _kMaxProfileComics = 50;

/// Normalizes a comic title for cross-source deduplication.
String normalizeComicTitle(String title) {
  return title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// Removes duplicate works across sources by normalized title.
///
/// The same work is often available on several sources with slightly
/// different formatting; counting its tags twice would skew frequencies.
List<Comic> dedupeComicsByTitle(List<Comic> comics) {
  var seen = <String>{};
  var result = <Comic>[];
  for (var comic in comics) {
    var key = normalizeComicTitle(comic.title);
    if (key.isEmpty || seen.add(key)) {
      result.add(comic);
    }
  }
  return result;
}

/// Writes one analysis record into a per-day log file.
///
/// The log is stored at `<dataPath>/logs/artist_analysis_YYYY-MM-DD.log`
/// and each run appends: per-source work counts, raw tag frequencies,
/// filtered frequencies and the final result, so tag rules can be tuned
/// from real data.
Future<void> _writeAnalysisLog(
  String name, {
  required Map<String, int> perSourceComics,
  required int totalComics,
  required Map<String, int> rawTagCounts,
  required Map<String, int> filteredTagCounts,
  required List<String> result,
}) async {
  try {
    // Log goes next to the app executable (software directory),
    // not into %APPDATA%, so it is easy to find during tuning.
    var exeDir = File(Platform.resolvedExecutable).parent.path;
    var dir = Directory('$exeDir/logs');
    await dir.create(recursive: true);
    var now = DateTime.now();
    var date = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    var file = File('${dir.path}/artist_analysis_$date.log');

    String top(Map<String, int> counts, int limit) {
      var entries = counts.entries.toList()
        ..sort((a, b) {
          var byCount = b.value.compareTo(a.value);
          if (byCount != 0) return byCount;
          return a.key.compareTo(b.key);
        });
      return entries
          .take(limit)
          .map((e) => '${e.key}(${e.value})')
          .join(', ');
    }

    var buffer = StringBuffer()
      ..writeln('========== ${now.toIso8601String()} 画师「$name」 ==========')
      ..writeln('各源作品数: '
          '${perSourceComics.entries.map((e) => '${e.key}: ${e.value}').join(', ')}')
      ..writeln('作品总数 (去重后): $totalComics')
      ..writeln('原始标签频次 (top 30): ${top(rawTagCounts, 30)}')
      ..writeln('过滤后标签频次 (top 30): ${top(filteredTagCounts, 30)}')
      ..writeln('最终结果: ${result.join('、')}')
      ..writeln('');

    await file.writeAsString(buffer.toString(), mode: FileMode.append);
  } catch (e) {
    // Logging must never break analysis.
  }
}

/// Ranks [counts] by frequency (ties alphabetical) and takes the top [limit].
List<String> topArtistTagsFromCounts(
  Map<String, int> counts, {
  int limit = 8,
}) {
  var merged = mergeSimplifiedVariants(counts, _toSimplified);
  var entries = merged.entries.toList()
    ..sort((a, b) {
      var byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return a.key.compareTo(b.key);
    });
  return entries.take(limit).map((e) => e.key).toList();
}

/// Collects works of [name] from one source with default search options.
///
/// Pages up to [_kMaxProfilePages] / [_kMaxProfileComics] works and truncates
/// to the limit. Returns whatever was fetched before a page error; the whole
/// fetch throws only on unexpected failures so the caller can retry.
Future<List<Comic>> _collectFromSource(
  SearchPageData search,
  String name,
  List<String> options,
) async {
  var sourceComics = <Comic>[];
  if (search.loadPage != null) {
    var page = 1;
    while (sourceComics.length < _kMaxProfileComics &&
        page <= _kMaxProfilePages) {
      var res = await search.loadPage!(name, page, options);
      if (res.error) break;
      sourceComics.addAll(res.dataOrNull ?? const []);
      var maxPage = res.subData;
      if (maxPage is! int || page >= maxPage) break;
      page += 1;
    }
  } else if (search.loadNext != null) {
    String? next;
    for (var i = 0;
        i < _kMaxProfilePages && sourceComics.length < _kMaxProfileComics;
        i++) {
      var res = await search.loadNext!(name, next, options);
      if (res.error) break;
      var list = res.dataOrNull ?? const <Comic>[];
      if (list.isEmpty) break;
      sourceComics.addAll(list);
      next = res.subData as String?;
      if (next == null) break;
    }
  }
  if (sourceComics.length > _kMaxProfileComics) {
    sourceComics = sourceComics.sublist(0, _kMaxProfileComics);
  }
  return sourceComics;
}

/// Collects [name]'s works from one source with retry + backoff.
///
/// Returns whatever the source yields after up to [_kMaxAnalysisRetries]
/// extra attempts; empty on persistent failure.
Future<List<Comic>> _collectWithRetry(
  SearchPageData search,
  String name,
) async {
  var options = (search.searchOptions ?? const <SearchOptions>[])
      .map((e) => e.defaultValue)
      .toList();
  var sourceComics = <Comic>[];
  for (var attempt = 0; attempt <= _kMaxAnalysisRetries; attempt++) {
    try {
      sourceComics = await _collectFromSource(search, name, options);
      if (sourceComics.isNotEmpty) break;
    } catch (e) {
      sourceComics = const <Comic>[];
    }
    if (attempt < _kMaxAnalysisRetries) {
      // Short backoff so a network hiccup can recover.
      await Future.delayed(Duration(milliseconds: 600 * (attempt + 1)));
    }
  }
  return sourceComics;
}

/// Searches [name] across all sources and returns the top content tags.
///
/// Uses the same default search options and page numbering as the aggregated
/// search page, then keeps paging to gather more works for a more reliable
/// tag distribution. Every run also appends a record to the per-day
/// analysis log for tuning. A failing source or exhausted pages do not
/// block others.
Future<List<String>> analyzeArtistProfile(String name) async {
  // Fetch all sources in parallel (network-bound); each source keeps its
  // own retry/backoff internally.
  var sources = ComicSource.all().where((s) => s.searchPageData != null);
  var results = await Future.wait(
    sources.map(
      (source) async => MapEntry(
        source.key,
        await _collectWithRetry(source.searchPageData!, name),
      ),
    ),
  );
  var comics = <Comic>[];
  var perSourceComics = <String, int>{};
  for (var entry in results) {
    comics.addAll(entry.value);
    perSourceComics[entry.key] = entry.value.length;
  }
  comics = dedupeComicsByTitle(comics);

  var rawCounts = <String, int>{};
  var filteredCounts = <String, int>{};
  for (var comic in comics) {
    for (var tag in comic.tags ?? const <String>[]) {
      var t = tag.trim();
      if (t.isEmpty || t.length > 30 || t.contains('http')) continue;
      rawCounts[t] = (rawCounts[t] ?? 0) + 1;
      var sanitized = sanitizeArtistTag(t);
      if (sanitized != null) {
        filteredCounts[sanitized] = (filteredCounts[sanitized] ?? 0) + 1;
      }
    }
  }
  var result = topArtistTagsFromCounts(filteredCounts);

  await _writeAnalysisLog(
    name,
    perSourceComics: perSourceComics,
    totalComics: comics.length,
    rawTagCounts: rawCounts,
    filteredTagCounts: filteredCounts,
    result: result,
  );

  return result;
}

/// Analyzes [name] and caches the profile. Returns the tags (or cached).
Future<List<String>> analyzeAndSaveArtist(String name) async {
  try {
    var tags = await analyzeArtistProfile(name);
    if (tags.isNotEmpty) {
      setArtistProfile(name, tags);
      return tags;
    }
  } catch (e) {
    // Fall through to cached profile.
  }
  return getArtistProfile(name)?['tags'] as List<String>? ?? const [];
}

/// Analyzes [name] in the background and caches the profile.
///
/// Silent: failures and empty results are ignored so background auto
/// analysis never interrupts the user. Skips artists that already have a
/// cached profile.
Future<void> autoAnalyzeArtist(String name) async {
  if (getArtistProfile(name) != null) return;
  await analyzeAndSaveArtist(name);
}

/// Maximum artists running profile analysis concurrently.
const _kAllAnalysisConcurrency = 2;

/// Re-analyzes every artist in [names] with [concurrency] parallel workers.
///
/// Unlike [autoAnalyzeArtist] this ignores existing cached profiles, so it
/// is the "scrape everything" entry point. Completes when all artists are
/// done; individual failures are silent.
Future<void> analyzeAllArtists(
  List<String> names, {
  int concurrency = _kAllAnalysisConcurrency,
}) async {
  if (concurrency < 1) concurrency = 1;
  for (var start = 0; start < names.length; start += concurrency) {
    var batch = names.sublist(
      start,
      start + concurrency > names.length ? names.length : start + concurrency,
    );
    await Future.wait(batch.map(analyzeAndSaveArtist));
  }
}
