import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/search/search.dart';

void main() {
  test('groupArtistShortcuts keeps only authors and merges by name', () {
    const shortcuts = [
      SearchShortcut(
        kind: SearchShortcutKind.author,
        sourceKey: 'source-a',
        namespace: 'artist',
        value: 'Same Name',
      ),
      SearchShortcut(
        kind: SearchShortcutKind.author,
        sourceKey: 'source-b',
        namespace: 'author',
        value: 'Same Name',
      ),
      SearchShortcut(
        kind: SearchShortcutKind.author,
        sourceKey: 'source-a',
        namespace: 'artist',
        value: 'Another Artist',
      ),
      SearchShortcut(
        kind: SearchShortcutKind.tag,
        sourceKey: 'source-a',
        namespace: 'artist',
        value: 'Same Name',
      ),
    ];

    final grouped = groupArtistShortcuts(shortcuts);

    expect(grouped, hasLength(2));
    expect(grouped['Same Name'], {'source-a', 'source-b'});
    expect(grouped['Another Artist'], {'source-a'});
  });

  test('groupArtistShortcuts preserves favorite insertion order', () {
    const shortcuts = [
      SearchShortcut(
        kind: SearchShortcutKind.author,
        sourceKey: 'source-a',
        namespace: 'artist',
        value: 'First',
      ),
      SearchShortcut(
        kind: SearchShortcutKind.author,
        sourceKey: 'source-a',
        namespace: 'artist',
        value: 'Second',
      ),
    ];

    expect(groupArtistShortcuts(shortcuts).keys.toList(), ['First', 'Second']);
  });

  test('groupArtistShortcuts handles empty input', () {
    expect(groupArtistShortcuts(const []), isEmpty);
  });


  test('topArtistTags ranks by frequency and filters junk', () {
    Comic comic(String id, List<String> tags) => Comic(
          'title-$id',
          'cover',
          id,
          null,
          tags,
          '',
          'src',
          null,
          null,
        );

    final comics = [
      comic('a', ['校园', '恋爱', '黑白']),
      comic('b', ['校园', '恋爱']),
      comic('c', ['校园', 'https://example.com/x.jpg', '', '  ']),
      comic('d', ['校园', '恋爱', '恋爱', '校园']),
    ];

    final top = topArtistTags(comics);

    expect(top.first, '校园');
    expect(top, contains('恋爱'));
    expect(top, isNot(contains('https://example.com/x.jpg')));
    expect(top, isNot(contains('')));
  });

  test('topArtistTags returns empty for no usable tags', () {
    Comic comic(String id, List<String> tags) => Comic(
          'title-$id',
          'cover',
          id,
          null,
          tags,
          '',
          'src',
          null,
          null,
        );

    expect(topArtistTags(const []), isEmpty);
    expect(
      topArtistTags([comic('a', ['', 'http://x.y']) ]),
      isEmpty,
    );
  });

  test('topArtistTags limits count', () {
    Comic comic(String id, List<String> tags) => Comic(
          'title-$id',
          'cover',
          id,
          null,
          tags,
          '',
          'src',
          null,
          null,
        );

    final comics = [
      for (var i = 0; i < 8; i++)
        comic('c$i', ['tag1', 'tag2', 'tag3', 'tag4', 'tag5', 'tag6', 'tag7', 'tag8', 'tag9']),
    ];

    expect(topArtistTags(comics).length, 8);
  });


  test('sanitizeArtistTag strips namespace and drops metadata tags', () {
    // translation db is loaded at app startup only; unit test sees passthrough
    expect(sanitizeArtistTag('female:big breasts'), 'big breasts');
    expect(sanitizeArtistTag('artist:michiking'), isNull);
    expect(sanitizeArtistTag('language:translated'), isNull);
    expect(sanitizeArtistTag('group:anmitsuyomogitei'), isNull);
    expect(sanitizeArtistTag('parody:original work'), isNull);
    expect(sanitizeArtistTag('同人'), isNull);
    expect(sanitizeArtistTag('同人誌'), isNull);
    expect(sanitizeArtistTag('doujinshi'), isNull);
    expect(sanitizeArtistTag('sole male'), isNull);
    expect(sanitizeArtistTag('male:sole male'), isNull);
    expect(sanitizeArtistTag('sole female'), isNull);
    expect(sanitizeArtistTag('  '), isNull);
    expect(sanitizeArtistTag('korean'), '韓漫');
    expect(sanitizeArtistTag('language:korean'), isNull);
    expect(sanitizeArtistTag('pantyhose'), '丝袜');
    expect(sanitizeArtistTag('https://x.y/z'), isNull);
  });

  test('topArtistTags excludes metadata namespaces in raw results', () {
    Comic comic(String id, List<String> tags) => Comic(
          'title-$id',
          'cover',
          id,
          null,
          tags,
          '',
          'src',
          null,
          null,
        );

    final comics = [
      comic('a', ['artist:michiking', 'female:big breasts', '同人']),
      comic('b', ['artist:michiking', 'language:translated', 'female:big breasts']),
      comic('c', ['group:xxx', 'same name']),
      comic('d', ['same name']),
    ];

    final top = topArtistTags(comics);

    expect(top, isNot(contains('artist:michiking')));
    expect(top, isNot(contains('language:translated')));
    expect(top, isNot(contains('group:xxx')));
    expect(top, contains('big breasts'));
  });


  test('dedupeComicsByTitle merges the same work across sources', () {
    Comic comic(String id, String title) => Comic(
          title,
          'cover',
          id,
          null,
          const ['same tag'],
          '',
          'src',
          null,
          null,
        );

    final deduped = dedupeComicsByTitle([
      comic('a1', 'Test Work'),
      comic('a2', '  test work  '),
      comic('b1', 'Test Work'),
      comic('c1', 'Another Work'),
      comic('d1', '  '),
    ]);

    // 4 non-empty, but "Test Work" x3 collapses into 1
    expect(deduped, hasLength(3));
    expect(
      deduped.map((c) => c.id).toSet(),
      {'a1', 'c1', 'd1'},
    );
  });

  test('normalizeComicTitle trims and lowercases consistently', () {
    expect(normalizeComicTitle('  Hello   World  '), 'hello world');
    expect(normalizeComicTitle('HELLO WORLD'), 'hello world');
  });


  test('mergeSimplifiedVariants keeps higher count, never sums', () {
    // fake converter: 韓 -> 韩 (simplified), 連 -> 连
    String toSimplified(String t) {
      return t
          .replaceAll('韓', '韩')
          .replaceAll('連', '连')
          .replaceAll('襪', '袜');
    }

    final merged = mergeSimplifiedVariants(
      {
        '韓漫': 8, // traditional, appears on source A
        '韩漫': 5, // simplified, same tag on source B
        '連褲襪': 3,
        '连裤袜': 9,
        '单本': 12,
      },
      toSimplified,
    );

    expect(merged['韩漫'], 8); // higher count kept, NOT 13
    expect(merged['连裤袜'], 9); // higher count kept, NOT 12
    expect(merged['单本'], 12); // untouched
  });
}
