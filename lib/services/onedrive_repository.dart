import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/song.dart';
import 'onedrive_auth.dart';
import 'song_repository.dart';

class OneDriveRoot {
  const OneDriveRoot({required this.path, required this.name});

  final String path;
  final String name;
}

class OneDriveRepository {
  OneDriveRepository._();

  static final OneDriveRepository instance = OneDriveRepository._();

  static const String _graphRoot = 'https://graph.microsoft.com/v1.0';
  final http.Client _client = http.Client();
  final Map<String, String> _etags = {};
  List<String> _subfolders = [];
  String? _driveId;
  String? _rootItemId;
  String? _rootPath;

  String? get rootPath => _rootPath;

  Future<String?> initializeAuth(String clientId, String redirectUri) {
    return OneDriveAuth.initialize(clientId, redirectUri);
  }

  Future<String?> signIn() => OneDriveAuth.signIn();

  Future<void> signOut() {
    _clearRoot();
    return OneDriveAuth.signOut();
  }

  Future<OneDriveRoot> openSharedFolder(String sharingUrl) async {
    final token = await OneDriveAuth.acquireToken();
    final encoded = base64Url
        .encode(utf8.encode(sharingUrl))
        .replaceAll('=', '');
    final sharePath = '$_graphRoot/shares/u!$encoded';
    await _request(
      'GET',
      Uri.parse(sharePath),
      token,
      headers: const {'Prefer': 'redeemSharingLink'},
    );
    final response = await _request(
      'GET',
      Uri.parse('$sharePath/driveItem'),
      token,
    );
    final data = _decodeJson(response) as Map<String, dynamic>;
    final item = (data['remoteItem'] as Map<String, dynamic>?) ?? data;
    final parentReference =
        (item['parentReference'] as Map<String, dynamic>?) ??
        (data['parentReference'] as Map<String, dynamic>?);
    final driveId = parentReference?['driveId'] as String?;
    final itemId = item['id'] as String?;
    if (driveId == null || itemId == null || item['folder'] == null) {
      throw Exception('Zdieľaný odkaz neukazuje na priečinok OneDrive.');
    }

    _driveId = driveId;
    _rootItemId = itemId;
    final name = item['name'] as String? ?? 'OneDrive';
    _rootPath = 'OneDrive/$name';
    _etags.clear();
    _subfolders = [];
    return OneDriveRoot(path: _rootPath!, name: name);
  }

