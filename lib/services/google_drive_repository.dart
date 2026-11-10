import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/song.dart';
import 'google_drive_auth.dart';
import 'song_repository.dart';

class GoogleDriveRoot {
  const GoogleDriveRoot({required this.path, required this.name});

  final String path;
  final String name;
}

class GoogleDriveRepository {
  GoogleDriveRepository._();

  static final GoogleDriveRepository instance = GoogleDriveRepository._();

  static const String _apiRoot = 'https://www.googleapis.com/drive/v3';
  static const String _uploadRoot =
      'https://www.googleapis.com/upload/drive/v3';
  static const String _folderMime = 'application/vnd.google-apps.folder';
  static const String _fileFields =
      'id,name,mimeType,md5Checksum,modifiedTime';

  final http.Client _client = http.Client();

  // Kontrolný súčet obsahu z času načítania, slúži na odhalenie súbežných úprav.
  final Map<String, String> _checksums = {};
  List<String> _subfolders = [];
  String? _rootItemId;
  String? _rootPath;

  String? get rootPath => _rootPath;

  Future<String?> initializeAuth(String clientId) {
    return GoogleDriveAuth.initialize(clientId);
  }

  Future<String?> signIn() => GoogleDriveAuth.signIn();

  Future<void> signOut() {
    _clearRoot();
    return GoogleDriveAuth.signOut();
  }

  /// Otvorí priečinok na Google Disku podľa odkazu (alebo priamo podľa ID).
  Future<GoogleDriveRoot> openSharedFolder(String folderUrl) async {
    final folderId = _extractFolderId(folderUrl);
    if (folderId == null) {
      throw Exception('Z odkazu sa nepodarilo zistiť ID priečinka Google Disku.');
    }

    final response = await _request(
      'GET',
      _apiUri('/files/${_segment(folderId)}', {
        'fields': 'id,name,mimeType',
      }),
      await GoogleDriveAuth.acquireToken(),
    );
    final item = _decodeJson(response) as Map<String, dynamic>;
    if (item['mimeType'] != _folderMime) {
      throw Exception('Odkaz neukazuje na priečinok Google Disku.');
    }

    _rootItemId = item['id'] as String;
    final name = item['name'] as String? ?? 'Google Disk';
    _rootPath = 'GoogleDrive/$name';
    _checksums.clear();
    _subfolders = [];
    return GoogleDriveRoot(path: _rootPath!, name: name);
  }

  Future<List<ProSongFile>> loadSongs() async {
    final rootItemId = _requiredRootItemId;
    final rootPath = _requiredRootPath;
    final songs = <ProSongFile>[];
    final folders = <String>{};
    _checksums.clear();

    Future<void> visit(String folderId, String relativeFolder) async {
      for (final item in await _children(folderId)) {
        final name = item['name'] as String?;
        final itemId = item['id'] as String?;
        if (name == null || itemId == null) continue;
        final relativePath =
            relativeFolder.isEmpty ? name : '$relativeFolder/$name';

        if (_isFolder(item)) {
          folders.add(relativePath);
          await visit(itemId, relativePath);
          continue;
        }

        if (!name.toLowerCase().endsWith('.pro')) continue;
        final path = '$rootPath/$relativePath';
        final bytes = await _download(itemId);
        final content = _decodeBytes(bytes);
        final song = ParsedSong.fromContent(
          content,
          fallbackTitle: SongRepository.basenameWithoutExtension(name),
        );
        songs.add(
          ProSongFile(
            path: path,
            title: song.title,
            subtitle: song.subtitle,
            content: content,
          ),
        );
        final checksum = item['md5Checksum'] as String?;
        if (checksum != null) _checksums[path] = checksum;
      }
    }

    await visit(rootItemId, '');
    _subfolders = folders.toList()..sort();
    SongRepository.sortSongs(songs);
    return songs;
  }

  List<String> getAllSubfolders() => List.unmodifiable(_subfolders);

