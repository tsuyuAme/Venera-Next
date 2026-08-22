import 'package:flutter_test/flutter_test.dart';
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
        comic('c$i', ['tag1', 'tag2', 'tag3', 'tag4', 'tag5', 'tag6', 'tag7']),
    ];

    expect(topArtistTags(comics).length, 5);
  });
}
