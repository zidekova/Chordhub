// Zobrazenie jedného riadku textu piesne spolu s akordami umiestnenými nad textom.
import 'package:flutter/material.dart';

import '../models/song.dart';
import '../utils/inline_markup_parser.dart';

class _VisualChord {
  const _VisualChord({required this.chord, required this.left});

  final String chord;
  final double left;
}

class ChordLineView extends StatelessWidget {
  const ChordLineView({
    required this.line,
    required this.inChorus,
    required this.transposeSemitones,
    this.fontScale = 1.0,
    super.key,
  });

  final String line;
  final bool inChorus;
  final int transposeSemitones;
  final double fontScale;

  @override
  Widget build(BuildContext context) {
    final rendered = RenderedChordLine.fromRaw(
      line,
      transposeSemitones: transposeSemitones,
    );

    if (rendered.chordPlacements.isEmpty && rendered.lyricLinePlain.isEmpty) {
      return SizedBox(height: 10 * fontScale);
    }

    final chordTextStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 14 * fontScale,
      color:
          inChorus
              ? Theme.of(context).colorScheme.onSecondaryContainer
              : Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
      height: 1.15,
    );

    final lyricTextStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 14 * fontScale,
      color: Theme.of(context).colorScheme.onSurface,
      height: 1.15,
    );

    final chordRowHeight = (chordTextStyle.fontSize ?? 14) * 1.2;
    final visualChords = _buildVisualChords(
      context,
      rendered,
      lyricTextStyle,
      chordTextStyle,
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (visualChords.isNotEmpty)
          SizedBox(
            height: chordRowHeight,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                for (final chord in visualChords)
                  Positioned(
                    left: chord.left,
                    top: 0,
                    child: Text(
                      chord.chord,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: chordTextStyle,
                    ),
                  ),
              ],
            ),
          ),
        RichText(
          softWrap: false,
          overflow: TextOverflow.clip,
          text: TextSpan(
            style: lyricTextStyle,
            children: InlineMarkupParser.toStyledSpans(
              context,
              rendered.lyricLineRaw,
              inChorus: inChorus,
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 8 * fontScale),
      child:
          inChorus
              ? Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: 6 * fontScale,
                  vertical: 2 * fontScale,
                ),
                child: content,
              )
              : content,
    );
  }

  List<_VisualChord> _buildVisualChords(
    BuildContext context,
    RenderedChordLine rendered,
    TextStyle lyricStyle,
    TextStyle chordStyle,
  ) {
    if (rendered.chordPlacements.isEmpty) {
      return [];
    }

    final sorted = [...rendered.chordPlacements]
      ..sort((a, b) => a.position.compareTo(b.position));

    final output = <_VisualChord>[];
    final minGap = _measureTextWidth(context, ' ', lyricStyle) * 1.5;
    var previousRight = -1000000.0;

    for (final placement in sorted) {
      final preferredLeft = _measureLyricPrefixWidth(
        context,
        rendered.lyricLinePlain,
        placement.position,
        lyricStyle,
      );
      final chordWidth = _measureTextWidth(
        context,
        placement.chord,
        chordStyle,
      );

      var left = preferredLeft;
      final minLeft = previousRight + minGap;
      if (left < minLeft) {
        left = minLeft;
      }

      output.add(_VisualChord(chord: placement.chord, left: left));
      previousRight = left + chordWidth;
    }

    return output;
  }

  double _measureLyricPrefixWidth(
    BuildContext context,
    String lyricPlain,
    int chordPosition,
    TextStyle lyricStyle,
  ) {
    final safePosition = chordPosition.clamp(0, lyricPlain.length);
    final prefix = lyricPlain.substring(0, safePosition);
    if (prefix.isEmpty) {
      return 0;
    }

    final textPainter = TextPainter(
      text: TextSpan(text: prefix, style: lyricStyle),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();

    return textPainter.width;
  }

  double _measureTextWidth(BuildContext context, String text, TextStyle style) {
    if (text.isEmpty) {
      return 0;
    }

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();

    return textPainter.width;
  }
}

