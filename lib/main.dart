// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive.dart';

void main() {
  runApp(const ChordHubApp());
}

class ChordHubApp extends StatefulWidget {
  const ChordHubApp({super.key});

  @override
  State<ChordHubApp> createState() => _ChordHubAppState();
}

class _ChordHubAppState extends State<ChordHubApp> {
  static const Color _brandOrange = Color(0xFFFF9F00);
  static const String _prefThemeMode = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _restoreThemeMode();
  }

  void _toggleThemeMode() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
    _saveThemeMode(_themeMode);
  }

  Future<void> _restoreThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefThemeMode);
    final restored =
        value == 'light'
            ? ThemeMode.light
            : value == 'dark'
            ? ThemeMode.dark
            : ThemeMode.dark;

    if (!mounted) {
      return;
    }
    setState(() {
      _themeMode = restored;
    });
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = mode == ThemeMode.light ? 'light' : 'dark';
    await prefs.setString(_prefThemeMode, value);
  }

  @override
  Widget build(BuildContext context) {
    final lightSeedScheme = ColorScheme.fromSeed(
      seedColor: _brandOrange,
      brightness: Brightness.light,
    );
    final darkSeedScheme = ColorScheme.fromSeed(
      seedColor: _brandOrange,
      brightness: Brightness.dark,
    );

    final lightScheme = lightSeedScheme.copyWith(
      primary: _brandOrange,
      surface: const Color(0xFFF7F8FA),
      surfaceContainerHighest: const Color(0xFFECEFF3),
      secondaryContainer: const Color(0xFFFFF1D7),
      onSecondaryContainer: const Color(0xFF4A2D00),
      tertiary: const Color(0xFF4B5563),
    );

    final darkScheme = darkSeedScheme.copyWith(
      primary: const Color(0xFFFFB433),
      surface: const Color(0xFF111317),
      surfaceContainerHighest: const Color(0xFF1D232C),
      secondaryContainer: const Color(0xFF3B2A00),
      onSecondaryContainer: const Color(0xFFFFE1AA),
      tertiary: const Color(0xFF9CA3AF),
    );

    return MaterialApp(
      title: 'Chordhub',
      theme: ThemeData(
        colorScheme: lightScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: lightScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: lightScheme.surface,
          foregroundColor: lightScheme.onSurface,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: darkScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: darkScheme.surface,
          foregroundColor: darkScheme.onSurface,
          elevation: 0,
        ),
      ),
      themeMode: _themeMode,
      home: SongbookPage(
        themeMode: _themeMode,
        onToggleThemeMode: _toggleThemeMode,
      ),
    );
  }
}