  Future<List<ProSongFile>> loadSongs() async {
    final driveId = _requiredDriveId;
    final rootItemId = _requiredRootItemId;
    final rootPath = _requiredRootPath;
    final songs = <ProSongFile>[];
    final folders = <String>{};
    _etags.clear();

    Future<void> visit(String folderId, String relativeFolder) async {
      for (final item in await _children(driveId, folderId)) {
        final name = item['name'] as String?;
        final itemId = item['id'] as String?;
        if (name == null || itemId == null) continue;
        final relativePath =
            relativeFolder.isEmpty ? name : '$relativeFolder/$name';

        if (item['folder'] != null) {
          folders.add(relativePath);
          await visit(itemId, relativePath);
          continue;
        }

        if (!name.toLowerCase().endsWith('.pro')) continue;
        final path = '$rootPath/$relativePath';
        final bytes = await _download(driveId, itemId);
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
        final etag = item['eTag'] as String?;
        if (etag != null) _etags[path] = etag;
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
    final etag = _etags[path] ?? item['eTag'] as String?;
    final headers = <String, String>{
      'Content-Type': 'text/plain; charset=utf-8',
    };
    if (etag != null) headers['If-Match'] = etag;

    final response = await _request(
      'PUT',
      _itemContentUri(_requiredDriveId, itemId),
      await OneDriveAuth.acquireToken(),
      headers: headers,
      bodyBytes: utf8.encode(content),
    );
    final updated = _decodeJson(response) as Map<String, dynamic>;
    final newEtag = updated['eTag'] as String?;
    if (newEtag != null) _etags[path] = newEtag;
  }

  Future<void> createSong(String path, String content) async {
    final relativePath = _relative(path);
    final separator = relativePath.lastIndexOf('/');
    final fileName =
        separator < 0 ? relativePath : relativePath.substring(separator + 1);
    final relativeParent =
        separator < 0 ? '' : relativePath.substring(0, separator);
    final parentId = await _resolveFolder(relativeParent);
    await _createFile(parentId, fileName, utf8.encode(content));
  }

  Future<void> createFolder(String relativePath) async {
    final segments = _pathSegments(relativePath);
    if (segments.isEmpty) throw ArgumentError('Názov priečinka je prázdny.');
    final name = segments.removeLast();
    final parentId = await _resolveFolder(segments.join('/'));
    await _request(
      'POST',
      _childrenUri(_requiredDriveId, parentId),
      await OneDriveAuth.acquireToken(),
      headers: const {'Content-Type': 'application/json'},
      bodyBytes: utf8.encode(
        jsonEncode({
          'name': name,
          'folder': <String, Object>{},
          '@microsoft.graph.conflictBehavior': 'fail',
        }),
      ),
    );
  }

  Future<void> renameFolder(String relativePath, String newName) async {
    final item = await _findRelativeItem(relativePath);
    await _request(
      'PATCH',
      _itemUri(_requiredDriveId, item['id'] as String),
      await OneDriveAuth.acquireToken(),
      headers: const {'Content-Type': 'application/json'},
      bodyBytes: utf8.encode(jsonEncode({'name': newName})),
    );
  }

  Future<void> deleteFolder(String relativePath) async {
    final item = await _findRelativeItem(relativePath);
    await _request(
      'DELETE',
      _itemUri(_requiredDriveId, item['id'] as String),
      await OneDriveAuth.acquireToken(),
    );
  }

  Future<void> deleteSong(String path) async {
    final item = await _findItem(path);
    await _request(
      'DELETE',
      _itemUri(_requiredDriveId, item['id'] as String),
      await OneDriveAuth.acquireToken(),
    );
    _etags.remove(path);
  }

  Future<String> copySong(String sourcePath, String targetFolder) async {
    final source = await _findItem(sourcePath);
    final sourceName = source['name'] as String;
    final baseName = SongRepository.basenameWithoutExtension(sourceName);
    final extension = sourceName.substring(sourceName.lastIndexOf('.'));
    final targetFolderId = await _ensureFolder(targetFolder);
    final existingNames = {
      for (final item in await _children(_requiredDriveId, targetFolderId))
        (item['name'] as String).toLowerCase(),
    };
    var fileName = sourceName;
    var counter = 1;
    while (existingNames.contains(fileName.toLowerCase())) {
      fileName = '${baseName}_copy$counter$extension';
      counter++;
    }

    final bytes = await _download(_requiredDriveId, source['id'] as String);
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
    final created = await _request(
      'POST',
      _childrenUri(_requiredDriveId, targetParent),
      await OneDriveAuth.acquireToken(),
      headers: const {'Content-Type': 'application/json'},
      bodyBytes: utf8.encode(
        jsonEncode({
          'name': targetName,
          'folder': <String, Object>{},
          '@microsoft.graph.conflictBehavior': 'fail',
        }),
      ),
    );
    final target = _decodeJson(created) as Map<String, dynamic>;
    await _copyChildren(source['id'] as String, target['id'] as String);
  }

  Future<void> _copyChildren(String sourceId, String targetId) async {
    for (final item in await _children(_requiredDriveId, sourceId)) {
      final name = item['name'] as String;
      if (item['folder'] != null) {
        final created = await _request(
          'POST',
          _childrenUri(_requiredDriveId, targetId),
          await OneDriveAuth.acquireToken(),
          headers: const {'Content-Type': 'application/json'},
          bodyBytes: utf8.encode(
            jsonEncode({'name': name, 'folder': <String, Object>{}}),
          ),
        );
        final folder = _decodeJson(created) as Map<String, dynamic>;
        await _copyChildren(item['id'] as String, folder['id'] as String);
      } else {
        final bytes = await _download(_requiredDriveId, item['id'] as String);
        await _request(
          'PUT',
          Uri.parse(
            '$_graphRoot/drives/${_segment(_requiredDriveId)}/items/${_segment(targetId)}:/${Uri.encodeComponent(name)}:/content',
          ),
          await OneDriveAuth.acquireToken(),
          headers: const {'Content-Type': 'application/octet-stream'},
          bodyBytes: bytes,
        );
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
      for (final item in await _children(_requiredDriveId, parentId)) {
        if ((item['name'] as String?) == segment) {
          found = item;
          break;
        }
      }
      if (found == null) throw Exception('Položka už v OneDrive neexistuje.');
      parentId = found['id'] as String;
    }
    return found!;
  }

  Future<String> _resolveFolder(String relativePath) async {
    var itemId = _requiredRootItemId;
    for (final segment in _pathSegments(relativePath)) {
      Map<String, dynamic>? found;
      for (final item in await _children(_requiredDriveId, itemId)) {
        if (item['name'] == segment && item['folder'] != null) {
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
      final children = await _children(_requiredDriveId, itemId);
      Map<String, dynamic>? folder;
      for (final item in children) {
        if ((item['name'] as String?)?.toLowerCase() == segment.toLowerCase()) {
          if (item['folder'] == null) {
            throw Exception('Položka "$segment" nie je priečinok.');
          }
          folder = item;
          break;
        }
      }

      if (folder == null) {
        final response = await _request(
          'POST',
          _childrenUri(_requiredDriveId, itemId),
          await OneDriveAuth.acquireToken(),
          headers: const {'Content-Type': 'application/json'},
          bodyBytes: utf8.encode(
            jsonEncode({
              'name': segment,
              'folder': <String, Object>{},
              '@microsoft.graph.conflictBehavior': 'fail',
            }),
          ),
        );
        folder = _decodeJson(response) as Map<String, dynamic>;
      }
      itemId = folder['id'] as String;
    }
    return itemId;
  }

  Future<void> _createFile(
    String parentId,
    String fileName,
    List<int> bytes,
  ) async {
    final response = await _request(
      'POST',
      _childrenUri(_requiredDriveId, parentId),
      await OneDriveAuth.acquireToken(),
      headers: const {'Content-Type': 'application/json'},
      bodyBytes: utf8.encode(
        jsonEncode({
          'name': fileName,
          'file': <String, Object>{},
          '@microsoft.graph.conflictBehavior': 'fail',
        }),
      ),
    );
    final created = _decodeJson(response) as Map<String, dynamic>;
    final itemId = created['id'] as String;

    try {
      final uploaded = await _request(
        'PUT',
        _itemContentUri(_requiredDriveId, itemId),
        await OneDriveAuth.acquireToken(),
        headers: const {'Content-Type': 'application/octet-stream'},
        bodyBytes: bytes,
      );
      _decodeJson(uploaded);
    } catch (_) {
      try {
        await _request(
          'DELETE',
          _itemUri(_requiredDriveId, itemId),
          await OneDriveAuth.acquireToken(),
        );
      } catch (_) {}
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _children(
    String driveId,
    String itemId,
  ) async {
    var uri = _childrenUri(driveId, itemId);
    final items = <Map<String, dynamic>>[];
    while (true) {
      final response = await _request(
        'GET',
        uri,
        await OneDriveAuth.acquireToken(),
      );
      final data = _decodeJson(response) as Map<String, dynamic>;
      items.addAll(
        (data['value'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>(),
      );
      final nextLink = data['@odata.nextLink'] as String?;
      if (nextLink == null) return items;
      uri = Uri.parse(nextLink);
    }
  }

  Future<List<int>> _download(String driveId, String itemId) async {
    final response = await _request(
      'GET',
      _itemContentUri(driveId, itemId),
      await OneDriveAuth.acquireToken(),
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
      if (response.statusCode == 412) {
        throw Exception(
          'Skladbu medzitým zmenil niekto iný. Obnov zoznam a skús to znova.',
        );
      }
      var message = response.reasonPhrase ?? 'chyba Graph API';
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        message =
            ((data['error'] as Map<String, dynamic>?)?['message'] as String?) ??
            message;
      } catch (_) {}
      throw Exception('OneDrive: $message (${response.statusCode})');
    }
    return response;
  }

  Uri _childrenUri(String driveId, String itemId) => Uri.parse(
    '$_graphRoot/drives/${_segment(driveId)}/items/${_segment(itemId)}/children',
  );

  Uri _itemUri(String driveId, String itemId) => Uri.parse(
    '$_graphRoot/drives/${_segment(driveId)}/items/${_segment(itemId)}',
  );

  Uri _itemContentUri(String driveId, String itemId) => Uri.parse(
    '$_graphRoot/drives/${_segment(driveId)}/items/${_segment(itemId)}/content',
  );

  Object? _decodeJson(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  String _relative(String path) {
    final normalizedPath = path.replaceAll('\\', '/');
    final root = _requiredRootPath.replaceAll('\\', '/');
    if (normalizedPath != root && !normalizedPath.startsWith('$root/')) {
      throw ArgumentError('Súbor nepatrí do aktuálneho OneDrive priečinka.');
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
    _driveId = null;
    _rootItemId = null;
    _rootPath = null;
    _etags.clear();
    _subfolders = [];
  }

  String get _requiredDriveId =>
      _driveId ?? (throw StateError('Najprv pripoj OneDrive priečinok.'));
  String get _requiredRootItemId =>
      _rootItemId ?? (throw StateError('Najprv pripoj OneDrive priečinok.'));
  String get _requiredRootPath =>
      _rootPath ?? (throw StateError('Najprv pripoj OneDrive priečinok.'));
}
