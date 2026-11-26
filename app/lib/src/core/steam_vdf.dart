/// A conservative KeyValues reader which edits token spans instead of
/// serializing the document. Steam's unknown keys, whitespace and comments
/// therefore survive an account switch byte for byte (after UTF-8 decoding).
class SteamVdfDocument {
  SteamVdfDocument._(this.source, this.root);

  factory SteamVdfDocument.parse(String source) {
    final parser = _Parser(source);
    return SteamVdfDocument._(source, parser.parse());
  }

  final String source;
  final SteamVdfObject root;
  final Map<SteamVdfEntry, String> _replacements = {};
  final Map<SteamVdfObject, Map<String, String>> _insertions = {};

  /// Case-insensitive lookup rejects duplicates rather than choosing a record
  /// Steam might interpret differently.
  SteamVdfEntry? entry(SteamVdfObject object, String key) {
    final matches = object.entries.where(
      (entry) => entry.key.toLowerCase() == key.toLowerCase(),
    );
    if (matches.length > 1) {
      throw const FormatException('Ambiguous duplicate VDF key');
    }
    return matches.firstOrNull;
  }

  SteamVdfObject? object(SteamVdfObject parent, String key) {
    final found = entry(parent, key);
    if (found == null) return null;
    if (found.object == null) {
      throw const FormatException('Expected VDF object');
    }
    return found.object;
  }

  String? string(SteamVdfObject parent, String key) {
    final found = entry(parent, key);
    if (found == null) return null;
    if (found.value == null) {
      throw const FormatException('Expected VDF string');
    }
    return found.value;
  }

  void setString(SteamVdfObject parent, String key, String value) {
    final found = entry(parent, key);
    if (found != null) {
      if (found.value == null) {
        throw const FormatException('Expected VDF string');
      }
      if (found.value != value) _replacements[found] = _quote(value);
    } else {
      (_insertions[parent] ??= {})[key] = value;
    }
  }

  String render() {
    final patches = <_Patch>[
      for (final edit in _replacements.entries)
        _Patch(edit.key.valueStart, edit.key.valueEnd, edit.value),
      for (final edit in _insertions.entries)
        _Patch(
          edit.key.closeOffset,
          edit.key.closeOffset,
          edit.value.entries
              .map((e) => '\n\t\t${_quote(e.key)}\t\t${_quote(e.value)}\n')
              .join(),
        ),
    ]..sort((a, b) => b.start.compareTo(a.start));
    var result = source;
    for (final patch in patches) {
      result = result.replaceRange(patch.start, patch.end, patch.text);
    }
    return result;
  }

  static String _quote(String value) =>
      '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\n').replaceAll('\r', '\\r').replaceAll('\t', '\\t')}"';
}

class SteamVdfObject {
  SteamVdfObject._(this.entries, this.closeOffset);
  final List<SteamVdfEntry> entries;
  final int closeOffset;
}

class SteamVdfEntry {
  SteamVdfEntry._(
    this.key,
    this.value,
    this.object,
    this.valueStart,
    this.valueEnd,
  );
  final String key;
  final String? value;
  final SteamVdfObject? object;
  final int valueStart;
  final int valueEnd;
}

class _Patch {
  const _Patch(this.start, this.end, this.text);
  final int start;
  final int end;
  final String text;
}

class _Token {
  const _Token(this.text, this.start, this.end, {this.brace = false});
  final String text;
  final int start;
  final int end;
  final bool brace;
}

class _Parser {
  _Parser(this.source);
  final String source;
  int offset = 0;

  SteamVdfObject parse() => _object(0, false);

  SteamVdfObject _object(int depth, bool nested) {
    if (depth > 128) throw const FormatException('VDF nesting too deep');
    final entries = <SteamVdfEntry>[];
    while (true) {
      final key = _next();
      if (key == null) {
        if (nested) throw const FormatException('Unclosed VDF object');
        return SteamVdfObject._(entries, source.length);
      }
      if (key.brace && key.text == '}') {
        if (!nested) throw const FormatException('Unexpected VDF brace');
        return SteamVdfObject._(entries, key.start);
      }
      if (key.brace || key.text.startsWith('#') || key.text.startsWith('[')) {
        throw const FormatException('Unsupported VDF structure');
      }
      final value = _next();
      if (value == null || (value.brace && value.text != '{')) {
        throw const FormatException('Missing VDF value');
      }
      if (value.brace) {
        final child = _object(depth + 1, true);
        entries.add(
          SteamVdfEntry._(key.text, null, child, value.start, offset),
        );
      } else {
        entries.add(
          SteamVdfEntry._(key.text, value.text, null, value.start, value.end),
        );
      }
    }
  }

  _Token? _next() {
    while (offset < source.length) {
      final c = source.codeUnitAt(offset);
      if (c <= 32 || (offset == 0 && c == 0xfeff)) {
        offset++;
      } else if (source.startsWith('//', offset)) {
        final end = source.indexOf('\n', offset + 2);
        offset = end == -1 ? source.length : end + 1;
      } else if (source.startsWith('/*', offset)) {
        final end = source.indexOf('*/', offset + 2);
        if (end == -1) throw const FormatException('Unclosed VDF comment');
        offset = end + 2;
      } else {
        break;
      }
    }
    if (offset == source.length) return null;
    final start = offset;
    final first = source[offset++];
    if (first == '{' || first == '}') {
      return _Token(first, start, offset, brace: true);
    }
    if (first == '"') {
      final text = StringBuffer();
      while (offset < source.length) {
        final c = source[offset++];
        if (c == '"') return _Token(text.toString(), start, offset);
        if (c != '\\') {
          text.write(c);
          continue;
        }
        if (offset == source.length) break;
        final escaped = source[offset++];
        text.write(switch (escaped) {
          'n' => '\n',
          'r' => '\r',
          't' => '\t',
          '"' => '"',
          '\\' => '\\',
          _ => '\\$escaped',
        });
      }
      throw const FormatException('Unclosed VDF string');
    }
    while (offset < source.length &&
        source.codeUnitAt(offset) > 32 &&
        source[offset] != '{' &&
        source[offset] != '}') {
      offset++;
    }
    return _Token(source.substring(start, offset), start, offset);
  }
}