class SongbookPage extends StatefulWidget {
  const SongbookPage({
    required this.themeMode,
    required this.onToggleThemeMode,
    super.key,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleThemeMode;

  @override
  State<SongbookPage> createState() => _SongbookPageState();
}

class _SongbookPageState extends State<SongbookPage> {
  static const String _prefFolderPath = 'songs_folder_path';
  static const String _prefSelectedSongPath = 'selected_song_path';
  static const String _prefFolderOrderMap = 'song_folder_order_map';
  static const String _prefPlaylistRoundCount = 'playlist_round_count';

  final TextEditingController _editorController = TextEditingController();
  final FocusNode _hotkeysFocusNode = FocusNode();
  final ScrollController _previewScrollController = ScrollController();
  final ScrollController _playlistHorizontalScrollController =
      ScrollController();

  final Set<String> _selectedForCopy =
      {}; // paths selected for copy to subfolder
  bool _isSelectionMode = false;
  Map<String, List<String>> _folderOrder =
      {}; // relative subfolder path -> custom song order (paths)
  bool _showPlaylistBuilder = false;
  int _playlistRoundCount = 4;
  List<List<String>> _playlistColumns = [];
  List<String> _playlistUnassigned = [];
  final Set<String> _playlistSelectedPaths = {};
  String _playlistSourceRelativeDir = '';
  String _playlistSourceTitle = '';

  String? _folderPath;
  final List<ProSongFile> _songs = [];
  ProSongFile? _selectedSong;
  bool _isLoading = false;
  bool _isEditing = false;
  int _transposeSemitones = 0;
  List<String> _subfolders = [];

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  @override
  void dispose() {
    _editorController.dispose();
    _hotkeysFocusNode.dispose();
    _previewScrollController.dispose();
    _playlistHorizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final storedFolderPath = prefs.getString(_prefFolderPath);
    final storedSelectedPath = prefs.getString(_prefSelectedSongPath);
    await _loadFolderOrder();
    _playlistRoundCount =
        prefs.getInt(_prefPlaylistRoundCount)?.clamp(1, 8) ?? 4;
    _showPlaylistBuilder = false;

    if (!mounted) {
      return;
    }

    setState(() {
      _folderPath = storedFolderPath;
    });

    if (storedFolderPath != null && storedFolderPath.isNotEmpty) {
      await _loadSongs(
        preferredSongPath: storedSelectedPath,
        showErrors: false,
      );
    }
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Vyber priečinok so skladbami',
    );

    if (path == null || path.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefFolderPath, path);

    if (!mounted) {
      return;
    }

    setState(() {
      _folderPath = path;
      _isEditing = false;
      _transposeSemitones = 0;
      _showPlaylistBuilder = false;
      _playlistColumns = [];
      _playlistUnassigned = [];
      _playlistSelectedPaths.clear();
      _playlistSourceRelativeDir = '';
      _playlistSourceTitle = '';
    });

    await _loadSongs();
  }

  Future<void> _loadSongs({
    String? preferredSongPath,
    bool showErrors = true,
  }) async {
    final folderPath = _folderPath;
    if (folderPath == null || folderPath.isEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final loadedSongs = await SongRepository.loadFromFolder(folderPath);
      final loadedFolders = SongRepository.getAllSubfolders(folderPath);

      ProSongFile? selected;
      if (preferredSongPath != null) {
        for (final song in loadedSongs) {
          if (song.path == preferredSongPath) {
            selected = song;
            break;
          }
        }
      }

      selected ??=
          _selectedSong == null
              ? null
              : loadedSongs
                  .where((song) => song.path == _selectedSong!.path)
                  .cast<ProSongFile?>()
                  .firstWhere((song) => song != null, orElse: () => null);

      selected ??= loadedSongs.isNotEmpty ? loadedSongs.first : null;

      if (!mounted) {
        return;
      }

      setState(() {
        _songs
          ..clear()
          ..addAll(loadedSongs);
        _selectedSong = selected;
        _subfolders = loadedFolders;
        _isEditing = false;
        _transposeSemitones = 0;
        if (_showPlaylistBuilder) {
          _refreshPlaylistBuilderSource(loadedSongs);
        }
        _isLoading = false;
      });

      if (selected != null) {
        _editorController.text = selected.content;
      } else {
        _editorController.clear();
      }

      await _persistSelectedSongPath(selected?.path);
      _requestHotkeysFocus();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      if (showErrors) {
        _showMessage('Nepodarilo sa načítať skladby: $error');
      }
    }
  }

  Future<void> _persistSelectedSongPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.isEmpty) {
      await prefs.remove(_prefSelectedSongPath);
      return;
    }
    await prefs.setString(_prefSelectedSongPath, path);
  }

  Future<void> _loadFolderOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefFolderOrderMap);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _folderOrder = decoded.map(
        (key, value) => MapEntry(key, (value as List).cast<String>()),
      );
    } catch (_) {
      _folderOrder = {};
    }
  }

  Future<void> _saveFolderOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefFolderOrderMap, jsonEncode(_folderOrder));
  }

  Future<void> _savePlaylistPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefPlaylistRoundCount, _playlistRoundCount);
  }

  void _openPlaylistBuilderForFolder(
    String relativeDir,
    String title,
    List<ProSongFile> songs,
  ) {
    setState(() {
      _showPlaylistBuilder = true;
      _playlistSourceRelativeDir = relativeDir;
      _playlistSourceTitle = title;
      _bootstrapPlaylistBuilder(songs);
    });
    _savePlaylistPreferences();
  }

  void _closePlaylistBuilder() {
    setState(() {
      _showPlaylistBuilder = false;
      _playlistSelectedPaths.clear();
    });
  }

  void _bootstrapPlaylistBuilder(List<ProSongFile> sourceSongs) {
    _playlistColumns = List.generate(_playlistRoundCount, (_) => <String>[]);
    _playlistUnassigned = sourceSongs.map((song) => song.path).toList();
    _playlistSelectedPaths.clear();
  }

  void _refreshPlaylistBuilderSource(List<ProSongFile> loadedSongs) {
    if (!_showPlaylistBuilder) {
      return;
    }

    final sourceSongs = _songsForRelativeDir(
      _playlistSourceRelativeDir,
      sourceSongs: loadedSongs,
    );
    _syncPlaylistBuilderWithSourceSongs(sourceSongs);
  }

  void _syncPlaylistBuilderWithSourceSongs(List<ProSongFile> sourceSongs) {
    if (!_showPlaylistBuilder) {
      return;
    }

    _ensurePlaylistColumnCount();

    if (_playlistColumns.isEmpty && _playlistUnassigned.isEmpty) {
      _playlistUnassigned = sourceSongs.map((song) => song.path).toList();
      return;
    }

    final availablePaths = sourceSongs.map((song) => song.path).toSet();
    final seen = <String>{};

    for (final column in _playlistColumns) {
      column.removeWhere((path) {
        if (!availablePaths.contains(path) || seen.contains(path)) {
          return true;
        }
        seen.add(path);
        return false;
      });
    }

    _playlistUnassigned.removeWhere((path) {
      if (!availablePaths.contains(path) || seen.contains(path)) {
        return true;
      }
      seen.add(path);
      return false;
    });

    for (final song in sourceSongs) {
      if (!seen.contains(song.path)) {
        _playlistUnassigned.add(song.path);
      }
    }

    _playlistSelectedPaths.removeWhere(
      (path) => !availablePaths.contains(path),
    );
  }

  void _ensurePlaylistColumnCount() {
    if (_playlistRoundCount < 1) {
      _playlistRoundCount = 1;
    }

    if (_playlistColumns.isEmpty && _playlistUnassigned.isEmpty) {
      _playlistColumns = List.generate(_playlistRoundCount, (_) => <String>[]);
      return;
    }

    if (_playlistColumns.length > _playlistRoundCount) {
      final removed = _playlistColumns.sublist(_playlistRoundCount);
      for (final column in removed) {
        _playlistUnassigned.addAll(column);
      }
      _playlistColumns = _playlistColumns.sublist(0, _playlistRoundCount);
    }

    while (_playlistColumns.length < _playlistRoundCount) {
      _playlistColumns.add(<String>[]);
    }
  }

  void _setPlaylistRoundCount(int newCount) {
    final clamped = newCount.clamp(1, 8);
    if (clamped == _playlistRoundCount) {
      return;
    }

    setState(() {
      _playlistRoundCount = clamped;
      _ensurePlaylistColumnCount();
    });
    _savePlaylistPreferences();
  }

  List<ProSongFile> _songsForRelativeDir(
    String relativeDir, {
    List<ProSongFile>? sourceSongs,
  }) {
    final from = sourceSongs ?? _songs;
    return from
        .where((song) => _songDirectoryRelative(song.path) == relativeDir)
        .toList();
  }

  String _songDirectoryRelative(String songPath) {
    final relative = _relativeSongPath(songPath);
    if (relative == null || relative.isEmpty) {
      return '';
    }
    final normalized = relative.replaceAll('\\', '/');
    final lastSlash = normalized.lastIndexOf('/');
    if (lastSlash <= 0) {
      return '';
    }
    return normalized.substring(0, lastSlash);
  }

  void _scrollPlaylistHorizontallyBy(double delta) {
    if (!_playlistHorizontalScrollController.hasClients) {
      return;
    }

    final position = _playlistHorizontalScrollController.position;
    final target = (_playlistHorizontalScrollController.offset + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    _playlistHorizontalScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  ProSongFile? _songForPath(String path) {
    for (final song in _songs) {
      if (song.path == path) {
        return song;
      }
    }
    return null;
  }

  List<ProSongFile> _orderedPlaylistSongs() {
    final ordered = <ProSongFile>[];
    for (final column in _playlistColumns) {
      for (final path in column) {
        final song = _songForPath(path);
        if (song != null) {
          ordered.add(song);
        }
      }
    }
    for (final path in _playlistUnassigned) {
      final song = _songForPath(path);
      if (song != null) {
        ordered.add(song);
      }
    }
    return ordered;
  }

  Future<void> _savePlaylistOrderToFolder() async {
    final relativeDir = _playlistSourceRelativeDir;
    final orderedSongs = _orderedPlaylistSongs();
    if (orderedSongs.isEmpty) {
      _showMessage('V playliste nie sú žiadne skladby na uloženie poradia.');
      return;
    }

    setState(() {
      _folderOrder[relativeDir] =
          orderedSongs.map((song) => song.path).toList();
    });
    await _saveFolderOrder();

    final folderLabel =
        _playlistSourceTitle.isEmpty
            ? '(Hlavný priečinok)'
            : _playlistSourceTitle;
    _showMessage('Poradie bolo uložené pre priečinok $folderLabel.');
  }

  _PlaylistPlacement? _findPlaylistPlacement(String path) {
    final unassignedIndex = _playlistUnassigned.indexOf(path);
    if (unassignedIndex != -1) {
      return _PlaylistPlacement(
        isUnassigned: true,
        bucketIndex: 0,
        itemIndex: unassignedIndex,
      );
    }

    for (
      var columnIndex = 0;
      columnIndex < _playlistColumns.length;
      columnIndex++
    ) {
      final itemIndex = _playlistColumns[columnIndex].indexOf(path);
      if (itemIndex != -1) {
        return _PlaylistPlacement(
          isUnassigned: false,
          bucketIndex: columnIndex,
          itemIndex: itemIndex,
        );
      }
    }

    return null;
  }

  List<String> _playlistAllPathsInVisualOrder() {
    final ordered = <String>[];
    ordered.addAll(_playlistUnassigned);
    for (final column in _playlistColumns) {
      ordered.addAll(column);
    }
    return ordered;
  }

  List<String> _dragGroupForPath(String draggedPath) {
    if (_playlistSelectedPaths.contains(draggedPath)) {
      final visualOrder = _playlistAllPathsInVisualOrder();
      return [
        for (final path in visualOrder)
          if (_playlistSelectedPaths.contains(path)) path,
      ];
    }
    return [draggedPath];
  }

  void _togglePlaylistSelection(String path) {
    setState(() {
      if (_playlistSelectedPaths.contains(path)) {
        _playlistSelectedPaths.remove(path);
      } else {
        _playlistSelectedPaths.add(path);
      }
    });
  }

  void _clearPlaylistSelection() {
    if (_playlistSelectedPaths.isEmpty) {
      return;
    }
    setState(() {
      _playlistSelectedPaths.clear();
    });
  }

  void _handlePlaylistDrop(
    String draggedPath, {
    required bool toUnassigned,
    required int bucketIndex,
    required int insertIndex,
  }) {
    final candidatePaths = _dragGroupForPath(draggedPath);
    final paths = <String>[];
    for (final path in candidatePaths) {
      if (_findPlaylistPlacement(path) != null && !paths.contains(path)) {
        paths.add(path);
      }
    }
    if (paths.isEmpty) {
      return;
    }

    final destinationList =
        toUnassigned ? _playlistUnassigned : _playlistColumns[bucketIndex];
    var targetIndex = insertIndex.clamp(0, destinationList.length);

    var removedBeforeTarget = 0;
    for (final path in paths) {
      final indexInDestination = destinationList.indexOf(path);
      if (indexInDestination != -1 && indexInDestination < targetIndex) {
        removedBeforeTarget++;
      }
    }
    targetIndex -= removedBeforeTarget;

    for (final path in paths) {
      final placement = _findPlaylistPlacement(path);
      if (placement == null) {
        continue;
      }
      final sourceList =
          placement.isUnassigned
              ? _playlistUnassigned
              : _playlistColumns[placement.bucketIndex];
      sourceList.removeAt(placement.itemIndex);
    }

    targetIndex = targetIndex.clamp(0, destinationList.length);
    destinationList.insertAll(targetIndex, paths);

    setState(() {
      for (final path in paths) {
        _playlistSelectedPaths.remove(path);
      }
    });
  }

  void _movePlaylistSong(
    String path, {
    required bool toUnassigned,
    required int bucketIndex,
    required int insertIndex,
  }) {
    _handlePlaylistDrop(
      path,
      toUnassigned: toUnassigned,
      bucketIndex: bucketIndex,
      insertIndex: insertIndex,
    );
  }

  Future<void> _exportPlaylistToWord() async {
    final orderedSongs = _orderedPlaylistSongs();
    if (orderedSongs.isEmpty) {
      _showMessage('Najprv pridaj skladby do playlistu.');
      return;
    }

    final entries = <_PlaylistEntry>[];
    final nonEmptyRoundIndexes = <int>[];
    for (var i = 0; i < _playlistColumns.length; i++) {
      if (_playlistColumns[i].isNotEmpty) {
        nonEmptyRoundIndexes.add(i);
      }
    }

    for (var i = 0; i < _playlistColumns.length; i++) {
      final round = _playlistColumns[i];
      if (round.isEmpty) {
        continue;
      }

      for (final path in round) {
        final song = _songForPath(path);
        if (song == null) {
          continue;
        }
        final parsed = ParsedSong.fromContent(
          song.content,
          fallbackTitle: SongRepository.basenameWithoutExtension(song.path),
        );
        entries.add(_PlaylistEntry(title: parsed.title, bpm: parsed.bpm));
      }

      final isLastNonEmptyRound = i == nonEmptyRoundIndexes.last;
      if (!isLastNonEmptyRound) {
        entries.add(const _PlaylistEntry.roundSeparator());
      }
    }

    for (final path in _playlistUnassigned) {
      final song = _songForPath(path);
      if (song == null) {
        continue;
      }
      final parsed = ParsedSong.fromContent(
        song.content,
        fallbackTitle: SongRepository.basenameWithoutExtension(song.path),
      );
      entries.add(_PlaylistEntry(title: parsed.title, bpm: parsed.bpm));
    }

    final folderTitle =
        _playlistSourceTitle.isEmpty
            ? (_folderPath == null || _folderPath!.isEmpty
                ? 'playlist'
                : SongRepository.basename(_folderPath!))
            : _playlistSourceTitle;

    final bytes = _WordPlaylistBuilder.build(
      folderTitle: folderTitle,
      entries: entries,
    );

    final suggestedName =
        '${folderTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}_playlist.docx';

    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Uložiť playlist ako Word dokument',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: ['docx'],
      );

      if (savePath == null) {
        return;
      }

      final finalPath =
          savePath.toLowerCase().endsWith('.docx')
              ? savePath
              : '$savePath.docx';
      await File(finalPath).writeAsBytes(bytes, flush: true);
      _showMessage('Playlist bol exportovaný do Wordu.');
    } catch (error) {
      _showMessage('Nepodarilo sa exportovať playlist: $error');
    }
  }

  Future<void> _exportFolderPlaylistToWord(
    String relativeDir,
    String folderTitle,
    List<ProSongFile> songs,
  ) async {
    if (songs.isEmpty) {
      _showMessage('V tomto priečinku nie sú žiadne skladby na export.');
      return;
    }

    final entries = <_PlaylistEntry>[
      for (final song in songs)
        _PlaylistEntry(
          title:
              ParsedSong.fromContent(
                song.content,
                fallbackTitle: SongRepository.basenameWithoutExtension(
                  song.path,
                ),
              ).title,
          bpm:
              ParsedSong.fromContent(
                song.content,
                fallbackTitle: SongRepository.basenameWithoutExtension(
                  song.path,
                ),
              ).bpm,
        ),
    ];

    final bytes = _WordPlaylistBuilder.build(
      folderTitle: folderTitle,
      entries: entries,
    );

    final suggestedName =
        '${folderTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}_playlist.docx';

    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Uložiť playlist ako Word dokument',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: ['docx'],
      );

      if (savePath == null) {
        return;
      }

      final finalPath =
          savePath.toLowerCase().endsWith('.docx')
              ? savePath
              : '$savePath.docx';
      await File(finalPath).writeAsBytes(bytes, flush: true);
      _showMessage('Playlist bol exportovaný do Wordu.');
    } catch (error) {
      _showMessage('Nepodarilo sa exportovať playlist: $error');
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedForCopy.clear();
      }
    });
  }

  void _reorderSongsInFolder(
    String relativeDir,
    List<ProSongFile> currentOrder,
    int oldIndex,
    int newIndex,
  ) {
    var adjustedNewIndex = newIndex;
    if (oldIndex < newIndex) {
      adjustedNewIndex -= 1;
    }

    final updated = List<ProSongFile>.from(currentOrder);
    final moved = updated.removeAt(oldIndex);
    updated.insert(adjustedNewIndex, moved);

    setState(() {
      _folderOrder[relativeDir] = updated.map((song) => song.path).toList();
    });
    _saveFolderOrder();
  }

  void _applyCustomOrder(String relativeDir, List<ProSongFile> songs) {
    final order = _folderOrder[relativeDir];
    if (order == null || order.isEmpty) {
      return;
    }

    final remaining = {for (final song in songs) song.path: song};
    final ordered = <ProSongFile>[];
    for (final path in order) {
      final song = remaining.remove(path);
      if (song != null) {
        ordered.add(song);
      }
    }
    ordered.addAll(remaining.values);

    songs
      ..clear()
      ..addAll(ordered);
  }

  void _selectSong(ProSongFile song) {
    setState(() {
      _selectedSong = song;
      _isEditing = false;
      _transposeSemitones = 0;
      _editorController.text = song.content;
    });
    _persistSelectedSongPath(song.path);
    _requestHotkeysFocus();
  }

  void _scrollPreviewBy(double delta) {
    if (!_previewScrollController.hasClients) {
      return;
    }

    final position = _previewScrollController.position;
    final target = (_previewScrollController.offset + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    _previewScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
    );
  }

  void _requestHotkeysFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (!_hotkeysFocusNode.hasFocus) {
        _hotkeysFocusNode.requestFocus();
      }
    });
  }

  void _changeTransposeBy(int delta) {
    setState(() {
      _transposeSemitones = (_transposeSemitones + delta).clamp(-24, 24);
    });
  }

  Future<void> _saveCurrentSong() async {
    final selectedSong = _selectedSong;
    if (selectedSong == null) {
      return;
    }

    final updatedContent = _editorController.text;
    try {
      await SongRepository.saveSong(selectedSong.path, updatedContent);
      final parsedSong = ParsedSong.fromContent(
        updatedContent,
        fallbackTitle: SongRepository.basenameWithoutExtension(
          selectedSong.path,
        ),
      );
      setState(() {
        selectedSong.content = updatedContent;
        selectedSong.title = parsedSong.title;
        selectedSong.subtitle = parsedSong.subtitle;
        SongRepository.sortSongs(_songs);
        _isEditing = false;
      });
      FocusScope.of(context).unfocus();
      _requestHotkeysFocus();
      _showMessage('Pieseň bola uložená.');
    } catch (error) {
      _showMessage('Nepodarilo sa uložiť pieseň: $error');
    }
  }

  void _transformEditorToChordPro() {
    if (!_isEditing) {
      return;
    }

    final source = _editorController.text;
    if (source.trim().isEmpty) {
      return;
    }

    final transformed = ChordProConverter.convertToChordPro(source);
    _editorController.value = TextEditingValue(
      text: transformed,
      selection: TextSelection.collapsed(offset: transformed.length),
    );
    _showMessage('Text bol transformovaný do ChordPro formátu.');
  }

  Future<void> _createNewProSong() async {
    final folderPath = _folderPath;
    if (folderPath == null || folderPath.isEmpty) {
      _showMessage('Najprv vyber priečinok pre skladby.');
      return;
    }

    final fileName = await _showNewSongFileNameDialog();
    if (fileName == null) {
      return;
    }

    final normalizedName =
        fileName.toLowerCase().endsWith('.pro') ? fileName : '$fileName.pro';
    final safeName = normalizedName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final path = '$folderPath${Platform.pathSeparator}$safeName';
    final file = File(path);

    if (file.existsSync()) {
      _showMessage('Súbor s týmto názvom už existuje.');
      return;
    }

    const initialContent = '{title: Nová pieseň}\n{subtitle: }\n\n';

    try {
      await SongRepository.saveSong(path, initialContent);
      final parsed = ParsedSong.fromContent(
        initialContent,
        fallbackTitle: SongRepository.basenameWithoutExtension(path),
      );
      final newSong = ProSongFile(
        path: path,
        title: parsed.title,
        subtitle: parsed.subtitle,
        content: initialContent,
      );

      setState(() {
        _songs.add(newSong);
        SongRepository.sortSongs(_songs);
        _selectedSong = newSong;
        _isEditing = true;
        _transposeSemitones = 0;
        _editorController.text = initialContent;
      });
      _showMessage('Nový .pro súbor bol vytvorený.');
    } catch (error) {
      _showMessage('Nepodarilo sa vytvoriť nový súbor: $error');
    }
  }

  Future<String?> _showNewSongFileNameDialog() async {
    final controller = TextEditingController(text: 'nova_piesen.pro');

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nový .pro súbor'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Názov súboru',
              hintText: 'napr. moja_piesen.pro',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Zrušiť'),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(name);
              },
              child: const Text('Vytvoriť'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveCurrentTransposition() async {
    final selectedSong = _selectedSong;
    if (selectedSong == null || _transposeSemitones == 0) {
      return;
    }

    try {
      final transposedContent = ChordTransposer.transposeChordProContent(
        selectedSong.content,
        _transposeSemitones,
      );

      await SongRepository.saveSong(selectedSong.path, transposedContent);
      final parsedSong = ParsedSong.fromContent(
        transposedContent,
        fallbackTitle: SongRepository.basenameWithoutExtension(
          selectedSong.path,
        ),
      );

      setState(() {
        selectedSong.content = transposedContent;
        selectedSong.title = parsedSong.title;
        selectedSong.subtitle = parsedSong.subtitle;
        _editorController.text = transposedContent;
        _transposeSemitones = 0;
        SongRepository.sortSongs(_songs);
      });
      _showMessage('Transpozícia bola uložená do súboru.');
    } catch (error) {
      _showMessage('Nepodarilo sa uložiť transpozíciu: $error');
    }
  }

  Future<void> _printCurrentSong() async {
    final selectedSong = _selectedSong;
    if (selectedSong == null) {
      return;
    }

    final parsedSong = ParsedSong.fromContent(
      selectedSong.content,
      fallbackTitle: SongRepository.basenameWithoutExtension(selectedSong.path),
    );
    final displayLines = SongDisplayBuilder.build(parsedSong.lines);

    try {
      await Printing.layoutPdf(
        name: '${parsedSong.title}.pdf',
        onLayout:
            (format) => _buildSongPdf(
              parsedSong: parsedSong,
              displayLines: displayLines,
              pageFormat: format,
            ),
      );
      if (mounted) {
        _showMessage('Tlač/export bol úspešne dokončený.');
      }
    } catch (error) {
      _showMessage('Nepodarilo sa otvoriť tlač: $error');
    }
  }

  Future<Uint8List> _buildSongPdf({
    required ParsedSong parsedSong,
    required List<SongDisplayLine> displayLines,
    required PdfPageFormat pageFormat,
  }) async {
    pw.Font baseFont;
    pw.Font boldFont;
    pw.Font monoFont;
    pw.Font monoBoldFont;

    try {
      baseFont = await PdfGoogleFonts.notoSansRegular();
      boldFont = await PdfGoogleFonts.notoSansBold();
      monoFont = await PdfGoogleFonts.notoSansMonoRegular();
      monoBoldFont = await PdfGoogleFonts.notoSansMonoBold();
    } catch (_) {
      baseFont = pw.Font.helvetica();
      boldFont = pw.Font.helveticaBold();
      monoFont = pw.Font.courier();
      monoBoldFont = pw.Font.courierBold();
    }

    final doc = pw.Document();
    const brandOrange = PdfColor(1.0, 0.623, 0.0);
    const neutralText = PdfColor(0.145, 0.161, 0.192);
    const softMuted = PdfColor(0.337, 0.369, 0.42);
    const chorusBg = PdfColor(1.0, 0.945, 0.843);
    const pageMargin = 12.0;
    const columnGap = 12.0;
    const songFontSize = 10.0;

    final contentWidth = pageFormat.width - (pageMargin * 2);
    final twoColumnWidth = (contentWidth - columnGap) / 2;

    final headerHeight = _estimatePdfHeaderHeight(
      parsedSong,
      contentWidth: contentWidth,
      hasTranspose: _transposeSemitones != 0,
    );
    final safetyBuffer = 30.0; // Rezerva pre nepresnosti v odhade
    final maxColumnHeight =
        pageFormat.height - (pageMargin * 2) - headerHeight - safetyBuffer;

    // --- Zostavenie blokov (jeden riadok piesne = jeden blok) ---
    final songBlocks = <_PdfColumnBlock>[];
    for (final line in displayLines) {
      final rendered = RenderedChordLine.fromRaw(
        line.rawLine,
        transposeSemitones: _transposeSemitones,
      );

      if (rendered.chordPlacements.isEmpty && rendered.lyricLinePlain.isEmpty) {
        songBlocks.add(
          _PdfColumnBlock(
            widget: pw.SizedBox(height: 3),
            heightSingleColumn: 3,
            heightTwoColumn: 3,
          ),
        );
        continue;
      }

      final chordText = _composePrintableChordLine(rendered);
      final lineBlock = <pw.Widget>[];
      if (chordText.trim().isNotEmpty) {
        lineBlock.add(
          pw.Text(
            chordText,
            style: pw.TextStyle(
              font: monoBoldFont,
              fontSize: songFontSize,
              height: 1.15,
              color: brandOrange,
            ),
          ),
        );
      }

      lineBlock.add(
        pw.Text(
          rendered.lyricLinePlain,
          style: pw.TextStyle(
            font: monoFont,
            fontSize: songFontSize,
            height: 1.15,
            color: neutralText,
          ),
        ),
      );

      final lineWidget =
          line.isChorus
              ? pw.Container(
                width: double.infinity,
                margin: const pw.EdgeInsets.only(bottom: 2),
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 3,
                  vertical: 1,
                ),
                decoration: pw.BoxDecoration(
                  color: chorusBg,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(1.5),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: lineBlock,
                ),
              )
              : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 2),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: lineBlock,
                ),
              );

      songBlocks.add(
        _PdfColumnBlock(
          widget: lineWidget,
          heightSingleColumn: _estimatePdfSongBlockHeight(
            rendered: rendered,
            chordText: chordText,
            isChorus: line.isChorus,
            columnWidth: contentWidth,
            fontSize: songFontSize,
          ),
          heightTwoColumn: _estimatePdfSongBlockHeight(
            rendered: rendered,
            chordText: chordText,
            isChorus: line.isChorus,
            columnWidth: twoColumnWidth,
            fontSize: songFontSize,
          ),
        ),
      );
    }

    // --- Princíp Songbook (Linkesoft) ---
    // 1) Ak sa pieseň v JEDNOM stĺpci (celá šírka) zmestí na 1 stranu -> 1 stĺpec.
    // 2) Inak, ak sa zmestí na 1 stranu v 2 stĺpcoch -> 2 stĺpce, 1 strana.
    // 3) Inak -> 1 (široký) stĺpec cez viacero strán.
    final totalSingleColumnHeight = songBlocks.fold<double>(
      0,
      (sum, block) => sum + block.heightSingleColumn,
    );
    final totalTwoColumnHeight = songBlocks.fold<double>(
      0,
      (sum, block) => sum + block.heightTwoColumn,
    );

    var fitsAsSingleColumn = totalSingleColumnHeight <= maxColumnHeight;
    var fitsAsTwoColumnsOnOnePage =
        !fitsAsSingleColumn &&
        totalTwoColumnHeight <= (maxColumnHeight * 2 * 0.9);

    // pages: zoznam strán, každá strana = zoznam stĺpcov, každý stĺpec = zoznam widgetov
    final List<List<List<pw.Widget>>> pages;
    final List<double> columnWidths;

    if (fitsAsSingleColumn) {
      final singleColumn = <pw.Widget>[
        for (final block in songBlocks) block.widget,
      ];
      pages = [
        [singleColumn],
      ];
      columnWidths = [contentWidth];
    } else if (fitsAsTwoColumnsOnOnePage) {
      final twoColumnPages = _paginateTwoColumnPages(
        songBlocks,
        maxColumnHeight,
      );
      pages = [
        for (final page in twoColumnPages) [page.leftColumn, page.rightColumn],
      ];
      columnWidths = [twoColumnWidth, twoColumnWidth];
    } else {
      final singleColumnPages = _paginateSingleColumnBlocks(
        songBlocks,
        maxColumnHeight,
      );
      pages = [
        for (final page in singleColumnPages) [page],
      ];
      columnWidths = [contentWidth];
    }

    for (final page in pages) {
      doc.addPage(
        // Používame MultiPage (nie Page), pretože Page vyžaduje, aby sa obsah
        // vždy presne zmestil na jednu stranu - ak je odhadovaná výška
        // stĺpca (viď _estimatePdfTextHeight) čo i len málo nižšia než
        // skutočná (typicky sa to stáva pri 2 stĺpcoch, kde sa kvôli menšej
        // šírke zalamuje oveľa viac riadkov), Page vyhodí výnimku a export
        // zlyhá - výsledkom je, že sa PDF vôbec nevykreslí. MultiPage vie
        // "spanning" obsah (Row/Column s textom) v takom prípade plynulo
        // pretiecť na ďalšiu fyzickú stranu namiesto pádu.
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(pageMargin),
          maxPages: 50,
          build: (context) {
            final rowChildren = <pw.Widget>[];
            for (var i = 0; i < page.length; i++) {
              if (i > 0) {
                rowChildren.add(pw.SizedBox(width: columnGap));
              }

              final columnWidth =
                  page.length == 1 ? columnWidths[i] : twoColumnWidth;

              rowChildren.add(
                pw.SizedBox(
                  width: columnWidth,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children:
                        page[i].isEmpty ? [pw.SizedBox.shrink()] : page[i],
                  ),
                ),
              );
            }

            return [
              pw.SizedBox(
                width: contentWidth,
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      parsedSong.title,
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 18,
                        color: neutralText,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    if (parsedSong.subtitle != null &&
                        parsedSong.subtitle!.trim().isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(
                          parsedSong.subtitle!,
                          style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 10,
                            color: softMuted,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    if (_transposeSemitones != 0)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(
                          'Transpozícia: ${_transposeSemitones > 0 ? '+' : ''}$_transposeSemitones',
                          style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 8,
                            color: softMuted,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 6, bottom: 8),
                      child: pw.Container(height: 1, color: brandOrange),
                    ),
                  ],
                ),
              ),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: rowChildren,
              ),
            ];
          },
        ),
      );
    }

    return doc.save();
  }

  String _composePrintableChordLine(RenderedChordLine rendered) {
    if (rendered.chordPlacements.isEmpty) {
      return '';
    }

    var length = math.max(1, rendered.lyricLinePlain.length);
    for (final placement in rendered.chordPlacements) {
      length = math.max(
        length,
        placement.position + placement.chord.length + 2,
      );
    }

    final buffer = List<String>.filled(length, ' ', growable: true);
    final occupied = List<bool>.filled(length, false, growable: true);

    for (final placement in rendered.chordPlacements) {
      final chord = placement.chord.trim();
      if (chord.isEmpty) {
        continue;
      }

      var start = placement.position.clamp(0, buffer.length - 1);
      while (start + chord.length <= buffer.length) {
        var collision = false;
        for (var i = 0; i < chord.length; i++) {
          if (occupied[start + i]) {
            collision = true;
            break;
          }
        }
        if (!collision) {
          break;
        }
        start++;
      }

      if (start + chord.length > buffer.length) {
        final needed = start + chord.length - buffer.length;
        buffer.addAll(List<String>.filled(needed, ' '));
        occupied.addAll(List<bool>.filled(needed, false));
      }

      for (var i = 0; i < chord.length; i++) {
        buffer[start + i] = chord[i];
        occupied[start + i] = true;
      }
      final gapIndex = start + chord.length;
      if (gapIndex < occupied.length) {
        occupied[gapIndex] = true;
      }
    }

    return buffer.join().trimRight();
  }

  double _estimatePdfHeaderHeight(
    ParsedSong parsedSong, {
    required double contentWidth,
    required bool hasTranspose,
  }) {
    var height =
        _estimatePdfTextHeight(
          parsedSong.title,
          fontSize: 18,
          availableWidth: contentWidth,
          widthFactor: 0.7, // Názvy bývajú tučné, zaberajú viac miesta
        ) +
        20; // Zväčšený padding z 14 na 20

    if (parsedSong.subtitle != null && parsedSong.subtitle!.trim().isNotEmpty) {
      height +=
          _estimatePdfTextHeight(
            parsedSong.subtitle!,
            fontSize: 10,
            availableWidth: contentWidth,
          ) +
          4;
    }

    if (hasTranspose) {
      height += 12; // Fixná výška pre riadok transpozície
    }

    return height + 15; // Celkový padding spodnej čiary
  }

  double _estimatePdfSongBlockHeight({
    required RenderedChordLine rendered,
    required String chordText,
    required bool isChorus,
    required double columnWidth,
    required double fontSize,
  }) {
    final chordHeight =
        chordText.trim().isEmpty
            ? 0.0
            : _estimatePdfTextHeight(
              chordText,
              fontSize: fontSize,
              availableWidth: columnWidth,
            );
    final lyricHeight = _estimatePdfTextHeight(
      rendered.lyricLinePlain,
      fontSize: fontSize,
      availableWidth: columnWidth,
    );
    return chordHeight + lyricHeight + (isChorus ? 4 : 2);
  }

  double _estimatePdfTextHeight(
    String text, {
    required double fontSize,
    required double availableWidth,
    double widthFactor = 0.62, // Zvýšené z 0.58 na 0.62 (pesimistickejší odhad)
    double lineHeightFactor = 1.2, // Zvýšené z 1.15 na 1.2
  }) {
    final normalized = text.trimRight();
    if (normalized.isEmpty) {
      return fontSize * lineHeightFactor;
    }

    // Odhad počtu znakov, ktoré sa zmestia do šírky
    final estimatedCharsPerLine =
        (availableWidth / (fontSize * widthFactor)).floor();

    // Ak je riadok prázdny alebo príliš krátky, vrátime aspoň jeden riadok
    if (estimatedCharsPerLine <= 0) return fontSize * lineHeightFactor;

    // Výpočet počtu riadkov (ceil zaistí, že aj kúsok textu navyše pridá celý riadok)
    final lineCount = (normalized.length / estimatedCharsPerLine).ceil();

    // Pridáme malý fixný prídavok pre istotu
    return (lineCount * fontSize * lineHeightFactor) + 1.0;
  }

  List<_PdfSongPage> _paginateTwoColumnPages(
    List<_PdfColumnBlock> blocks,
    double maxColumnHeight,
  ) {
    final pages = <_PdfSongPage>[];
    var leftColumn = <pw.Widget>[];
    var rightColumn = <pw.Widget>[];
    var leftHeight = 0.0;
    var rightHeight = 0.0;

    void flushPage() {
      if (leftColumn.isEmpty && rightColumn.isEmpty) {
        return;
      }

      pages.add(
        _PdfSongPage(
          leftColumn: List<pw.Widget>.unmodifiable(leftColumn),
          rightColumn: List<pw.Widget>.unmodifiable(rightColumn),
        ),
      );
      leftColumn = <pw.Widget>[];
      rightColumn = <pw.Widget>[];
      leftHeight = 0.0;
      rightHeight = 0.0;
    }

    for (final block in blocks) {
      if (leftHeight + block.heightTwoColumn <= maxColumnHeight ||
          leftColumn.isEmpty) {
        leftColumn.add(block.widget);
        leftHeight += block.heightTwoColumn;
        continue;
      }

      if (rightHeight + block.heightTwoColumn <= maxColumnHeight ||
          rightColumn.isEmpty) {
        rightColumn.add(block.widget);
        rightHeight += block.heightTwoColumn;
        continue;
      }

      flushPage();
      leftColumn.add(block.widget);
      leftHeight += block.heightTwoColumn;
    }

    flushPage();
    if (pages.isEmpty) {
      pages.add(const _PdfSongPage(leftColumn: [], rightColumn: []));
    }

    return pages;
  }

  // Rozdelenie blokov do viacerých strán s JEDNÝM širokým stĺpcom
  // (použije sa, keď pieseň nie je krátka - nezmestí sa ani na 1 stranu
  // v 2 stĺpcoch).
  List<List<pw.Widget>> _paginateSingleColumnBlocks(
    List<_PdfColumnBlock> blocks,
    double maxColumnHeight,
  ) {
    final pages = <List<pw.Widget>>[];
    var current = <pw.Widget>[];
    var currentHeight = 0.0;

    for (final block in blocks) {
      if (currentHeight + block.heightSingleColumn <= maxColumnHeight ||
          current.isEmpty) {
        current.add(block.widget);
        currentHeight += block.heightSingleColumn;
      } else {
        pages.add(current);
        current = [block.widget];
        currentHeight = block.heightSingleColumn;
      }
    }

    if (current.isNotEmpty) {
      pages.add(current);
    }
    if (pages.isEmpty) {
      pages.add([]);
    }

    return pages;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openPerformanceMode(
    ParsedSong parsedSong,
    List<SongDisplayLine> displayLines,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (context) => SongPerformancePage(
              title: parsedSong.title,
              subtitle: parsedSong.subtitle,
              displayLines: displayLines,
              initialTransposeSemitones: _transposeSemitones,
              initialScrollSpeedPixelsPerSecond: parsedSong.scrollSpeed,
            ),
      ),
    );
  }

  Future<void> _openSelectedSongPerformanceMode() {
    final selectedSong = _selectedSong;
    if (selectedSong == null) {
      return Future.value();
    }

    final parsedSong = ParsedSong.fromContent(
      selectedSong.content,
      fallbackTitle: SongRepository.basenameWithoutExtension(selectedSong.path),
    );
    final displayLines = SongDisplayBuilder.build(parsedSong.lines);
    return _openPerformanceMode(parsedSong, displayLines);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _hotkeysFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }

        if (!_isEditing && event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _scrollPreviewBy(56);
          return KeyEventResult.handled;
        }

        if (!_isEditing && event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _scrollPreviewBy(-56);
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.space && !_isEditing) {
          _openSelectedSongPerformanceMode();
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 76,
          leadingWidth: 170,
          leading: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
            child: Image.asset(
              widget.themeMode == ThemeMode.dark
                  ? 'chordhub biely text.png'
                  : 'chordhub cierny text.png',
              fit: BoxFit.fitWidth,
              filterQuality: FilterQuality.high,
            ),
          ),
          actions: [
            IconButton(
              onPressed: widget.onToggleThemeMode,
              tooltip:
                  widget.themeMode == ThemeMode.dark
                      ? 'Prepnúť na svetlý režim'
                      : 'Prepnúť na tmavý režim',
              icon: Icon(
                widget.themeMode == ThemeMode.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
              ),
            ),
            TextButton.icon(
              onPressed: _pickFolder,
              icon: const Icon(Icons.folder_open),
              label: const Text('Vybrať priečinok'),
            ),
            TextButton.icon(
              onPressed: _folderPath == null ? null : _createNewProSong,
              icon: const Icon(Icons.note_add),
              label: const Text('Pridať akordy'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _folderPath == null ? null : _createSubfolder,
              icon: const Icon(Icons.create_new_folder),
              label: const Text('Nový priečinok'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _folderPath == null ? null : _toggleSelectionMode,
              icon: Icon(_isSelectionMode ? Icons.close : Icons.checklist),
              label: Text(
                _isSelectionMode
                    ? 'Zrušiť výber'
                    : 'Vyber skladby do priečinka',
              ),
            ),
            const SizedBox(width: 8),
            if (_isSelectionMode)
              TextButton.icon(
                onPressed: _selectedForCopy.isEmpty ? null : _showCopyToDialog,
                icon: const Icon(Icons.copy),
                label: const Text('Kopírovať do priečinka'),
              ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _folderPath == null ? null : _loadSongs,
              tooltip: 'Obnoviť zoznam',
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _folderPath == null
                ? _buildFolderPrompt()
                : _showPlaylistBuilder
                ? _buildPlaylistBuilderPanel()
                : Row(
                  children: [
                    SizedBox(width: 320, child: _buildSongListPanel()),
                    const VerticalDivider(width: 1),
                    Expanded(child: _buildSongDetailsPanel()),
                  ],
                ),
      ),
    );
  }

  Widget _buildFolderPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Vyber priečinok so skladbami vo formáte .pro'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _pickFolder,
            icon: const Icon(Icons.folder_open),
            label: const Text('Vybrať priečinok'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistBuilderPanel() {
    if (_folderPath == null) {
      return _buildFolderPrompt();
    }

    if (_songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'V priečinku nie sú žiadne skladby na zostavenie playlistu.',
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadSongs,
              icon: const Icon(Icons.refresh),
              label: const Text('Obnoviť zoznam'),
            ),
          ],
        ),
      );
    }

    final desiredWidth = 328 + (_playlistRoundCount * 292);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Playlist: $_playlistSourceTitle',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _folderPath!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Počet kôl'),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: _playlistRoundCount,
                        onChanged: (value) {
                          if (value != null) {
                            _setPlaylistRoundCount(value);
                          }
                        },
                        items: [
                          for (var count = 1; count <= 8; count++)
                            DropdownMenuItem(
                              value: count,
                              child: Text('$count'),
                            ),
                        ],
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: _savePlaylistOrderToFolder,
                    icon: const Icon(Icons.save),
                    label: const Text('Uložiť poradie do priečinka'),
                  ),
                  FilledButton.icon(
                    onPressed: _exportPlaylistToWord,
                    icon: const Icon(Icons.description),
                    label: const Text('Export do Wordu'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _bootstrapPlaylistBuilder(
                          _songsForRelativeDir(_playlistSourceRelativeDir),
                        );
                      });
                    },
                    icon: const Icon(Icons.cleaning_services),
                    label: const Text('Vrátiť všetko späť'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _closePlaylistBuilder,
                    icon: const Icon(Icons.view_list),
                    label: const Text('Späť na knižnicu'),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Posun doľava',
                        onPressed: () => _scrollPlaylistHorizontallyBy(-420),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      IconButton(
                        tooltip: 'Posun doprava',
                        onPressed: () => _scrollPlaylistHorizontallyBy(420),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _playlistSelectedPaths.isEmpty
                            ? null
                            : _clearPlaylistSelection,
                    icon: const Icon(Icons.deselect),
                    label: Text(
                      _playlistSelectedPaths.isEmpty
                          ? 'Bez výberu'
                          : 'Vymazať výber (${_playlistSelectedPaths.length})',
                    ),
                  ),
                  Text(
                    'Nezaradené: ${_playlistUnassigned.length}  |  Spolu: ${_songs.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = math.max(
                  constraints.maxWidth,
                  desiredWidth.toDouble(),
                );

                return Scrollbar(
                  controller: _playlistHorizontalScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: SingleChildScrollView(
                    controller: _playlistHorizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: width,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 316,
                            child: _buildPlaylistBucket(
                              title: 'Nezaradené skladby',
                              subtitle: 'Potiahni ich do jednotlivých kôl',
                              paths: _playlistUnassigned,
                              accentColor:
                                  Theme.of(context).colorScheme.primary,
                              isUnassigned: true,
                              bucketIndex: 0,
                            ),
                          ),
                          const SizedBox(width: 12),
                          for (
                            var index = 0;
                            index < _playlistColumns.length;
                            index++
                          ) ...[
                            SizedBox(
                              width: 280,
                              child: _buildPlaylistBucket(
                                title: 'Kolo ${index + 1}',
                                subtitle: 'Zoradenie pre toto kolo',
                                paths: _playlistColumns[index],
                                accentColor:
                                    Theme.of(context).colorScheme.tertiary,
                                isUnassigned: false,
                                bucketIndex: index,
                              ),
                            ),
                            if (index < _playlistColumns.length - 1)
                              const SizedBox(width: 12),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistBucket({
    required String title,
    required String subtitle,
    required List<String> paths,
    required Color accentColor,
    required bool isUnassigned,
    required int bucketIndex,
  }) {
    final songs =
        [
          for (final path in paths) _songForPath(path),
        ].whereType<ProSongFile>().toList();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Chip(label: Text('${songs.length}')),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child:
                songs.isEmpty
                    ? _buildPlaylistEmptyDropZone(
                      message:
                          isUnassigned
                              ? 'Sem pretiahni skladby z knižnice'
                              : 'Sem pretiahni skladby pre toto kolo',
                      bucketIndex: bucketIndex,
                      isUnassigned: isUnassigned,
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: songs.length * 2 + 1,
                      itemBuilder: (context, index) {
                        if (index.isEven) {
                          final insertIndex = index ~/ 2;
                          return _buildPlaylistDropMarker(
                            isUnassigned: isUnassigned,
                            bucketIndex: bucketIndex,
                            insertIndex: insertIndex,
                          );
                        }

                        final song = songs[index ~/ 2];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildPlaylistSongTile(
                            song,
                            isSelected: _playlistSelectedPaths.contains(
                              song.path,
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistEmptyDropZone({
    required String message,
    required bool isUnassigned,
    required int bucketIndex,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: DragTarget<String>(
        onAcceptWithDetails: (details) {
          _movePlaylistSong(
            details.data,
            toUnassigned: isUnassigned,
            bucketIndex: bucketIndex,
            insertIndex: 0,
          );
        },
        builder: (context, candidateData, rejectedData) {
          final active = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color:
                  active
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    active
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                width: active ? 2 : 1,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaylistDropMarker({
    required bool isUnassigned,
    required int bucketIndex,
    required int insertIndex,
  }) {
    return DragTarget<String>(
      onAcceptWithDetails: (details) {
        _movePlaylistSong(
          details.data,
          toUnassigned: isUnassigned,
          bucketIndex: bucketIndex,
          insertIndex: insertIndex,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: active ? 28 : 14,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color:
                active
                    ? Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.14)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  active
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
              width: 1.5,
            ),
          ),
          child:
              active
                  ? Center(
                    child: Text(
                      'Pusti sem',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                  : const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildPlaylistSongTile(ProSongFile song, {required bool isSelected}) {
    final dragGroup = _dragGroupForPath(song.path);

    return Draggable<String>(
      data: song.path,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: _buildPlaylistSongCard(
            song,
            dragging: true,
            isSelected: isSelected,
            multiDragCount: dragGroup.length,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _buildPlaylistSongCard(song, isSelected: isSelected),
      ),
      child: _buildPlaylistSongCard(song, isSelected: isSelected),
    );
  }

  Widget _buildPlaylistSongCard(
    ProSongFile song, {
    bool dragging = false,
    bool isSelected = false,
    int multiDragCount = 1,
  }) {
    final hasMultiDragBadge = dragging && multiDragCount > 1;

    return Card(
      elevation: dragging ? 4 : 0,
      margin: EdgeInsets.zero,
      color:
          isSelected ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank),
            const SizedBox(width: 8),
            const Icon(Icons.drag_indicator),
          ],
        ),
        title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle:
            song.subtitle == null || song.subtitle!.trim().isEmpty
                ? null
                : Text(
                  song.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        trailing:
            hasMultiDragBadge
                ? CircleAvatar(radius: 13, child: Text('$multiDragCount'))
                : null,
        dense: true,
        onTap: () => _togglePlaylistSelection(song.path),
      ),
    );
  }

  Widget _buildSongListPanel() {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      descendantsAreFocusable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text(
              _folderPath!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (_songs.isEmpty)
            const Expanded(
              child: Center(
                child: Text('V tomto priečinku nie sú žiadne .pro súbory.'),
              ),
            )
          else
            Expanded(child: _buildGroupedSongList()),
        ],
      ),
    );
  }

  Widget _buildGroupedSongList() {
    final folderPath = _folderPath ?? '';
    // group by relative directory under selected folder
    final groups = <String, List<ProSongFile>>{};

    for (var folder in _subfolders) {
      groups[folder] = [];
    }

    for (final song in _songs) {
      var rel = song.path.replaceAll('\\', '/');
      var base = folderPath.replaceAll('\\', '/');
      if (base.isNotEmpty && rel.startsWith(base)) {
        rel = rel.substring(base.length).trimLeft();
        if (rel.startsWith('/')) rel = rel.substring(1);
      }
      final lastSlash = rel.lastIndexOf('/');
      String dir;
      if (lastSlash <= 0) {
        dir = '';
      } else {
        dir = rel.substring(0, lastSlash);
      }
      groups.putIfAbsent(dir, () => []).add(song);
    }

    final sortedKeys =
        groups.keys.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    for (final key in sortedKeys) {
      _applyCustomOrder(key, groups[key]!);
    }

    return ListView(
      children: [
        for (final key in sortedKeys)
          if (key.isEmpty)
            _buildFolderSection(key, '(Hlavný priečinok)', groups[key]!)
          else
            _buildFolderSection(key, key, groups[key]!),
      ],
    );
  }

  Widget _buildFolderSection(
    String relativeDir,
    String title,
    List<ProSongFile> songs,
  ) {
    final isMainFolder = relativeDir.isEmpty;
    final canReorder = !isMainFolder && !_isSelectionMode;
    final canBuildPlaylist = songs.isNotEmpty;

    return ExpansionTile(
      initiallyExpanded: isMainFolder,
      title: Row(
        children: [
          Expanded(child: Text(title)),
          PopupMenuButton<String>(
            tooltip: 'Akcie pre priečinok',
            onSelected: (value) {
              switch (value) {
                case 'playlist':
                  _openPlaylistBuilderForFolder(relativeDir, title, songs);
                  break;
                case 'rename':
                  _renameFolder(relativeDir, title);
                  break;
                case 'duplicate':
                  _duplicateFolder(relativeDir, title);
                  break;
                case 'export':
                  _exportFolderPlaylistToWord(relativeDir, title, songs);
                  break;
                case 'delete':
                  _deleteFolder(relativeDir, title);
                  break;
              }
            },
            itemBuilder: (context) {
              final items = <PopupMenuEntry<String>>[];
              items.add(
                PopupMenuItem(
                  value: 'playlist',
                  enabled: canBuildPlaylist,
                  child: const Text('Zostaviť playlist (drag & drop)'),
                ),
              );
              if (!isMainFolder) {
                items.add(
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('Premenovať priečinok'),
                  ),
                );
                items.add(
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Text('Duplikovať priečinok'),
                  ),
                );
                items.add(
                  const PopupMenuItem(
                    value: 'export',
                    child: Text('Exportovať do Wordu'),
                  ),
                );
                items.add(
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Vymazať priečinok'),
                  ),
                );
              }
              return items;
            },
          ),
        ],
      ),
      children: [
        if (canReorder)
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder:
                (oldIndex, newIndex) => _reorderSongsInFolder(
                  relativeDir,
                  songs,
                  oldIndex,
                  newIndex,
                ),
            children: [
              for (final song in songs)
                _buildSongTile(
                  song,
                  relativeDir: relativeDir,
                  key: ValueKey(song.path),
                ),
            ],
          )
        else
          for (final song in songs)
            _buildSongTile(
              song,
              relativeDir: relativeDir,
              key: ValueKey(song.path),
            ),
      ],
    );
  }

  Widget _buildSongTile(
    ProSongFile song, {
    required String relativeDir,
    Key? key,
  }) {
    final isSelected = song.path == _selectedSong?.path;
    final canDelete = relativeDir.isNotEmpty;
    return ListTile(
      key: key,
      leading:
          _isSelectionMode
              ? Checkbox(
                value: _selectedForCopy.contains(song.path),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedForCopy.add(song.path);
                    } else {
                      _selectedForCopy.remove(song.path);
                    }
                  });
                },
              )
              : null,
      selected: isSelected,
      title: Text(song.title),
      subtitle:
          song.subtitle == null || song.subtitle!.trim().isEmpty
              ? null
              : Text(
                song.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
      trailing:
          _isSelectionMode
              ? null
              : PopupMenuButton<String>(
                tooltip: 'Akcie pre skladbu',
                onSelected: (value) {
                  switch (value) {
                    case 'move':
                      _showCopySingleToDialog(song);
                      break;
                    case 'delete':
                      _deleteSong(song);
                      break;
                  }
                },
                itemBuilder:
                    (context) => [
                      const PopupMenuItem(
                        value: 'move',
                        child: Text('Kopírovať do priečinka'),
                      ),
                      if (canDelete)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Vymazať skladbu'),
                        ),
                    ],
              ),
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (_selectedForCopy.contains(song.path)) {
              _selectedForCopy.remove(song.path);
            } else {
              _selectedForCopy.add(song.path);
            }
          });
        } else {
          _selectSong(song);
        }
      },
    );
  }

  Future<void> _createSubfolder() async {
    final folderPath = _folderPath;
    if (folderPath == null) return;
    final name = await _showNewSubfolderDialog();
    if (name == null || name.trim().isEmpty) return;
    final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final target = '$folderPath${Platform.pathSeparator}$safe';
    final dir = Directory(target);
    try {
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      await _loadSongs();
      _showMessage('Priečinok vytvorený: $safe');
    } catch (e) {
      _showMessage('Nepodarilo sa vytvoriť priečinok: $e');
    }
  }

  Future<String?> _showNewSubfolderDialog({
    String title = 'Nový priečinok',
    String labelText = 'Názov priečinka',
    String? initialValue,
    String confirmLabel = 'Vytvoriť',
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: labelText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Zrušiť'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(value);
              },
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _duplicateFolder(String relativeDir, String title) async {
    if (relativeDir.isEmpty) {
      _showMessage('Koreňový priečinok nie je možné duplikovať.');
      return;
    }

    final folderPath = _folderPath;
    if (folderPath == null) {
      return;
    }

    final normalized = relativeDir.replaceAll('\\', '/');
    final lastSlash = normalized.lastIndexOf('/');
    final parentRelative =
        lastSlash == -1 ? '' : normalized.substring(0, lastSlash);
    final currentName =
        lastSlash == -1 ? normalized : normalized.substring(lastSlash + 1);

    final requestedName = await _showNewSubfolderDialog(
      title: 'Duplikovať priečinok',
      labelText: 'Nový názov priečinka',
      initialValue: '${currentName}_copy',
      confirmLabel: 'Duplikovať',
    );
    if (requestedName == null || requestedName.trim().isEmpty) {
      return;
    }

    final safeName = requestedName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final targetRelative =
        parentRelative.isEmpty ? safeName : '$parentRelative/$safeName';
    if (targetRelative == normalized) {
      _showMessage('Zadaj iný názov priečinka.');
      return;
    }

    final sourcePath =
        '$folderPath${Platform.pathSeparator}${normalized.replaceAll('/', Platform.pathSeparator)}';
    final targetPath =
        '$folderPath${Platform.pathSeparator}${targetRelative.replaceAll('/', Platform.pathSeparator)}';

    final sourceDir = Directory(sourcePath);
    final targetDir = Directory(targetPath);
    if (!sourceDir.existsSync()) {
      _showMessage('Zdrojový priečinok už neexistuje.');
      await _loadSongs();
      return;
    }
    if (targetDir.existsSync()) {
      _showMessage('Priečinok s týmto názvom už existuje.');
      return;
    }

    try {
      await _copyDirectoryRecursively(sourceDir, targetDir);
      _cloneFolderOrderForDuplicate(normalized, targetRelative);
      await _saveFolderOrder();
      await _loadSongs();
      _showMessage('Priečinok bol duplikovaný.');
    } catch (error) {
      _showMessage('Nepodarilo sa duplikovať priečinok: $error');
    }
  }

  Future<void> _renameFolder(String relativeDir, String title) async {
    if (relativeDir.isEmpty) {
      _showMessage('Koreňový priečinok nie je možné premenovať.');
      return;
    }

    final folderPath = _folderPath;
    if (folderPath == null) {
      return;
    }

    final normalized = relativeDir.replaceAll('\\', '/');
    final lastSlash = normalized.lastIndexOf('/');
    final parentRelative =
        lastSlash == -1 ? '' : normalized.substring(0, lastSlash);
    final currentName =
        lastSlash == -1 ? normalized : normalized.substring(lastSlash + 1);

    final requestedName = await _showNewSubfolderDialog(
      title: 'Premenovať priečinok',
      labelText: 'Nový názov priečinka',
      initialValue: currentName,
      confirmLabel: 'Premenovať',
    );
    if (requestedName == null || requestedName.trim().isEmpty) {
      return;
    }

    final safeName = requestedName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final targetRelative =
        parentRelative.isEmpty ? safeName : '$parentRelative/$safeName';
    if (targetRelative == normalized) {
      return;
    }

    final sourcePath =
        '$folderPath${Platform.pathSeparator}${normalized.replaceAll('/', Platform.pathSeparator)}';
    final targetPath =
        '$folderPath${Platform.pathSeparator}${targetRelative.replaceAll('/', Platform.pathSeparator)}';

    final sourceDir = Directory(sourcePath);
    final targetDir = Directory(targetPath);
    if (!sourceDir.existsSync()) {
      _showMessage('Priečinok už neexistuje.');
      await _loadSongs();
      return;
    }
    if (targetDir.existsSync()) {
      _showMessage('Priečinok s týmto názvom už existuje.');
      return;
    }

    try {
      await sourceDir.rename(targetPath);
      _renameFolderOrderPaths(normalized, targetRelative);
      await _saveFolderOrder();

      if (_showPlaylistBuilder &&
          (_playlistSourceRelativeDir == normalized ||
              _playlistSourceRelativeDir.startsWith('$normalized/'))) {
        final suffix = _playlistSourceRelativeDir.substring(normalized.length);
        _playlistSourceRelativeDir = '$targetRelative$suffix';
        if (_playlistSourceRelativeDir == targetRelative) {
          _playlistSourceTitle = safeName;
        }
      }

      await _loadSongs();
      _showMessage('Priečinok bol premenovaný.');
    } catch (error) {
      _showMessage('Nepodarilo sa premenovať priečinok: $error');
    }
  }

  Future<void> _copyDirectoryRecursively(
    Directory source,
    Directory target,
  ) async {
    if (!target.existsSync()) {
      target.createSync(recursive: true);
    }

    final sourcePath = source.path;
    for (final entity in source.listSync(recursive: true, followLinks: false)) {
      final suffix = entity.path.substring(sourcePath.length);
      final normalizedSuffix =
          suffix.startsWith(Platform.pathSeparator)
              ? suffix.substring(1)
              : suffix;
      final targetPath =
          '${target.path}${Platform.pathSeparator}$normalizedSuffix';

      if (entity is Directory) {
        Directory(targetPath).createSync(recursive: true);
      } else if (entity is File) {
        final parent = File(targetPath).parent;
        if (!parent.existsSync()) {
          parent.createSync(recursive: true);
        }
        entity.copySync(targetPath);
      }
    }
  }

  void _renameFolderOrderPaths(String oldRelativeDir, String newRelativeDir) {
    final normalizedOld = oldRelativeDir.replaceAll('\\', '/');
    final normalizedNew = newRelativeDir.replaceAll('\\', '/');
    final folderPath = _folderPath;
    if (folderPath == null) {
      return;
    }

    final updatedEntries = <String, List<String>>{};
    final keysToRemove = <String>[];

    for (final entry in _folderOrder.entries) {
      final key = entry.key.replaceAll('\\', '/');
      if (key != normalizedOld && !key.startsWith('$normalizedOld/')) {
        continue;
      }

      final suffix = key.substring(normalizedOld.length);
      final newKey = '$normalizedNew$suffix';
      final newPaths = <String>[];
      for (final absolutePath in entry.value) {
        final rel = _relativeSongPath(absolutePath);
        if (rel == null) {
          continue;
        }
        final normalizedRel = rel.replaceAll('\\', '/');
        if (!normalizedRel.startsWith('$normalizedOld/')) {
          continue;
        }
        final relSuffix = normalizedRel.substring(normalizedOld.length);
        final mappedRel = '$normalizedNew$relSuffix';
        newPaths.add(
          '$folderPath${Platform.pathSeparator}${mappedRel.replaceAll('/', Platform.pathSeparator)}',
        );
      }

      keysToRemove.add(entry.key);
      updatedEntries[newKey] = newPaths;
    }

    for (final key in keysToRemove) {
      _folderOrder.remove(key);
    }
    _folderOrder.addAll(updatedEntries);
  }

  void _cloneFolderOrderForDuplicate(
    String sourceRelativeDir,
    String targetRelativeDir,
  ) {
    final normalizedSource = sourceRelativeDir.replaceAll('\\', '/');
    final normalizedTarget = targetRelativeDir.replaceAll('\\', '/');
    final folderPath = _folderPath;
    if (folderPath == null) {
      return;
    }

    final clonedEntries = <String, List<String>>{};
    for (final entry in _folderOrder.entries) {
      final key = entry.key.replaceAll('\\', '/');
      if (key != normalizedSource && !key.startsWith('$normalizedSource/')) {
        continue;
      }

      final keySuffix = key.substring(normalizedSource.length);
      final newKey = '$normalizedTarget$keySuffix';
      final newPaths = <String>[];
      for (final absolutePath in entry.value) {
        final rel = _relativeSongPath(absolutePath);
        if (rel == null) {
          continue;
        }
        final normalizedRel = rel.replaceAll('\\', '/');
        if (!normalizedRel.startsWith('$normalizedSource/')) {
          continue;
        }
        final relSuffix = normalizedRel.substring(normalizedSource.length);
        final mappedRel = '$normalizedTarget$relSuffix';
        newPaths.add(
          '$folderPath${Platform.pathSeparator}${mappedRel.replaceAll('/', Platform.pathSeparator)}',
        );
      }
      clonedEntries[newKey] = newPaths;
    }

    _folderOrder.addAll(clonedEntries);
  }

  Future<void> _showCopySingleToDialog(ProSongFile song) async {
    final folderPath = _folderPath;
    if (folderPath == null) return;

    final list = {'', ..._subfolders}.toList()..sort();
    final chosen = await showDialog<String?>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Kopírovať do priečinka'),
          children: [
            for (final d in list)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(d),
                child: Text(d.isEmpty ? '(Hlavný priečinok)' : d),
              ),
            SimpleDialogOption(
              onPressed: () async {
                Navigator.of(context).pop();
                final newName = await _showNewSubfolderDialog();
                if (newName != null && newName.trim().isNotEmpty) {
                  await _copySingleSongToSubfolder(song, newName.trim());
                }
              },
              child: const Text('Vytvoriť nový priečinok...'),
            ),
          ],
        );
      },
    );

    if (chosen != null) {
      await _copySingleSongToSubfolder(song, chosen);
    }
  }

  Future<void> _deleteFolder(String relativeDir, String title) async {
    if (relativeDir.isEmpty) {
      _showMessage('Koreňový priečinok nie je možné vymazať.');
      return;
    }

    final folderPath = _folderPath;
    if (folderPath == null) return;

    final confirmed = await _confirmDelete(
      title: 'Vymazať priečinok',
      message:
          'Naozaj chceš vymazať priečinok "$title" vrátane všetkých skladieb v ňom?',
      destructiveLabel: 'Vymazať priečinok',
    );
    if (!confirmed) {
      return;
    }

    final targetPath =
        '$folderPath${Platform.pathSeparator}${relativeDir.replaceAll('/', Platform.pathSeparator)}';

    try {
      final directory = Directory(targetPath);
      if (!directory.existsSync()) {
        _showMessage('Priečinok už neexistuje.');
        await _loadSongs();
        return;
      }

      await directory.delete(recursive: true);
      _cleanupFolderOrderAfterDeletion(relativeDir);
      await _loadSongs();
      _showMessage('Priečinok bol vymazaný.');
    } catch (error) {
      _showMessage('Nepodarilo sa vymazať priečinok: $error');
    }
  }

  Future<void> _deleteSong(ProSongFile song) async {
    final relativePath = _relativeSongPath(song.path);
    if (relativePath == null || !relativePath.contains('/')) {
      _showMessage(
        'Skladbu z koreňového priečinka nie je možné vymazať týmto spôsobom.',
      );
      return;
    }

    final confirmed = await _confirmDelete(
      title: 'Vymazať skladbu',
      message: 'Naozaj chceš vymazať skladbu "${song.title} z priečinka"?',
      destructiveLabel: 'Vymazať skladbu z priečinka',
    );
    if (!confirmed) {
      return;
    }

    try {
      final file = File(song.path);
      if (!file.existsSync()) {
        _showMessage('Súbor už neexistuje.');
        await _loadSongs();
        return;
      }

      await file.delete();
      if (_selectedSong?.path == song.path) {
        _selectedSong = null;
        _editorController.clear();
        await _persistSelectedSongPath(null);
      }
      await _loadSongs();
      _showMessage('Skladba bola vymazaná z priečinka.');
    } catch (error) {
      _showMessage('Nepodarilo sa vymazať skladbu: $error');
    }
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
    required String destructiveLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Zrušiť'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(destructiveLabel),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  String? _relativeSongPath(String songPath) {
    final folderPath = _folderPath;
    if (folderPath == null || folderPath.isEmpty) {
      return null;
    }

    final normalizedSongPath = songPath.replaceAll('\\', '/');
    var normalizedRoot = folderPath.replaceAll('\\', '/');
    if (!normalizedRoot.endsWith('/')) {
      normalizedRoot = '$normalizedRoot/';
    }

    if (!normalizedSongPath.startsWith(normalizedRoot)) {
      return null;
    }

    return normalizedSongPath.substring(normalizedRoot.length);
  }

  void _cleanupFolderOrderAfterDeletion(String deletedRelativeDir) {
    final normalizedDeleted = deletedRelativeDir.replaceAll('\\', '/');
    _folderOrder.removeWhere(
      (key, _) =>
          key == normalizedDeleted || key.startsWith('$normalizedDeleted/'),
    );
    _saveFolderOrder();
  }

  Future<void> _copySingleSongToSubfolder(
    ProSongFile song,
    String relativeDir,
  ) async {
    final folderPath = _folderPath;
    if (folderPath == null) return;
    final file = File(song.path);
    if (!file.existsSync()) {
      _showMessage('Súbor neexistuje.');
      await _loadSongs();
      return;
    }
    final fileName = SongRepository.basename(song.path);
    final safeRel = relativeDir.replaceAll('\\', '/').trim();
    final targetDirPath =
        safeRel.isEmpty
            ? folderPath
            : '$folderPath${Platform.pathSeparator}${safeRel.replaceAll('/', Platform.pathSeparator)}';
    final targetDir = Directory(targetDirPath);
    try {
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }
      final targetPath = '$targetDirPath${Platform.pathSeparator}$fileName';
      var finalTarget = targetPath;
      var counter = 1;
      while (File(finalTarget).existsSync()) {
        finalTarget =
            '$targetDirPath${Platform.pathSeparator}${SongRepository.basenameWithoutExtension(fileName)}_copy$counter${fileName.substring(fileName.lastIndexOf('.'))}';
        counter++;
      }
      await file.copy(finalTarget);
      await _loadSongs(preferredSongPath: finalTarget);
      _showMessage('Súbor skopírovaný.');
    } catch (e) {
      _showMessage('Nepodarilo sa skopírovať súbor: $e');
    }
  }

  Future<void> _showCopyToDialog() async {
    final folderPath = _folderPath;
    if (folderPath == null) return;
    final list = {'', ..._subfolders}.toList()..sort();
    final chosen = await showDialog<String?>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Kopírovať do priečinka'),
          children: [
            for (final d in list)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(d),
                child: Text(d.isEmpty ? '(Hlavný priečinok)' : d),
              ),
            SimpleDialogOption(
              onPressed: () async {
                Navigator.of(context).pop();
                final newName = await _showNewSubfolderDialog();
                if (newName != null && newName.trim().isNotEmpty) {
                  await _copySelectedToSubfolder(newName.trim());
                }
              },
              child: const Text('Vytvoriť nový priečinok...'),
            ),
          ],
        );
      },
    );

    if (chosen != null) {
      await _copySelectedToSubfolder(chosen);
    }
  }

  Future<void> _copySelectedToSubfolder(String relativeDir) async {
    final folderPath = _folderPath;
    if (folderPath == null) return;
    final selected = _selectedForCopy.toList();
    if (selected.isEmpty) return;
    for (final path in selected) {
      final song = _songs.firstWhere(
        (s) => s.path == path,
        orElse:
            () => ProSongFile(
              path: path,
              title: SongRepository.basenameWithoutExtension(path),
              subtitle: null,
              content: '',
            ),
      );
      await _copySongToSubfolder(song, relativeDir);
    }
    setState(() {
      _selectedForCopy.clear();
      _isSelectionMode = false;
    });
    await _loadSongs();
    _showMessage('Kopírovanie dokončené.');
  }

  Future<void> _copySongToSubfolder(
    ProSongFile song,
    String relativeDir,
  ) async {
    final folderPath = _folderPath;
    if (folderPath == null) return;
    final file = File(song.path);
    if (!file.existsSync()) {
      _showMessage('Súbor neexistuje: ${song.path}');
      return;
    }
    final fileName = SongRepository.basename(song.path);
    final safeRel = relativeDir.replaceAll('\\', '/').trim();
    final targetDirPath =
        safeRel.isEmpty
            ? folderPath
            : '$folderPath${Platform.pathSeparator}${safeRel.replaceAll('/', Platform.pathSeparator)}';
    final targetDir = Directory(targetDirPath);
    try {
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }
      final targetPath = '$targetDirPath${Platform.pathSeparator}$fileName';
      // If file exists, append suffix
      var finalTarget = targetPath;
      var counter = 1;
      while (File(finalTarget).existsSync()) {
        finalTarget =
            '$targetDirPath${Platform.pathSeparator}${SongRepository.basenameWithoutExtension(fileName)}_copy$counter${fileName.substring(fileName.lastIndexOf('.'))}';
        counter++;
      }
      await file.copy(finalTarget);
    } catch (e) {
      _showMessage('Nepodarilo sa skopírovať súbor: $e');
    }
  }

  Widget _buildSongDetailsPanel() {
    final selectedSong = _selectedSong;
    if (selectedSong == null) {
      return const Center(child: Text('Vyber pieseň zo zoznamu.'));
    }

    final parsedSong = ParsedSong.fromContent(
      selectedSong.content,
      fallbackTitle: SongRepository.basenameWithoutExtension(selectedSong.path),
    );
    final displayLines = SongDisplayBuilder.build(parsedSong.lines);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parsedSong.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (parsedSong.subtitle != null)
                      Text(
                        parsedSong.subtitle!,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _changeTransposeBy(-1),
                tooltip: 'Transpozícia -1',
                icon: const Icon(Icons.remove),
              ),
              Text('$_transposeSemitones'),
              IconButton(
                onPressed: () => _changeTransposeBy(1),
                tooltip: 'Transpozícia +1',
                icon: const Icon(Icons.add),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _transposeSemitones = 0;
                  });
                },
                child: const Text('Reset'),
              ),
              TextButton.icon(
                onPressed:
                    _isEditing || _transposeSemitones == 0
                        ? null
                        : _saveCurrentTransposition,
                icon: const Icon(Icons.save_as),
                label: const Text('Uložiť transpozíciu'),
              ),
              TextButton.icon(
                onPressed: _isEditing ? null : _printCurrentSong,
                icon: const Icon(Icons.print),
                label: const Text('Tlačiť'),
              ),
              IconButton(
                onPressed:
                    _isEditing
                        ? null
                        : () => _openPerformanceMode(parsedSong, displayLines),
                tooltip: 'Zobraziť na celej obrazovke',
                icon: const Icon(Icons.fullscreen),
              ),
              const SizedBox(width: 8),
              if (_isEditing)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _transformEditorToChordPro,
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('Na ChordPro'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _saveCurrentSong,
                      icon: const Icon(Icons.save),
                      label: const Text('Uložiť'),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                      _editorController.text = selectedSong.content;
                    });
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Upraviť'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child:
                _isEditing
                    ? TextField(
                      controller: _editorController,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                        labelText: 'ChordPro obsah',
                      ),
                      style: const TextStyle(fontFamily: 'monospace'),
                    )
                    : Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: ListView.builder(
                        controller: _previewScrollController,
                        itemCount: displayLines.length,
                        itemBuilder: (context, index) {
                          final line = displayLines[index];
                          return ChordLineView(
                            line: line.rawLine,
                            inChorus: line.isChorus,
                            transposeSemitones: _transposeSemitones,
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class SongPerformancePage extends StatefulWidget {
  const SongPerformancePage({
    required this.title,
    required this.subtitle,
    required this.displayLines,
    required this.initialTransposeSemitones,
    required this.initialScrollSpeedPixelsPerSecond,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<SongDisplayLine> displayLines;
  final int initialTransposeSemitones;
  final double initialScrollSpeedPixelsPerSecond;

  @override
  State<SongPerformancePage> createState() => _SongPerformancePageState();
}

class _SongPerformancePageState extends State<SongPerformancePage> {
  late int _transposeSemitones = widget.initialTransposeSemitones;
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  late double _scrollSpeedPixelsPerSecond;
  bool _isAutoScrolling = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scrollSpeedPixelsPerSecond = widget.initialScrollSpeedPixelsPerSecond;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _startAutoScroll();
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _changeTransposeBy(int delta) {
    setState(() {
      _transposeSemitones = (_transposeSemitones + delta).clamp(-11, 11);
    });
  }

  void _changeScrollSpeedBy(double delta) {
    setState(() {
      _scrollSpeedPixelsPerSecond = (_scrollSpeedPixelsPerSecond + delta).clamp(
        4,
        120,
      );
    });
  }

  void _toggleAutoScroll() {
    if (_isAutoScrolling) {
      _stopAutoScroll();
      return;
    }

    setState(() {
      _isAutoScrolling = true;
    });
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted || !_isAutoScrolling || !_scrollController.hasClients) {
        return;
      }

      final position = _scrollController.position;
      if (!position.hasPixels || !position.hasContentDimensions) {
        return;
      }

      final maxExtent = position.maxScrollExtent;
      final minExtent = position.minScrollExtent;
      if (maxExtent <= minExtent) {
        return;
      }

      final delta = _scrollSpeedPixelsPerSecond / 60;
      final nextOffset = (position.pixels + delta).clamp(minExtent, maxExtent);
      _scrollController.jumpTo(nextOffset);

      final reachedBottom = nextOffset >= maxExtent - 0.5;
      if (reachedBottom) {
        _stopAutoScroll();
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _isAutoScrolling = false;
    });
  }

  void _scrollFullscreenBy(double delta) {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _scrollController.jumpTo(target);
  }

  double _fontScaleForSingleColumn(
    BoxConstraints constraints,
    List<SongDisplayLine> lines,
  ) {
    const baseFontSize = 14.0;
    final lyricStyle = const TextStyle(
      fontFamily: 'monospace',
      fontSize: baseFontSize,
    );
    final chordStyle = const TextStyle(
      fontFamily: 'monospace',
      fontSize: baseFontSize,
      fontWeight: FontWeight.w600,
    );

    final lyricCharWidth = _measureTextWidth(context, 'M', lyricStyle);
    final chordCharWidth = _measureTextWidth(context, 'M', chordStyle);
    if (lyricCharWidth <= 0 || chordCharWidth <= 0) {
      return 1.0;
    }

    var maxLineWidth = 0.0;
    for (final line in lines) {
      final rendered = RenderedChordLine.fromRaw(
        line.rawLine,
        transposeSemitones: _transposeSemitones,
      );

      var lineWidth = rendered.lyricLinePlain.length * lyricCharWidth;
      for (final placement in rendered.chordPlacements) {
        final chordRight =
            (placement.position * lyricCharWidth) +
            (placement.chord.length * chordCharWidth);
        lineWidth = math.max(lineWidth, chordRight);
      }

      maxLineWidth = math.max(maxLineWidth, lineWidth);
    }

    if (maxLineWidth <= 1) {
      return 1.0;
    }

    final widthByContent = (constraints.maxWidth - 44) / (maxLineWidth + 12);
    final heightBoost = (constraints.maxHeight / 900).clamp(1.0, 1.35);
    final scale = widthByContent * 0.95 * heightBoost;
    return scale.clamp(0.9, 2.8);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        leading: IconButton(
          tooltip: 'Zavrieť full screen',
          icon: const Icon(Icons.fullscreen_exit),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            onPressed: () => _changeTransposeBy(-1),
            tooltip: 'Transpozícia -1',
            icon: const Icon(Icons.remove),
          ),
          Center(child: Text('$_transposeSemitones')),
          IconButton(
            onPressed: () => _changeTransposeBy(1),
            tooltip: 'Transpozícia +1',
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () => _changeScrollSpeedBy(-4),
            tooltip: 'Spomaliť scrollovanie',
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Center(child: Text('${_scrollSpeedPixelsPerSecond.round()} px/s')),
          IconButton(
            onPressed: () => _changeScrollSpeedBy(4),
            tooltip: 'Zrýchliť scrollovanie',
            icon: const Icon(Icons.add_circle_outline),
          ),
          IconButton(
            onPressed: _toggleAutoScroll,
            tooltip:
                _isAutoScrolling
                    ? 'Zastaviť scrollovanie'
                    : 'Spustiť scrollovanie',
            icon: Icon(
              _isAutoScrolling ? Icons.pause_circle : Icons.play_circle,
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _transposeSemitones = 0;
              });
            },
            child: const Text('Reset'),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final fontScale = _fontScaleForSingleColumn(
            constraints,
            widget.displayLines,
          );

          return Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                return KeyEventResult.ignored;
              }

              final key = event.logicalKey;
              if (key == LogicalKeyboardKey.space) {
                _toggleAutoScroll();
                return KeyEventResult.handled;
              }

              if (key == LogicalKeyboardKey.escape) {
                Navigator.of(context).pop();
                return KeyEventResult.handled;
              }

              if (key == LogicalKeyboardKey.arrowDown) {
                _scrollFullscreenBy(64);
                return KeyEventResult.handled;
              }

              if (key == LogicalKeyboardKey.arrowUp) {
                _scrollFullscreenBy(-64);
                return KeyEventResult.handled;
              }

              if (key == LogicalKeyboardKey.add ||
                  key == LogicalKeyboardKey.numpadAdd ||
                  key == LogicalKeyboardKey.equal) {
                _changeScrollSpeedBy(4);
                return KeyEventResult.handled;
              }

              if (key == LogicalKeyboardKey.minus ||
                  key == LogicalKeyboardKey.numpadSubtract) {
                _changeScrollSpeedBy(-4);
                return KeyEventResult.handled;
              }

              return KeyEventResult.ignored;
            },
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: widget.displayLines.length,
              itemBuilder: (context, index) {
                final line = widget.displayLines[index];
                return ChordLineView(
                  line: line.rawLine,
                  inChorus: line.isChorus,
                  transposeSemitones: _transposeSemitones,
                  fontScale: fontScale,
                );
              },
            ),
          );
        },
      ),
    );
  }
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