  Future<void> saveSong(String path, String content) async {
    final item = await _findItem(path);
    final itemId = item['id'] as String;

    // Google Disk nepozná podmienku If-Match, preto pred zápisom porovnáme
    // kontrolný súčet s verziou, ktorú sme načítali.
    final knownChecksum = _checksums[path];
    final currentChecksum = item['md5Checksum'] as String?;
    if (knownChecksum != null &&
        currentChecksum != null &&
        knownChecksum != currentChecksum) {
      throw Exception(
        'Skladbu medzitým zmenil niekto iný. Obnov zoznam a skús to znova.',
      );
    }

    final response = await _request(
      'PATCH',
      _uploadUri('/files/${_segment(itemId)}', {
        'uploadType': 'media',
        'fields': _fileFields,
      }),
      await GoogleDriveAuth.acquireToken(),
      headers: const {'Content-Type': 'text/plain; charset=utf-8'},
      bodyBytes: utf8.encode(content),
    );
    final updated = _decodeJson(response) as Map<String, dynamic>;
    final newChecksum = updated['md5Checksum'] as String?;
    if (newChecksum != null) _checksums[path] = newChecksum;
  }

  Future<void> createSong(String path, String content) async {
    final relativePath = _relative(path);
    final separator = relativePath.lastIndexOf('/');
    final fileName =
        separator < 0 ? relativePath : relativePath.substring(separator + 1);
    final relativeParent =
        separator < 0 ? '' : relativePath.substring(0, separator);
    final parentId = await _resolveFolder(relativeParent);
    await _assertNameFree(parentId, fileName);
    await _createFile(parentId, fileName, utf8.encode(content));
  }

  Future<void> createFolder(String relativePath) async {
    final segments = _pathSegments(relativePath);
    if (segments.isEmpty) throw ArgumentError('Názov priečinka je prázdny.');
    final name = segments.removeLast();
    final parentId = await _resolveFolder(segments.join('/'));
    await _assertNameFree(parentId, name);
    await _createFolderItem(parentId, name);
  }

  Future<void> renameFolder(String relativePath, String newName) async {
    final segments = _pathSegments(relativePath);
    final item = await _findRelativeItem(relativePath);
    segments.removeLast();
    final parentId = await _resolveFolder(segments.join('/'));
    await _assertNameFree(parentId, newName);
    await _request(
      'PATCH',
      _apiUri('/files/${_segment(item['id'] as String)}'),
      await GoogleDriveAuth.acquireToken(),
      headers: const {'Content-Type': 'application/json'},
      bodyBytes: utf8.encode(jsonEncode({'name': newName})),
    );
  }

  Future<void> deleteFolder(String relativePath) async {
    final item = await _findRelativeItem(relativePath);
    await _trash(item['id'] as String);
  }

  Future<void> deleteSong(String path) async {
    final item = await _findItem(path);
    await _trash(item['id'] as String);
    _checksums.remove(path);
  }

  Future<String> copySong(String sourcePath, String targetFolder) async {
    final source = await _findItem(sourcePath);
    final sourceName = source['name'] as String;
    final baseName = SongRepository.basenameWithoutExtension(sourceName);
    final extension = sourceName.substring(sourceName.lastIndexOf('.'));
    final targetFolderId = await _ensureFolder(targetFolder);
    final existingNames = {
      for (final item in await _children(targetFolderId))
        (item['name'] as String).toLowerCase(),
    };
    var fileName = sourceName;
    var counter = 1;
    while (existingNames.contains(fileName.toLowerCase())) {
      fileName = '${baseName}_copy$counter$extension';
      counter++;
    }

    final bytes = await _download(source['id'] as String);
    final targetPath =
        '$_requiredRootPath/'
        '${_join(targetFolder, fileName)}';
    await _createFile(targetFolderId, fileName, bytes);
    return targetPath;
  }

  Future<void> duplicateFolder(
    String sourceRelative,
    String targetRelative,
  ) async {
    final source = await _findRelativeItem(sourceRelative);
    final targetSegments = _pathSegments(targetRelative);
    final targetName = targetSegments.removeLast();
    final targetParent = await _resolveFolder(targetSegments.join('/'));
    await _assertNameFree(targetParent, targetName);
    final targetId = await _createFolderItem(targetParent, targetName);
    await _copyChildren(source['id'] as String, targetId);
  }

  Future<void> _copyChildren(String sourceId, String targetId) async {
    for (final item in await _children(sourceId)) {
      final name = item['name'] as String;
      if (_isFolder(item)) {
        final folderId = await _createFolderItem(targetId, name);
        await _copyChildren(item['id'] as String, folderId);
      } else {
        final bytes = await _download(item['id'] as String);
        await _createFile(targetId, name, bytes);
      }
    }
  }

