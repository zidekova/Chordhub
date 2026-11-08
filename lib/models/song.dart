// Dátové modely piesne: súbor s piesňou, spracovaná pieseň a jej riadky s akordami.
import '../utils/inline_markup_parser.dart';
import '../utils/chord_transposer.dart';

class ProSongFile {
  ProSongFile({
    required this.path,
    required this.title,
    required this.subtitle,
    required this.content,
  });

  final String path;
  String title;
  String? subtitle;
  String content;
}

class ParsedSong {
  ParsedSong({
    required this.title,
    required this.subtitle,
    required this.lines,
    required this.scrollSpeed,
    this.bpm,
  });

  final String title;
  final String? subtitle;
  final List<String> lines;
  final double scrollSpeed;
  final int? bpm;

  static ParsedSong fromContent(
    String content, {
    required String fallbackTitle,
  }) {
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final allLines = normalized.split('\n');
    String title = fallbackTitle;
    String? subtitle;
    var scrollSpeed = 16.0;
    int? bpm;
    for (final line in allLines) {
      final directive = tryParseDirective(line);
      if (directive != null &&
          directive.key == 'title' &&
          directive.value != null) {
        final value = directive.value!.trim();
        if (value.isNotEmpty) {
          title = value;
        }
      }
      if (directive != null &&
          directive.key == 'subtitle' &&
          directive.value != null) {
        final value = directive.value!.trim();
        if (value.isNotEmpty) {
          subtitle ??= value;
        }
      }
      if (directive != null &&
          directive.key == 'scrollspeed' &&
          directive.value != null) {
        final raw = directive.value!.trim();
        var cleaned = raw.toLowerCase();
        if (cleaned.endsWith('px')) {
          cleaned = cleaned.substring(0, cleaned.length - 2).trim();
        }
        final parsed = double.tryParse(cleaned);
        if (parsed != null && parsed > 0) {
          scrollSpeed = parsed;
        }
      }
      if (directive != null &&
          directive.key == 'bpm' &&
          directive.value != null) {
        var raw = directive.value!.trim().toLowerCase();
        // allow values like "120", "120bpm", "120 bpm"
        raw = raw.replaceAll('bpm', '').trim();
        // remove any non-numeric/postfix chars
        final parsedDouble = double.tryParse(raw);
        if (parsedDouble != null && parsedDouble > 0) {
          bpm = parsedDouble.round();
        }
      }
    }

    return ParsedSong(
      title: title,
      subtitle: subtitle,
      lines: allLines,
      scrollSpeed: scrollSpeed,
      bpm: bpm,
    );
  }

  static ChordProDirective? tryParseDirective(String line) {
    final trimmed = line.trim();
    final match = RegExp(
      r'^\{([a-zA-Z0-9_]+)(?::\s*(.*))?\}$',
    ).firstMatch(trimmed);
    if (match == null) {
      return null;
    }
    return ChordProDirective(
      key: match.group(1)!.toLowerCase(),
      value: match.group(2)?.trim(),
    );
  }
}

class ChordProDirective {
  ChordProDirective({required this.key, this.value});

  final String key;
  final String? value;
}

class RenderedChordLine {
  RenderedChordLine({
    required this.chordPlacements,
    required this.lyricLineRaw,
    required this.lyricLinePlain,
  });

  final List<ChordPlacement> chordPlacements;
  final String lyricLineRaw;
  final String lyricLinePlain;

  static RenderedChordLine fromRaw(
    String rawLine, {
    required int transposeSemitones,
  }) {
    final chordRegex = RegExp(r'\[([^\]]+)\]');
    final lyricBuffer = StringBuffer();
    final positions = <ChordPlacement>[];

    var searchStart = 0;
    var lyricPosition = 0;
    for (final match in chordRegex.allMatches(rawLine)) {
      final lyricChunk = rawLine.substring(searchStart, match.start);
      lyricBuffer.write(lyricChunk);
      lyricPosition += InlineMarkupParser.visibleLength(lyricChunk);

      final originalChord = match.group(1) ?? '';
      final transposed = ChordTransposer.transposeChord(
        originalChord,
        transposeSemitones,
      );
      positions.add(ChordPlacement(position: lyricPosition, chord: transposed));
      searchStart = match.end;
    }

    final trailingChunk = rawLine.substring(searchStart);
    lyricBuffer.write(trailingChunk);
    final lyricRaw = lyricBuffer.toString();
    final lyricPlain = InlineMarkupParser.toPlainText(lyricRaw);

    return RenderedChordLine(
      chordPlacements: positions,
      lyricLineRaw: lyricRaw,
      lyricLinePlain: lyricPlain,
    );
  }
}

class ChordPlacement {
  ChordPlacement({required this.position, required this.chord});

  final int position;
  final String chord;
}

class SongDisplayLine {
  SongDisplayLine({required this.rawLine, required this.isChorus});

  final String rawLine;
  final bool isChorus;
}

