// Práca so súborovým systémom: načítanie, ukladanie a triedenie skladieb (.pro súbory).
import 'dart:convert';
import 'dart:io';

import '../models/song.dart';

class SongRepository {
  static Future<List<ProSongFile>> loadFromFolder(String folderPath) async {
    final directory = Directory(folderPath);
    if (!directory.existsSync()) {
      throw Exception('Priečinok neexistuje.');
    }

    final files =
        directory
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((file) => file.path.toLowerCase().endsWith('.pro'))
            .toList();

    final songs = <ProSongFile>[];
    for (final file in files) {
      final content = await _readFileText(file);
      final parsedSong = ParsedSong.fromContent(
        content,
        fallbackTitle: basenameWithoutExtension(file.path),
      );
      songs.add(
        ProSongFile(
          path: file.path,
          title: parsedSong.title,
          subtitle: parsedSong.subtitle,
          content: content,
        ),
      );
    }

    sortSongs(songs);
    return songs;
  }

  static void sortSongs(List<ProSongFile> songs) {
    songs.sort(compareSongTitlesSk);
  }

  static int compareSongTitlesSk(ProSongFile a, ProSongFile b) {
    final aKey = _slovakSortKey(a.title);
    final bKey = _slovakSortKey(b.title);
    final primary = aKey.compareTo(bKey);
    if (primary != 0) {
      return primary;
    }
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  static String _slovakSortKey(String value) {
    final lower = value.toLowerCase().trim();
    if (lower.isEmpty) {
      return lower;
    }

    final replacements = {
      'á': 'a',
      'ä': 'a',
      'č': 'c',
      'ď': 'd',
      'é': 'e',
      'ě': 'e',
      'í': 'i',
      'ĺ': 'l',
      'ľ': 'l',
      'ň': 'n',
      'ó': 'o',
      'ô': 'o',
      'ŕ': 'r',
      'š': 's',
      'ť': 't',
      'ú': 'u',
      'ů': 'u',
      'ý': 'y',
      'ž': 'z',
    };

    final key = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      key.write(replacements[char] ?? char);
    }
    return key.toString();
  }

  static Future<void> saveSong(String path, String content) {
    return File(path).writeAsString(content, flush: true);
  }

  static Future<String> _readFileText(File file) async {
    final bytes = await file.readAsBytes();
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  static String basename(String fullPath) {
    final normalized = fullPath.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isEmpty ? fullPath : parts.last;
  }

  static String basenameWithoutExtension(String fullPath) {
    final fileName = basename(fullPath);
    final extensionIndex = fileName.lastIndexOf('.');
    if (extensionIndex <= 0) {
      return fileName;
    }
    return fileName.substring(0, extensionIndex);
  }

  static List<String> getAllSubfolders(String rootPath) {
    final directory = Directory(rootPath);
    if (!directory.existsSync()) return [];

    return directory
        .listSync(recursive: true, followLinks: false)
        .whereType<Directory>()
        .map((dir) {
          var rel = dir.path.replaceAll('\\', '/');
          var base = rootPath.replaceAll('\\', '/');
          if (rel.startsWith(base)) {
            rel = rel.substring(base.length).trimLeft();
            if (rel.startsWith('/')) rel = rel.substring(1);
          }
          return rel;
        })
        .where((path) => path.isNotEmpty)
        .toList();
  }
}