  Future<Map<String, dynamic>> _findItem(String path) {
    return _findRelativeItem(_relative(path));
  }

  Future<Map<String, dynamic>> _findRelativeItem(String relativePath) async {
    final segments = _pathSegments(relativePath);
    if (segments.isEmpty) {
      throw ArgumentError('Koreňový priečinok nie je súborová položka.');
    }
    var parentId = _requiredRootItemId;
    Map<String, dynamic>? found;
    for (final segment in segments) {
      found = null;
      for (final item in await _children(parentId)) {
        if ((item['name'] as String?) == segment) {
          found = item;
          break;
        }
      }
      if (found == null) {
        throw Exception('Položka už na Google Disku neexistuje.');
      }
      parentId = found['id'] as String;
    }
    return found!;
  }

  Future<String> _resolveFolder(String relativePath) async {
    var itemId = _requiredRootItemId;
    for (final segment in _pathSegments(relativePath)) {
      Map<String, dynamic>? found;
      for (final item in await _children(itemId)) {
        if (item['name'] == segment && _isFolder(item)) {
          found = item;
          break;
        }
      }
      if (found == null) throw Exception('Priečinok "$segment" neexistuje.');
      itemId = found['id'] as String;
    }
    return itemId;
  }

  Future<String> _ensureFolder(String relativePath) async {
    var itemId = _requiredRootItemId;
    for (final segment in _pathSegments(relativePath)) {
      final children = await _children(itemId);
      Map<String, dynamic>? folder;
      for (final item in children) {
        if ((item['name'] as String?)?.toLowerCase() == segment.toLowerCase()) {
          if (!_isFolder(item)) {
            throw Exception('Položka "$segment" nie je priečinok.');
          }
          folder = item;
          break;
        }
      }

      itemId =
          folder != null
              ? folder['id'] as String
              : await _createFolderItem(itemId, segment);
    }
    return itemId;
  }

  /// Google Disk dovolí viac položiek s rovnakým názvom, preto to kontrolujeme sami.
  Future<void> _assertNameFree(String parentId, String name) async {
    final lower = name.toLowerCase();
    for (final item in await _children(parentId)) {
      if ((item['name'] as String?)?.toLowerCase() == lower) {
        throw Exception('Položka "$name" už existuje.');
      }
    }
  }

  Future<String> _createFolderItem(String parentId, String name) async {
    final response = await _request(
      'POST',
      _apiUri('/files', {'fields': 'id'}),
      await GoogleDriveAuth.acquireToken(),
      headers: const {'Content-Type': 'application/json'},
      bodyBytes: utf8.encode(
        jsonEncode({
          'name': name,
          'mimeType': _folderMime,
          'parents': [parentId],
        }),
      ),
    );
    final created = _decodeJson(response) as Map<String, dynamic>;
    return created['id'] as String;
  }

  /// Vytvorí súbor jedným multipart požiadavkou (metadáta + obsah),
  /// takže pri chybe nezostane na Disku prázdny súbor.
  Future<void> _createFile(
    String parentId,
    String fileName,
    List<int> bytes,
  ) async {
    const boundary = 'chordhub_boundary_7f3a9c';
    final metadata = jsonEncode({
      'name': fileName,
      'parents': [parentId],
    });
    final body = <int>[
      ...utf8.encode(
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadata\r\n'
        '--$boundary\r\n'
        'Content-Type: application/octet-stream\r\n\r\n',
      ),
      ...bytes,
      ...utf8.encode('\r\n--$boundary--'),
    ];

    final response = await _request(
      'POST',
      _uploadUri('/files', {'uploadType': 'multipart', 'fields': _fileFields}),
      await GoogleDriveAuth.acquireToken(),
      headers: const {'Content-Type': 'multipart/related; boundary=$boundary'},
      bodyBytes: body,
    );
    _decodeJson(response);
  }

  /// Presun do koša (obnoviteľný), nie trvalé zmazanie.
  Future<void> _trash(String itemId) async {
    await _request(
      'PATCH',
      _apiUri('/files/${_segment(itemId)}'),
      await GoogleDriveAuth.acquireToken(),
      headers: const {'Content-Type': 'application/json'},
      bodyBytes: utf8.encode(jsonEncode({'trashed': true})),
    );
  }

