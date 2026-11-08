// Pomocník na skladanie zvýrazneného textu (soh/eoh/c: značky) v texte piesne.
import 'package:flutter/material.dart';

class InlineMarkupParser {
  static final RegExp _tokenRegex = RegExp(r'\{(soh|eoh|c:\s*[^}]*)\}');

  static int visibleLength(String input) {
    return toPlainText(input).length;
  }

  static String toPlainText(String input) {
    final buffer = StringBuffer();
    var cursor = 0;

    for (final match in _tokenRegex.allMatches(input)) {
      buffer.write(input.substring(cursor, match.start));
      final token = match.group(1)?.trim() ?? '';
      if (token.toLowerCase().startsWith('c:')) {
        buffer.write(token.substring(2).trimLeft());
      }
      cursor = match.end;
    }

    buffer.write(input.substring(cursor));
    return buffer.toString();
  }

  static List<TextSpan> toStyledSpans(
    BuildContext context,
    String input, {
    required bool inChorus,
  }) {
    final baseStyle = TextStyle(
      fontFamily: 'monospace',
      color: Theme.of(context).colorScheme.onSurface,
    );
    final highlightStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.primary,
    );
    final commentStyle = baseStyle.copyWith(
      fontStyle: FontStyle.italic,
      color:
          inChorus
              ? Theme.of(context).colorScheme.onSecondaryContainer
              : Theme.of(context).colorScheme.tertiary,
    );

    final spans = <TextSpan>[];
    var cursor = 0;
    var highlightEnabled = false;

    void appendText(String text, {TextStyle? style}) {
      if (text.isEmpty) {
        return;
      }
      spans.add(TextSpan(text: text, style: style));
    }

    for (final match in _tokenRegex.allMatches(input)) {
      final before = input.substring(cursor, match.start);
      appendText(before, style: highlightEnabled ? highlightStyle : baseStyle);

      final token = match.group(1)?.trim() ?? '';
      final lower = token.toLowerCase();
      if (lower == 'soh') {
        highlightEnabled = true;
      } else if (lower == 'eoh') {
        highlightEnabled = false;
      } else if (lower.startsWith('c:')) {
        final comment = token.substring(2).trimLeft();
        appendText(comment, style: commentStyle);
      }
      cursor = match.end;
    }

    final trailing = input.substring(cursor);
    appendText(trailing, style: highlightEnabled ? highlightStyle : baseStyle);

    return spans;
  }
}

