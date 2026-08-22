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
}