  Future<List<Map<String, dynamic>>> _children(String folderId) async {
    final items = <Map<String, dynamic>>[];
    String? pageToken;
    do {
      final response = await _request(
        'GET',
        _apiUri('/files', {
          'q': "'$folderId' in parents and trashed = false",
          'fields': 'nextPageToken,files($_fileFields)',
          'pageSize': '1000',
          'includeItemsFromAllDrives': 'true',
          if (pageToken != null) 'pageToken': pageToken,
        }),
        await GoogleDriveAuth.acquireToken(),
      );
      final data = _decodeJson(response) as Map<String, dynamic>;
      for (final item in (data['files'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()) {
        // Google Dokumenty, Tabuľky a odkazy nemajú stiahnuteľný obsah.
        final mime = item['mimeType'] as String? ?? '';
        if (mime.startsWith('application/vnd.google-apps.') &&
            mime != _folderMime) {
          continue;
        }
        items.add(item);
      }
      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null);
    return items;
  }

  Future<List<int>> _download(String itemId) async {
    final response = await _request(
      'GET',
      _apiUri('/files/${_segment(itemId)}', {'alt': 'media'}),
      await GoogleDriveAuth.acquireToken(),
      headers: const {'Accept': '*/*'},
    );
    return response.bodyBytes;
  }

  Future<http.Response> _request(
    String method,
    Uri uri,
    String token, {
    Map<String, String> headers = const {},
    List<int>? bodyBytes,
  }) async {
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        ...headers,
      });
    if (bodyBytes != null) request.bodyBytes = bodyBytes;
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = response.reasonPhrase ?? 'chyba Google Drive API';
      try {
        final data = jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        message =
            ((data['error'] as Map<String, dynamic>?)?['message'] as String?) ??
            message;
      } catch (_) {}
      throw Exception('Google Disk: $message (${response.statusCode})');
    }
    return response;
  }

  Uri _apiUri(String path, [Map<String, String> query = const {}]) =>
      Uri.parse('$_apiRoot$path').replace(
        queryParameters: {'supportsAllDrives': 'true', ...query},
      );

  Uri _uploadUri(String path, [Map<String, String> query = const {}]) =>
      Uri.parse('$_uploadRoot$path').replace(
        queryParameters: {'supportsAllDrives': 'true', ...query},
      );

  /// Akceptuje odkaz typu https://drive.google.com/drive/folders/<ID>?usp=sharing,
  /// odkaz s parametrom ?id=<ID>, alebo samotné ID.
  String? _extractFolderId(String input) {
    final value = input.trim();
    if (value.isEmpty) return null;

    final folderMatch = RegExp(r'/folders/([A-Za-z0-9_-]+)').firstMatch(value);
    if (folderMatch != null) return folderMatch.group(1);

    final idMatch = RegExp(r'[?&]id=([A-Za-z0-9_-]+)').firstMatch(value);
    if (idMatch != null) return idMatch.group(1);

    if (RegExp(r'^[A-Za-z0-9_-]{10,}$').hasMatch(value)) return value;
    return null;
  }

  bool _isFolder(Map<String, dynamic> item) => item['mimeType'] == _folderMime;

  Object? _decodeJson(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  String _relative(String path) {
    final normalizedPath = path.replaceAll('\\', '/');
    final root = _requiredRootPath.replaceAll('\\', '/');
    if (normalizedPath != root && !normalizedPath.startsWith('$root/')) {
      throw ArgumentError('Súbor nepatrí do aktuálneho priečinka Google Disku.');
    }
    return normalizedPath == root
        ? ''
        : normalizedPath.substring(root.length + 1);
  }

  List<String> _pathSegments(String path) =>
      path
          .replaceAll('\\', '/')
          .split('/')
          .where((segment) => segment.isNotEmpty)
          .toList();

  String _join(String first, String second) =>
      first.isEmpty
          ? second
          : second.isEmpty
          ? first
          : '$first/$second';

  String _segment(String value) => Uri.encodeComponent(value);

  String _decodeBytes(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  void _clearRoot() {
    _rootItemId = null;
    _rootPath = null;
    _checksums.clear();
    _subfolders = [];
  }

  String get _requiredRootItemId =>
      _rootItemId ??
      (throw StateError('Najprv pripoj priečinok Google Disku.'));
  String get _requiredRootPath =>
      _rootPath ?? (throw StateError('Najprv pripoj priečinok Google Disku.'));
}
