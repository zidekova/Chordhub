// Transpozícia akordov (posun o pol tóny) a prevod ChordPro obsahu.
class ChordTransposer {
  static const List<String> _germanNotes = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'B',
    'H',
  ];

  static const Map<String, int> _noteIndex = {
    'C': 0,
    'B#': 0,
    'C#': 1,
    'DB': 1,
    'D': 2,
    'D#': 3,
    'EB': 3,
    'E': 4,
    'FB': 4,
    'F': 5,
    'E#': 5,
    'F#': 6,
    'GB': 6,
    'G': 7,
    'G#': 8,
    'AB': 8,
    'A': 9,
    'A#': 10,
    'BB': 10,
    'B': 11,
    'CB': 11,
    'H': 11,
    'HB': 10,
  };

  static String transposeChord(String chord, int semitones) {
    if (chord.trim().isEmpty) {
      return chord;
    }

    final parts = chord.split('/');
    final transposedParts =
        parts
            .map((part) => _transposeChordPart(part.trim(), semitones))
            .toList();
    return transposedParts.join('/');
  }

  static String transposeChordProContent(String content, int semitones) {
    if (semitones == 0 || content.isEmpty) {
      return content;
    }

    final chordRegex = RegExp(r'\[([^\]]+)\]');
    return content.replaceAllMapped(chordRegex, (match) {
      final originalChord = match.group(1) ?? '';
      final transposedChord = transposeChord(originalChord, semitones);
      return '[$transposedChord]';
    });
  }

  static String _transposeChordPart(String part, int semitones) {
    if (part.isEmpty) {
      return part;
    }

    final match = RegExp(r'^([A-GH])([b#]?)(.*)$').firstMatch(part);
    if (match == null) {
      return part;
    }

    final root = '${match.group(1)}${match.group(2) ?? ''}'.toUpperCase();
    final suffix = match.group(3) ?? '';
    final index = _noteIndex[root];
    if (index == null) {
      return part;
    }

    final normalizedShift = semitones % 12;
    final transposedIndex = (index + normalizedShift + 12) % 12;
    final transposedRoot = _germanNotes[transposedIndex];
    return '$transposedRoot$suffix';
  }
}

