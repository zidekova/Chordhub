// Prevod obyčajného textu piesne (akordy nad textom) do formátu ChordPro.
class ChordProConverter {
  static final RegExp _tokenRegex = RegExp(r'\S+');
  static final RegExp _chordTokenRegex = RegExp(
    r'^(?:[A-H](?:[#b])?(?:[a-zA-Z0-9+°ø#b()\-]*)(?:/[A-H](?:[#b])?)?|N\.C\.)$',
    caseSensitive: false,
  );

  static String convertToChordPro(String input) {
    final normalized = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    final output = <String>[];

    var index = 0;
    while (index < lines.length) {
      final current = lines[index];

      if (_looksLikeChordLine(current)) {
        final hasNext = index + 1 < lines.length;
        if (hasNext) {
          final next = lines[index + 1];
          final nextIsChord = _looksLikeChordLine(next);
          final nextIsEmpty = next.trim().isEmpty;

          if (!nextIsChord && !nextIsEmpty) {
            output.add(_mergeChordAndLyricLine(current, next));
            index += 2;
            continue;
          }
        }

        output.add(_wrapChordLine(current));
        index += 1;
        continue;
      }

      output.add(current);
      index += 1;
    }

    return output.join('\n');
  }

  static bool _looksLikeChordLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    final matches = _tokenRegex.allMatches(trimmed).toList();
    if (matches.isEmpty) {
      return false;
    }

    for (final match in matches) {
      final token = match.group(0) ?? '';
      if (!_chordTokenRegex.hasMatch(token)) {
        return false;
      }
    }
    return true;
  }

  static String _mergeChordAndLyricLine(String chordLine, String lyricLine) {
    final chordMatches = _tokenRegex.allMatches(chordLine).toList();
    if (chordMatches.isEmpty) {
      return lyricLine;
    }

    final output = StringBuffer();
    var lyricCursor = 0;

    for (final match in chordMatches) {
      final chord = match.group(0) ?? '';
      final targetPosition = match.start.clamp(0, lyricLine.length);

      if (targetPosition > lyricCursor) {
        output.write(lyricLine.substring(lyricCursor, targetPosition));
      }

      output.write('[$chord]');
      lyricCursor = targetPosition;
    }

    if (lyricCursor < lyricLine.length) {
      output.write(lyricLine.substring(lyricCursor));
    }

    return output.toString();
  }

  static String _wrapChordLine(String line) {
    return line.replaceAllMapped(_tokenRegex, (match) {
      final token = match.group(0) ?? '';
      if (token.isEmpty) {
        return token;
      }
      return '[$token]';
    });
  }
}
