// Generovanie jednoduchého .docx dokumentu s playlistom (zoznamom skladieb podľa kôl).
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class PlaylistEntry {
  const PlaylistEntry({required this.title, this.bpm})
    : isRoundSeparator = false;

  const PlaylistEntry.roundSeparator()
    : title = '------------------',
      bpm = null,
      isRoundSeparator = true;

  final String title;
  final int? bpm;
  final bool isRoundSeparator;
}

class WordPlaylistBuilder {
  static Uint8List build({
    required String folderTitle,
    required List<PlaylistEntry> entries,
  }) {
    final documentXml = _buildDocumentXml(folderTitle, entries);

    final archive = Archive();
    archive.addFile(_textFile('[Content_Types].xml', _contentTypesXml));
    archive.addFile(_textFile('_rels/.rels', _relsXml));
    archive.addFile(_textFile('word/document.xml', documentXml));

    final zipped = ZipEncoder().encode(archive);
    if (zipped == null) {
      throw Exception('Nepodarilo sa vytvoriť .docx súbor.');
    }
    return Uint8List.fromList(zipped);
  }

  static ArchiveFile _textFile(String name, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(name, bytes.length, bytes);
  }

  static const String _contentTypesXml =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';

  static const String _relsXml =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

  static String _buildDocumentXml(
    String folderTitle,
    List<PlaylistEntry> entries,
  ) {
    final buffer =
        StringBuffer()
          ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
          ..write(
            '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">',
          )
          ..write('<w:body>');

    // Nadpis – názov priečinka, vycentrovaný, tučný, veľký (28pt).
    buffer
      ..write('<w:p><w:pPr><w:jc w:val="center"/></w:pPr>')
      ..write(
        '<w:r><w:rPr><w:b/><w:sz w:val="56"/><w:szCs w:val="56"/></w:rPr>'
        '<w:t xml:space="preserve">${_escape(folderTitle)}</w:t></w:r></w:p>',
      );

    buffer.write('<w:p/>'); // prázdny riadok pod nadpisom

    for (final entry in entries) {
      final label =
          entry.isRoundSeparator
              ? entry.title
              : (entry.bpm == null
                  ? entry.title
                  : '${entry.title} - ${entry.bpm}');
      buffer
        ..write('<w:p>')
        ..write(
          '<w:r><w:rPr><w:sz w:val="40"/><w:szCs w:val="40"/></w:rPr>'
          '<w:t xml:space="preserve">${_escape(label)}</w:t></w:r>',
        )
        ..write('</w:p>');
    }

    buffer
      ..write('<w:sectPr/>')
      ..write('</w:body></w:document>');
    return buffer.toString();
  }

  static String _escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