class _VisualChord {
  _VisualChord({required this.chord, required this.left});

  final String chord;
  final double left;
}

class _PlaylistPlacement {
  _PlaylistPlacement({
    required this.isUnassigned,
    required this.bucketIndex,
    required this.itemIndex,
  });

  final bool isUnassigned;
  final int bucketIndex;
  final int itemIndex;
}

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

class _PdfColumnBlock {
  _PdfColumnBlock({
    required this.widget,
    required this.heightSingleColumn,
    required this.heightTwoColumn,
  });

  final pw.Widget widget;
  final double heightSingleColumn;
  final double heightTwoColumn;
}

class _PdfSongPage {
  const _PdfSongPage({required this.leftColumn, required this.rightColumn});

  final List<pw.Widget> leftColumn;
  final List<pw.Widget> rightColumn;
}

class SongDisplayBuilder {
  static List<SongDisplayLine> build(List<String> lines) {
    final output = <SongDisplayLine>[];
    var inChorus = false;

    for (final line in lines) {
      final directive = ParsedSong.tryParseDirective(line);
      if (directive != null) {
        final key = directive.key;
        if (key == 'title' || key == 'subtitle') {
          continue;
        }
        if (key == 'soc' || key == 'start_of_chorus') {
          inChorus = true;
          continue;
        }
        if (key == 'eoc' || key == 'end_of_chorus') {
          inChorus = false;
          continue;
        }
        // Skip any other standalone directive lines (e.g. {scrollspeed: 20})
        continue;
      }

      output.add(SongDisplayLine(rawLine: line, isChorus: inChorus));
    }

    return output;
  }
}

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

class _PlaylistEntry {
  const _PlaylistEntry({required this.title, this.bpm})
    : isRoundSeparator = false;

  const _PlaylistEntry.roundSeparator()
    : title = '------------------',
      bpm = null,
      isRoundSeparator = true;

  final String title;
  final int? bpm;
  final bool isRoundSeparator;
}

class _WordPlaylistBuilder {
  static Uint8List build({
    required String folderTitle,
    required List<_PlaylistEntry> entries,
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
    List<_PlaylistEntry> entries,
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
