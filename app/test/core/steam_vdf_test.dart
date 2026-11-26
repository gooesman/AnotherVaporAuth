import 'package:ava/src/core/steam_vdf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('patches one token while preserving comments and unknown fields', () {
    const source =
        '\ufeff// original\r\n"uSeRs"\r\n{\r\n'
        '  "unknown" "keep \\\\ path \\"quoted\\"" /* note */\r\n'
        '  "MostRecent"  "0" // keep spacing\r\n}\r\n';
    final document = SteamVdfDocument.parse(source);
    final users = document.object(document.root, 'users')!;
    document.setString(users, 'mostrecent', '1');
    expect(document.render(), source.replaceFirst('"0"', '"1"'));
    expect(document.string(users, 'unknown'), 'keep \\ path "quoted"');
  });

  test('inserts missing flags without discarding an inline comment', () {
    const source = '"users" { "id" { "name" "test" // note\n } }';
    final document = SteamVdfDocument.parse(source);
    final record = document.object(
      document.object(document.root, 'users')!,
      'id',
    )!;
    document.setString(record, 'AutoLogin', '1');
    document.setString(record, 'AllowAutoLogin', '1');
    final rendered = document.render();
    expect(rendered, contains('"name" "test" // note\n'));
    final reread = SteamVdfDocument.parse(rendered);
    final updated = reread.object(reread.object(reread.root, 'users')!, 'id')!;
    expect(reread.string(updated, 'AutoLogin'), '1');
    expect(reread.string(updated, 'AllowAutoLogin'), '1');
  });

  test('handles escaped quotes, backslashes and unknown escapes', () {
    final document = SteamVdfDocument.parse(
      r'"root" { "text" "a\"b\\c\n\t\r\q" }',
    );
    final root = document.object(document.root, 'root')!;
    expect(document.string(root, 'text'), 'a"b\\c\n\t\r\\q');
    document.setString(root, 'text', 'a"b\\c\n\t\r\\q!');
    final reread = SteamVdfDocument.parse(document.render());
    expect(
      reread.string(reread.object(reread.root, 'root')!, 'text'),
      'a"b\\c\n\t\r\\q!',
    );
  });

  test('case-insensitive duplicate lookup fails closed', () {
    final document = SteamVdfDocument.parse('"users" {} "USERS" {}');
    expect(
      () => document.object(document.root, 'users'),
      throwsFormatException,
    );
  });

  test('does not confuse scalar and object fields', () {
    final document = SteamVdfDocument.parse('"root" { "flag" {} }');
    final root = document.object(document.root, 'root')!;
    expect(() => document.setString(root, 'flag', '1'), throwsFormatException);
  });

  for (final source in [
    '"users" {',
    '"users" }',
    '"users" { "id" "unterminated }',
    '/* unterminated',
    '#include "another.vdf"',
    '"users" {} [WIN32]',
  ]) {
    test('rejects malformed or conditional structure: $source', () {
      expect(() => SteamVdfDocument.parse(source), throwsFormatException);
    });
  }
}
