// ignore_for_file: use_build_context_synchronously
// Hlavná stránka aplikácie: zoznam skladieb, editor, export do PDF/Wordu, playlist builder.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';
import '../services/song_display_builder.dart';
import '../services/song_file_order.dart';
import '../services/google_drive_repository.dart';
import '../services/song_repository.dart';
import '../services/word_playlist_builder.dart';
import '../utils/chord_transposer.dart';
import '../utils/chordpro_converter.dart';
import '../widgets/chord_line_view.dart';
import 'song_performance_page.dart';

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
  static const String _prefDriveFolderUrl = 'google_drive_folder_url';
  // OAuth Client ID z Google Cloud Console (typ Web application).
  // Je verejný, môžeš ho vložiť sem alebo zadať cez --dart-define=GOOGLE_CLIENT_ID=...
  static const String _googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '794458736034-mu7ghlmkspm2n931h04esfc450f92cst.apps.googleusercontent.com',
  );

  // Pevne daný priečinok so skladbami na Google Disku (odkaz na priečinok).
  // Po vyplnení sa používateľ len prihlási a odkaz už nezadáva. Priečinok musí
  // byť zdieľaný ako "Každý, kto má odkaz". Pri prázdnej hodnote sa odkaz pýta
  // ako predtým. Dá sa zadať aj cez --dart-define=DRIVE_FOLDER_URL=...
  static const String _fixedDriveFolderUrl = String.fromEnvironment(
    'DRIVE_FOLDER_URL',
    defaultValue:
        'https://drive.google.com/drive/folders/14rkqNiABz2MediqhVbh-X_3yXa4muaZA?usp=sharing',
  );

  bool get _hasFixedFolder => kIsWeb && _fixedDriveFolderUrl.isNotEmpty;

  String _folderActionLabel() =>
      _hasFixedFolder
          ? 'Prihlásiť sa'
          : (kIsWeb ? 'Priečinok Google Disku' : 'Vybrať priečinok');

  String? _configuredFolderUrl(SharedPreferences prefs) =>
      _hasFixedFolder
          ? _fixedDriveFolderUrl
          : prefs.getString(_prefDriveFolderUrl);

  final TextEditingController _editorController = TextEditingController();
  final FocusNode _hotkeysFocusNode = FocusNode();
  final ScrollController _previewScrollController = ScrollController();
  final ScrollController _playlistHorizontalScrollController =
      ScrollController();
  final TextEditingController _songSearchController = TextEditingController();
  final FocusNode _songSearchFocusNode = FocusNode();
  // Dopyt je v ValueNotifier, aby písanie neprekresľovalo celú stránku
  // (detail piesne sa pri každom setState znovu parsuje).
  final ValueNotifier<String> _songSearchQuery = ValueNotifier<String>('');
  final Map<String, _SongSearchEntry> _songSearchIndex = {};

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
  String? _cloudAccount;
  final List<ProSongFile> _songs = [];
  ProSongFile? _selectedSong;
  bool _isLoading = false;
  bool _isSyncing = false; // obnova na pozadí, zoznam ostáva viditeľný
  bool _needsDriveLogin = false; // vypršalo prihlásenie do Google Disku
  bool _mobileDetailOpen = false; // na mobile: otvorený detail skladby
  // Kľúč vybranej skladby v zozname, aby sa k nej dalo doscrollovať.
  final GlobalKey _selectedTileKey = GlobalKey();
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
    _songSearchController.dispose();
    _songSearchQuery.dispose();
    _songSearchFocusNode.dispose();
    _previewScrollController.dispose();
    _playlistHorizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (kIsWeb) {
      final sharingUrl = _configuredFolderUrl(prefs);
      if (sharingUrl == null || sharingUrl.isEmpty || _googleClientId.isEmpty) {
        return;
      }

      final repository = GoogleDriveRepository.instance;
      var restoredFromCache = false;
      try {
        _cloudAccount = await repository.initializeAuth(_googleClientId);

        // 1) Hneď zobraz naposledy uložený zoznam (bez čakania na Google).
        final snapshot = await repository.restoreSnapshot(sharingUrl);
        if (snapshot != null && mounted) {
          final storedSelectedPath = prefs.getString(_prefSelectedSongPath);
          ProSongFile? selected;
          for (final song in snapshot.songs) {
            if (song.path == storedSelectedPath) {
              selected = song;
              break;
            }
          }
          selected ??= snapshot.songs.isNotEmpty ? snapshot.songs.first : null;

          setState(() {
            _folderPath = snapshot.root.path;
            _songs
              ..clear()
              ..addAll(snapshot.songs);
            _subfolders = snapshot.folders;
            _selectedSong = selected;
          });
          _editorController.text = selected?.content ?? '';
          restoredFromCache = true;
          _scrollListToSelected();
        }

        // 2) Na pozadí zoznam aktualizuj, ak je prihlásenie ešte platné.
        if (repository.isSignedIn) {
          final root = await repository.openSharedFolder(sharingUrl);
          if (!mounted) return;
          setState(() {
            _folderPath = root.path;
          });
          await _loadSongs(background: restoredFromCache);
        } else if (mounted) {
          // Bez kliknutia používateľa prehliadač nepustí prihlasovacie okno.
          setState(() {
            _needsDriveLogin = true;
          });
        }
      } catch (error) {
        if (!mounted) return;
        if (restoredFromCache) {
          setState(() {
            _isSyncing = false;
            _needsDriveLogin = _isAuthExpired(error);
          });
        } else {
          setState(() {
            _folderPath = null;
          });
        }
      }
      return;
    }

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
    if (kIsWeb) {
      await _connectGoogleDriveFolder();
      return;
    }

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

  Future<void> _connectGoogleDriveFolder() async {
    if (_googleClientId.isEmpty) {
      _showMessage('Najprv nastav GOOGLE_CLIENT_ID z Google Cloud Console.');
      return;
    }

    try {
      final repository = GoogleDriveRepository.instance;
      _cloudAccount = await repository.initializeAuth(_googleClientId);
      if (!repository.isSignedIn) {
        _cloudAccount = await repository.signIn() ?? _cloudAccount;
      }
      if (_cloudAccount == null) return;

      final prefs = await SharedPreferences.getInstance();
      final sharingUrl =
          _hasFixedFolder
              ? _fixedDriveFolderUrl
              : await _showDriveUrlDialog(
                initialValue: prefs.getString(_prefDriveFolderUrl),
              );
      if (sharingUrl == null || sharingUrl.isEmpty) return;

      final root = await repository.openSharedFolder(sharingUrl);
      if (!_hasFixedFolder) {
        await prefs.setString(_prefDriveFolderUrl, sharingUrl);
      }
      if (!mounted) return;

      setState(() {
        _folderPath = root.path;
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
    } catch (error) {
      final account = _cloudAccount;
      _showMessage(
        account == null
            ? 'Nepodarilo sa pripojiť Google Disk: $error'
            : _hasFixedFolder
            ? 'Google Disk odmietol prístup pre účet $account. Skontroluj, že je priečinok zdieľaný ako "Každý, kto má odkaz". ($error)'
            : 'Google Disk odmietol prístup pre účet $account. Odhlás sa a použi účet, s ktorým je priečinok zdieľaný. Skontroluj, že má oprávnenie na úpravy. ($error)',
      );
    }
  }

  bool _isAuthExpired(Object error) {
    final text = error.toString();
    return text.contains('vypršalo') ||
        text.contains('Najprv sa prihlás') ||
        text.contains('(401)');
  }

  /// Volá sa z kliknutia na tlačidlo. Až vtedy smie prehliadač otvoriť
  /// prihlasovacie okno Google.
  Future<void> _reconnectGoogleDrive() async {
    final repository = GoogleDriveRepository.instance;
    try {
      final account = await repository.signIn();
      if (account != null) _cloudAccount = account;

      final prefs = await SharedPreferences.getInstance();
      final sharingUrl = _configuredFolderUrl(prefs);
      if (sharingUrl == null || sharingUrl.isEmpty) {
        if (mounted) setState(() => _needsDriveLogin = false);
        return;
      }

      final root = await repository.openSharedFolder(sharingUrl);
      if (!mounted) return;
      setState(() {
        _folderPath = root.path;
        _needsDriveLogin = false;
      });
      await _loadSongs(background: true);
    } catch (error) {
      if (mounted) {
        _showMessage('Prihlásenie do Google Disku zlyhalo: $error');
      }
    }
  }

  Widget _buildDriveLoginBanner() {
    return MaterialBanner(
      leading: const Icon(Icons.cloud_off),
      content: const Text(
        'Prihlásenie do Google Disku vypršalo. Zobrazuje sa naposledy '
        'načítaný zoznam.',
      ),
      actions: [
        TextButton(
          onPressed: _reconnectGoogleDrive,
          child: const Text('Prihlásiť sa'),
        ),
      ],
    );
  }

  Future<String?> _showDriveUrlDialog({String? initialValue}) async {
    final controller = TextEditingController(text: initialValue ?? '');
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Zdieľaný priečinok Google Disku'),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Odkaz na priečinok na Google Disku',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Zrušiť'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.of(context).pop(controller.text.trim()),
                child: const Text('Otvoriť'),
              ),
            ],
          ),
    );
  }

  Future<void> _signOutGoogleDrive() async {
    try {
      await GoogleDriveRepository.instance.signOut();
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefDriveFolderUrl);
      await prefs.remove(_prefSelectedSongPath);
      if (mounted) {
        setState(() {
          _cloudAccount = null;
          _mobileDetailOpen = false;
          _needsDriveLogin = false;
          _isSyncing = false;
          _folderPath = null;
          _songs.clear();
          _selectedSong = null;
          _subfolders = [];
          _editorController.clear();
          _isEditing = false;
        });
      }
    }
  }

  Future<void> _loadSongs({
    String? preferredSongPath,
    bool showErrors = true,
    bool background = false,
  }) async {
    final folderPath = _folderPath;
    if (folderPath == null || folderPath.isEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        if (background) {
          _isSyncing = true;
        } else {
          _isLoading = true;
        }
      });
    }

    try {
      final loadedSongs =
          kIsWeb
              ? await GoogleDriveRepository.instance.loadSongs()
              : await SongRepository.loadFromFolder(folderPath);
      final loadedFolders =
          kIsWeb
              ? GoogleDriveRepository.instance.getAllSubfolders()
              : SongRepository.getAllSubfolders(folderPath);

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

      // Pri obnove na pozadí neprerušíme úpravy ani transpozíciu práve
      // otvorenej skladby.
      final keepState = background && selected?.path == _selectedSong?.path;
      final keepEditing = keepState && _isEditing;

      setState(() {
        _songs
          ..clear()
          ..addAll(loadedSongs);
        _selectedSong = selected;
        _subfolders = loadedFolders;
        if (!keepState) {
          _isEditing = false;
          _transposeSemitones = 0;
        }
        if (_showPlaylistBuilder) {
          _refreshPlaylistBuilderSource(loadedSongs);
        }
        _isLoading = false;
        _isSyncing = false;
        _needsDriveLogin = false;
      });

      if (!keepEditing) {
        if (selected != null) {
          _editorController.text = selected.content;
        } else {
          _editorController.clear();
        }
      }

      await _persistSelectedSongPath(selected?.path);
      _requestHotkeysFocus();
    } catch (error) {
      if (!mounted) {
        return;
      }
      final authExpired = kIsWeb && _isAuthExpired(error);
      setState(() {
        _isLoading = false;
        _isSyncing = false;
        if (authExpired) _needsDriveLogin = true;
      });
      if (showErrors && !authExpired) {
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
    // Skladby s uloženým kolom ("K2-05 - ...") sa vrátia do svojho kola.
    int? savedRound(ProSongFile song) =>
        _playlistSourceRelativeDir.isEmpty
            ? null
            : SongFileOrder.roundOf(SongRepository.basename(song.path));

    var highestRound = 0;
    for (final song in sourceSongs) {
      highestRound = math.max(highestRound, savedRound(song) ?? 0);
    }
    if (highestRound > _playlistRoundCount) {
      _playlistRoundCount = highestRound.clamp(1, 8);
    }

    _playlistColumns = List.generate(_playlistRoundCount, (_) => <String>[]);
    _playlistUnassigned = [];
    for (final song in sourceSongs) {
      final round = savedRound(song);
      if (round != null && round >= 1 && round <= _playlistRoundCount) {
        _playlistColumns[round - 1].add(song.path);
      } else {
        _playlistUnassigned.add(song.path);
      }
    }
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
    final result =
        from
            .where((song) => _songDirectoryRelative(song.path) == relativeDir)
            .toList();
    _applyCustomOrder(relativeDir, result);
    return result;
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

    if (relativeDir.isEmpty) {
      // Hlavný priečinok: poradie sa pamätá len v tomto zariadení.
      setState(() {
        _folderOrder[relativeDir] =
            orderedSongs.map((song) => song.path).toList();
      });
      await _saveFolderOrder();
    } else {
      // Podpriečinok: poradie a kolá sa uložia do názvov súborov
      // (napr. K1-01 - ..., K2-05 - ...). Nezaradené skladby kolo nemajú.
      final rounds = <String, int?>{};
      for (var i = 0; i < _playlistColumns.length; i++) {
        for (final path in _playlistColumns[i]) {
          rounds[path] = i + 1;
        }
      }
      for (final path in _playlistUnassigned) {
        rounds[path] = null;
      }
      await _saveFolderOrderToFiles(relativeDir, orderedSongs, rounds: rounds);
    }

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

    final entries = <PlaylistEntry>[];
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
        entries.add(PlaylistEntry(title: parsed.title, bpm: parsed.bpm));
      }

      final isLastNonEmptyRound = i == nonEmptyRoundIndexes.last;
      if (!isLastNonEmptyRound) {
        entries.add(const PlaylistEntry.roundSeparator());
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
      entries.add(PlaylistEntry(title: parsed.title, bpm: parsed.bpm));
    }

    final folderTitle =
        _playlistSourceTitle.isEmpty
            ? (_folderPath == null || _folderPath!.isEmpty
                ? 'playlist'
                : SongRepository.basename(_folderPath!))
            : _playlistSourceTitle;

    final bytes = WordPlaylistBuilder.build(
      folderTitle: folderTitle,
      entries: entries,
    );

    final suggestedName =
        '${folderTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}_playlist.docx';

    try {
      if (!await _saveExportBytes(bytes, suggestedName)) return;
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

    final entries = <PlaylistEntry>[
      for (final song in songs)
        PlaylistEntry(
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

    final bytes = WordPlaylistBuilder.build(
      folderTitle: folderTitle,
      entries: entries,
    );

    final suggestedName =
        '${folderTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}_playlist.docx';

    try {
      if (!await _saveExportBytes(bytes, suggestedName)) return;
      _showMessage('Playlist bol exportovaný do Wordu.');
    } catch (error) {
      _showMessage('Nepodarilo sa exportovať playlist: $error');
    }
  }

  Future<bool> _saveExportBytes(List<int> bytes, String fileName) async {
    final suggestedName =
        fileName.toLowerCase().endsWith('.docx') ? fileName : '$fileName.docx';
    if (kIsWeb) {
      await FilePicker.platform.saveFile(
        fileName: suggestedName,
        bytes: Uint8List.fromList(bytes),
        type: FileType.custom,
        allowedExtensions: ['docx'],
      );
      return true;
    }

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Uložiť playlist ako Word dokument',
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: ['docx'],
    );
    if (savePath == null) return false;
    final finalPath =
        savePath.toLowerCase().endsWith('.docx') ? savePath : '$savePath.docx';
    await File(finalPath).writeAsBytes(bytes, flush: true);
    return true;
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
    if (adjustedNewIndex == oldIndex) {
      return;
    }

    final updated = List<ProSongFile>.from(currentOrder);
    final moved = updated.removeAt(oldIndex);
    updated.insert(adjustedNewIndex, moved);

    // Presunutá skladba prevezme kolo skladby nad sebou (alebo pod sebou,
    // ak je na začiatku). Ostatné si kolo ponechajú.
    int? roundOf(ProSongFile song) =>
        SongFileOrder.roundOf(SongRepository.basename(song.path));
    Map<String, int?>? rounds;
    if (updated.any((song) => roundOf(song) != null)) {
      rounds = {for (final song in updated) song.path: roundOf(song)};
      final neighbor =
          adjustedNewIndex > 0
              ? updated[adjustedNewIndex - 1]
              : (updated.length > 1 ? updated[1] : null);
      rounds[moved.path] = neighbor == null ? null : roundOf(neighbor);
    }

    unawaited(_saveFolderOrderToFiles(relativeDir, updated, rounds: rounds));
  }

  String _replaceFileName(String path, String newName) {
    final separator = math.max(path.lastIndexOf('/'), path.lastIndexOf('\\'));
    return separator < 0
        ? newName
        : '${path.substring(0, separator + 1)}$newName';
  }

  /// Uloží poradie skladieb v podpriečinku do názvov súborov
  /// ("01 - Názov.pro", "02 - Názov.pro", ...). Premenujú sa len súbory,
  /// ktorým sa číslo zmenilo. Nové poradie sa zobrazí hneď.
  Future<void> _saveFolderOrderToFiles(
    String relativeDir,
    List<ProSongFile> ordered, {
    Map<String, int?>? rounds,
  }) async {
    final width = SongFileOrder.widthFor(ordered.length);
    final renames = <String, String>{}; // pôvodná cesta -> nová cesta
    for (var index = 0; index < ordered.length; index++) {
      final song = ordered[index];
      final currentName = SongRepository.basename(song.path);
      // Kolo sa ukladá do názvu ("K2-05 - ..."). Bez zadaných kôl ostáva
      // každej skladbe jej doterajšie kolo.
      final round =
          rounds != null ? rounds[song.path] : SongFileOrder.roundOf(currentName);
      final targetName = SongFileOrder.withOrder(
        currentName,
        index + 1,
        width: width,
        round: round,
      );
      if (targetName != currentName) {
        renames[song.path] = _replaceFileName(song.path, targetName);
      }
    }

    setState(() {
      for (var i = 0; i < _songs.length; i++) {
        final newPath = renames[_songs[i].path];
        if (newPath == null) continue;
        final old = _songs[i];
        final renamed = ProSongFile(
          path: newPath,
          title: old.title,
          subtitle: old.subtitle,
          content: old.content,
        );
        if (_selectedSong?.path == old.path) {
          _selectedSong = renamed;
        }
        _songs[i] = renamed;
      }
      _remapPlaylistPaths(renames);
      _folderOrder.remove(relativeDir);
      if (renames.isNotEmpty) {
        _isSyncing = true;
      }
    });
    if (renames.isNotEmpty) {
      unawaited(_persistSelectedSongPath(_selectedSong?.path));
    }

    try {
      if (kIsWeb) {
        await GoogleDriveRepository.instance.renameSongs(renames);
      } else {
        for (final entry in renames.entries) {
          await SongRepository.renameFile(entry.key, entry.value);
        }
      }
      await _saveFolderOrder();
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    } catch (error) {
      _showMessage('Nepodarilo sa uložiť poradie skladieb: $error');
      // Zobraz skutočný stav z disku.
      await _loadSongs(background: true, showErrors: false);
    }
  }

  void _remapPlaylistPaths(Map<String, String> renames) {
    if (renames.isEmpty) return;
    String mapPath(String path) => renames[path] ?? path;
    _playlistColumns = [
      for (final column in _playlistColumns)
        [for (final p in column) mapPath(p)],
    ];
    _playlistUnassigned = [for (final p in _playlistUnassigned) mapPath(p)];
    final selected = _playlistSelectedPaths.map(mapPath).toList();
    _playlistSelectedPaths
      ..clear()
      ..addAll(selected);
  }

  /// Poradie v podpriečinkoch určujú číselné predpony v názvoch súborov
  /// ("01 - Názov.pro"). Skladby bez predpony idú na koniec. Staré poradie
  /// uložené len v tomto zariadení sa použije, kým priečinok nemá očíslované súbory.
  void _applyCustomOrder(String relativeDir, List<ProSongFile> songs) {
    if (relativeDir.isNotEmpty) {
      int? numberOf(ProSongFile song) =>
          SongFileOrder.orderOf(SongRepository.basename(song.path));

      if (songs.any((song) => numberOf(song) != null)) {
        final original = {
          for (var i = 0; i < songs.length; i++) songs[i].path: i,
        };
        songs.sort((a, b) {
          final numberA = numberOf(a);
          final numberB = numberOf(b);
          if (numberA != null && numberB != null) {
            final byNumber = numberA.compareTo(numberB);
            if (byNumber != 0) return byNumber;
          } else if (numberA != null) {
            return -1;
          } else if (numberB != null) {
            return 1;
          }
          return original[a.path]!.compareTo(original[b.path]!);
        });
        return;
      }
    }

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

  /// Skladby aktuálneho priečinka v poradí playlistu (tak, ako sú v zozname).
  List<ProSongFile> _playlistOrderForSelected() {
    final selected = _selectedSong;
    if (selected == null) return const [];
    return _songsForRelativeDir(_relativeDirOf(selected.path));
  }

  int? _roundOfSong(ProSongFile song) =>
      _relativeDirOf(song.path).isEmpty
          ? null
          : SongFileOrder.roundOf(SongRepository.basename(song.path));

  String _positionLabel(List<ProSongFile> order, int index) {
    final round = _roundOfSong(order[index]);
    final position = '${index + 1} / ${order.length}';
    return round == null ? position : 'Kolo $round · $position';
  }

  bool _canMoveSong(int delta) {
    final selected = _selectedSong;
    if (selected == null) return false;
    final order = _playlistOrderForSelected();
    final index = order.indexWhere((song) => song.path == selected.path);
    final target = index + delta;
    return index >= 0 && target >= 0 && target < order.length;
  }

  /// Prepne na predchádzajúcu (-1) alebo nasledujúcu (+1) skladbu v poradí playlistu.
  ProSongFile? _moveSelectedSong(int delta) {
    if (_isEditing || !_canMoveSong(delta)) return null;
    final order = _playlistOrderForSelected();
    final index = order.indexWhere((song) => song.path == _selectedSong!.path);
    final target = order[index + delta];
    _selectSong(target);
    _scrollListToSelected();
    return target;
  }

  /// Dáta pre fullscreen pri prepnutí skladby šípkami.
  PerformanceSong? _performanceSongAfterMove(int delta) {
    final song = _moveSelectedSong(delta);
    if (song == null) return null;
    final parsed = ParsedSong.fromContent(
      song.content,
      fallbackTitle: SongRepository.basenameWithoutExtension(song.path),
    );
    final order = _playlistOrderForSelected();
    final index = order.indexWhere((item) => item.path == song.path);
    return PerformanceSong(
      title: parsed.title,
      subtitle: parsed.subtitle,
      displayLines: SongDisplayBuilder.build(parsed.lines),
      scrollSpeed: parsed.scrollSpeed,
      positionLabel: index >= 0 ? _positionLabel(order, index) : null,
    );
  }

  /// Doscrolluje zoznam k vybranej skladbe (po návrate z detailu alebo
  /// po prepnutí šípkami).
  void _scrollListToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tileContext = _selectedTileKey.currentContext;
      if (!mounted || tileContext == null) return;
      // Na mobile je zoznam pri otvorenom detaile skrytý, tam netreba animáciu.
      final listHidden =
          MediaQuery.sizeOf(context).width < 700 && _mobileDetailOpen;
      Scrollable.ensureVisible(
        tileContext,
        alignment: 0.35,
        duration: listHidden ? Duration.zero : const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _closeMobileDetail() {
    setState(() => _mobileDetailOpen = false);
    _scrollListToSelected();
  }

  void _selectSong(ProSongFile song) {
    setState(() {
      _selectedSong = song;
      _isEditing = false;
      _transposeSemitones = 0;
      _editorController.text = song.content;
      _mobileDetailOpen = true;
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

  bool _isTextInputFocused() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _requestHotkeysFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // hasFocus je true aj keď má focus potomok (napr. vyhľadávacie pole),
      // preto sa kontroluje priamo primárny focus.
      if (FocusManager.instance.primaryFocus != _hotkeysFocusNode) {
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
      if (kIsWeb) {
        await GoogleDriveRepository.instance.saveSong(
          selectedSong.path,
          updatedContent,
        );
      } else {
        await SongRepository.saveSong(selectedSong.path, updatedContent);
      }
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
    final path = '$folderPath$_pathSeparator$safeName';

    const initialContent = '{title: Nová pieseň}\n{subtitle: }\n\n';

    try {
      if (kIsWeb) {
        await GoogleDriveRepository.instance.createSong(path, initialContent);
      } else {
        final file = File(path);
        if (file.existsSync()) {
          _showMessage('Súbor s týmto názvom už existuje.');
          return;
        }
        await SongRepository.saveSong(path, initialContent);
      }
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
        _mobileDetailOpen = true;
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

      if (kIsWeb) {
        await GoogleDriveRepository.instance.saveSong(
          selectedSong.path,
          transposedContent,
        );
      } else {
        await SongRepository.saveSong(selectedSong.path, transposedContent);
      }
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

  String? _currentPositionLabel() {
    final selected = _selectedSong;
    if (selected == null) return null;
    final order = _playlistOrderForSelected();
    final index = order.indexWhere((song) => song.path == selected.path);
    if (index < 0 || order.length < 2) return null;
    return _positionLabel(order, index);
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
              onSaveScrollSpeed: _saveScrollSpeedToSong,
              positionLabel: _currentPositionLabel(),
              canChangeSong: _canMoveSong,
              onChangeSong: _performanceSongAfterMove,
            ),
      ),
    );
  }

  /// Zapíše {scrollspeed: N} do aktuálne vybranej piesne (existujúci flag prepíše).
  Future<void> _saveScrollSpeedToSong(double speed) async {
    final selectedSong = _selectedSong;
    if (selectedSong == null) {
      throw StateError('Nie je vybraná žiadna pieseň.');
    }

    final newContent = _withScrollSpeedDirective(
      selectedSong.content,
      speed.round(),
    );
    if (kIsWeb) {
      await GoogleDriveRepository.instance.saveSong(
        selectedSong.path,
        newContent,
      );
    } else {
      await SongRepository.saveSong(selectedSong.path, newContent);
    }

    if (!mounted) return;
    setState(() {
      selectedSong.content = newContent;
      if (!_isEditing) {
        _editorController.text = newContent;
      }
    });
  }

  static String _withScrollSpeedDirective(String content, int speed) {
    final newline = content.contains('\r\n') ? '\r\n' : '\n';
    final directive = '{scrollspeed: $speed}';
    final lines = content.split(RegExp(r'\r?\n'));

    final existing = RegExp(
      r'^\s*\{\s*scroll[_-]?speed\s*:.*\}\s*$',
      caseSensitive: false,
    );
    final existingIndex = lines.indexWhere(existing.hasMatch);
    if (existingIndex >= 0) {
      lines[existingIndex] = directive;
      return lines.join(newline);
    }

    // Nový flag sa vloží za posledný title/subtitle riadok, inak na začiatok.
    final header = RegExp(
      r'^\s*\{\s*(title|subtitle|t|st)\s*:',
      caseSensitive: false,
    );
    var insertAt = 0;
    for (var i = 0; i < lines.length; i++) {
      if (header.hasMatch(lines[i])) insertAt = i + 1;
    }
    lines.insert(insertAt, directive);
    return lines.join(newline);
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
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final isCompactToolbar = viewportWidth < 1120;
    final isNarrowToolbar = viewportWidth < 600;
    final isPhone = viewportWidth < 700;
    final isTablet = !isPhone && viewportWidth < 1100;
    // Na mobile sa zobrazuje buď zoznam, alebo detail skladby.
    final showMobileDetail =
        isPhone &&
        _mobileDetailOpen &&
        _selectedSong != null &&
        _folderPath != null &&
        !_showPlaylistBuilder &&
        !_isLoading;

    return Focus(
      focusNode: _hotkeysFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }

        // Pri písaní do ľubovoľného textového poľa (hľadanie, editor) nesmú
        // šípky/medzerník/backspace spúšťať skratky.
        if (_songSearchFocusNode.hasFocus || _isTextInputFocused()) {
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
          toolbarHeight: isPhone ? 60 : 76,
          leadingWidth: showMobileDetail ? 56 : (isNarrowToolbar ? 120 : 170),
          leading:
              showMobileDetail
                  ? IconButton(
                    onPressed: _closeMobileDetail,
                    tooltip: 'Späť na zoznam',
                    icon: const Icon(Icons.arrow_back),
                  )
                  : Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                    child: Image.asset(
                      widget.themeMode == ThemeMode.dark
                          ? 'chordhub biely text.png'
                          : 'chordhub cierny text.png',
                      fit: BoxFit.fitWidth,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
          actions:
              isPhone
                  ? _phoneAppBarActions()
                  : [
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
                    // S pevne daným priečinkom je tlačidlo len na prihlásenie a po
                    // pripojení sa skryje.
                    if (!(_hasFixedFolder && _folderPath != null))
                      if (isNarrowToolbar)
                        IconButton(
                          onPressed: _pickFolder,
                          tooltip: _folderActionLabel(),
                          icon: Icon(
                            _hasFixedFolder ? Icons.login : Icons.folder_open,
                          ),
                        )
                      else
                        TextButton.icon(
                          onPressed: _pickFolder,
                          icon: Icon(
                            _hasFixedFolder ? Icons.login : Icons.folder_open,
                          ),
                          label: Text(
                            _hasFixedFolder
                                ? 'Prihlásiť sa'
                                : (isCompactToolbar
                                    ? (kIsWeb ? 'Google Disk' : 'Priečinok')
                                    : (kIsWeb
                                        ? 'Priečinok Google Disku'
                                        : 'Vybrať priečinok')),
                          ),
                        ),
                    if (kIsWeb)
                      IconButton(
                        onPressed: _signOutGoogleDrive,
                        tooltip:
                            _cloudAccount == null
                                ? 'Odhlásiť Google účet'
                                : 'Odhlásiť $_cloudAccount',
                        icon: const Icon(Icons.logout),
                      ),
                    if (isCompactToolbar)
                      PopupMenuButton<String>(
                        tooltip: 'Akcie',
                        onSelected: (value) {
                          switch (value) {
                            case 'new_song':
                              _createNewProSong();
                              break;
                            case 'new_folder':
                              _createSubfolder();
                              break;
                            case 'selection':
                              _toggleSelectionMode();
                              break;
                            case 'copy':
                              _showCopyToDialog();
                              break;
                          }
                        },
                        itemBuilder:
                            (context) => [
                              PopupMenuItem(
                                value: 'new_song',
                                enabled: _folderPath != null,
                                child: const Text('Pridať akordy'),
                              ),
                              PopupMenuItem(
                                value: 'new_folder',
                                enabled: _folderPath != null,
                                child: const Text('Nový priečinok'),
                              ),
                              PopupMenuItem(
                                value: 'selection',
                                enabled: _folderPath != null,
                                child: Text(
                                  _isSelectionMode
                                      ? 'Zrušiť výber'
                                      : 'Vybrať skladby do priečinka',
                                ),
                              ),
                              if (_isSelectionMode)
                                PopupMenuItem(
                                  value: 'copy',
                                  enabled: _selectedForCopy.isNotEmpty,
                                  child: const Text('Kopírovať do priečinka'),
                                ),
                            ],
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.more_horiz),
                        ),
                      )
                    else ...[
                      TextButton.icon(
                        onPressed:
                            _folderPath == null ? null : _createNewProSong,
                        icon: const Icon(Icons.note_add),
                        label: const Text('Pridať akordy'),
                      ),
                      TextButton.icon(
                        onPressed:
                            _folderPath == null ? null : _createSubfolder,
                        icon: const Icon(Icons.create_new_folder),
                        label: const Text('Nový priečinok'),
                      ),
                      TextButton.icon(
                        onPressed:
                            _folderPath == null ? null : _toggleSelectionMode,
                        icon: Icon(
                          _isSelectionMode ? Icons.close : Icons.checklist,
                        ),
                        label: Text(
                          _isSelectionMode
                              ? 'Zrušiť výber'
                              : 'Vyber skladby do priečinka',
                        ),
                      ),
                      if (_isSelectionMode)
                        TextButton.icon(
                          onPressed:
                              _selectedForCopy.isEmpty
                                  ? null
                                  : _showCopyToDialog,
                          icon: const Icon(Icons.copy),
                          label: const Text('Kopírovať do priečinka'),
                        ),
                    ],
                    IconButton(
                      onPressed:
                          _folderPath == null
                              ? null
                              : (kIsWeb && _needsDriveLogin
                                  ? _reconnectGoogleDrive
                                  : _loadSongs),
                      tooltip: 'Obnoviť zoznam',
                      icon: const Icon(Icons.refresh),
                    ),
                    const SizedBox(width: 8),
                  ],
        ),
        body: PopScope(
          // Tlačidlo Späť na mobile zavrie detail skladby namiesto opustenia aplikácie.
          canPop: !showMobileDetail,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _closeMobileDetail();
          },
          child: Column(
            children: [
              if (_isSyncing) const LinearProgressIndicator(minHeight: 2),
              if (kIsWeb && _needsDriveLogin && _folderPath != null)
                _buildDriveLoginBanner(),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _folderPath == null
                        ? _buildFolderPrompt()
                        : _showPlaylistBuilder
                        ? _buildPlaylistBuilderPanel()
                        : isPhone
                        // Zoznam ostáva v strome (len skrytý), takže po návrate z
                        // detailu je na rovnakom mieste a s rozbalenými priečinkami.
                        ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Offstage(
                              offstage: showMobileDetail,
                              child: _buildSongListPanel(),
                            ),
                            if (showMobileDetail) _buildSongDetailsPanel(),
                          ],
                        )
                        : Row(
                          children: [
                            SizedBox(
                              width: isTablet ? 280 : 320,
                              child: _buildSongListPanel(),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(child: _buildSongDetailsPanel()),
                          ],
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _refreshPressed() {
    if (kIsWeb && _needsDriveLogin) {
      _reconnectGoogleDrive();
    } else {
      _loadSongs();
    }
  }

  /// Na úzkej obrazovke je v lište len obnovenie a jedno menu so všetkým ostatným.
  List<Widget> _phoneAppBarActions() {
    final hasFolder = _folderPath != null;
    return [
      IconButton(
        onPressed: hasFolder ? _refreshPressed : null,
        tooltip: 'Obnoviť zoznam',
        icon: const Icon(Icons.refresh),
      ),
      PopupMenuButton<String>(
        tooltip: 'Menu',
        onSelected: (value) {
          switch (value) {
            case 'new_song':
              _createNewProSong();
              break;
            case 'new_folder':
              _createSubfolder();
              break;
            case 'selection':
              _toggleSelectionMode();
              break;
            case 'copy':
              _showCopyToDialog();
              break;
            case 'folder':
              _pickFolder();
              break;
            case 'theme':
              widget.onToggleThemeMode();
              break;
            case 'logout':
              _signOutGoogleDrive();
              break;
          }
        },
        itemBuilder:
            (context) => [
              PopupMenuItem(
                value: 'new_song',
                enabled: hasFolder,
                child: const Text('Pridať akordy'),
              ),
              PopupMenuItem(
                value: 'new_folder',
                enabled: hasFolder,
                child: const Text('Nový priečinok'),
              ),
              PopupMenuItem(
                value: 'selection',
                enabled: hasFolder,
                child: Text(
                  _isSelectionMode
                      ? 'Zrušiť výber'
                      : 'Vybrať skladby do priečinka',
                ),
              ),
              if (_isSelectionMode)
                PopupMenuItem(
                  value: 'copy',
                  enabled: _selectedForCopy.isNotEmpty,
                  child: const Text('Kopírovať do priečinka'),
                ),
              const PopupMenuDivider(),
              if (!(_hasFixedFolder && hasFolder))
                PopupMenuItem(
                  value: 'folder',
                  child: Text(_folderActionLabel()),
                ),
              PopupMenuItem(
                value: 'theme',
                child: Text(
                  widget.themeMode == ThemeMode.dark
                      ? 'Svetlý režim'
                      : 'Tmavý režim',
                ),
              ),
              if (kIsWeb)
                PopupMenuItem(
                  value: 'logout',
                  child: Text(
                    _cloudAccount == null
                        ? 'Odhlásiť Google účet'
                        : 'Odhlásiť $_cloudAccount',
                  ),
                ),
            ],
      ),
    ];
  }

  Widget _buildFolderPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _hasFixedFolder
                ? 'Prihlás sa do Google účtu, aby sa načítal spevník.'
                : (kIsWeb
                    ? 'Pripoj zdieľaný priečinok Google Disku so skladbami.'
                    : 'Vyber priečinok so skladbami vo formáte .pro'),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _pickFolder,
            icon: Icon(_hasFixedFolder ? Icons.login : Icons.folder_open),
            label: Text(
              _hasFixedFolder
                  ? 'Prihlásiť sa do Google'
                  : (kIsWeb ? 'Pripojiť Google Disk' : 'Vybrať priečinok'),
            ),
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

    final isPhone = MediaQuery.sizeOf(context).width < 700;

    return Padding(
      padding: EdgeInsets.all(isPhone ? 8 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: EdgeInsets.all(isPhone ? 10 : 16),
              child: ConstrainedBox(
                // Na mobile hlavička nezaberie celú obrazovku, dá sa v nej rolovať.
                constraints: BoxConstraints(
                  maxHeight:
                      isPhone
                          ? MediaQuery.sizeOf(context).height * 0.3
                          : double.infinity,
                ),
                child: SingleChildScrollView(
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
                            onPressed:
                                () => _scrollPlaylistHorizontallyBy(-420),
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
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 700;
                final unassignedWidth =
                    narrow
                        ? math.min(316.0, constraints.maxWidth * 0.85)
                        : 316.0;
                final roundWidth =
                    narrow
                        ? math.min(280.0, constraints.maxWidth * 0.8)
                        : 280.0;
                final neededWidth =
                    unassignedWidth +
                    12 +
                    _playlistRoundCount * (roundWidth + 12);
                final width = math.max(constraints.maxWidth, neededWidth);

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
                            width: unassignedWidth,
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
                              width: roundWidth,
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
    return Column(
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
        if (_songs.isNotEmpty) _buildSongSearchField(),
        Expanded(
          // Zoznam skladieb zostáva nefocusovateľný (kvôli klávesovým skratkám),
          // vyhľadávacie pole je preto mimo tohto Focus widgetu.
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            descendantsAreFocusable: false,
            child:
                _songs.isEmpty
                    ? const Center(
                      child: Text(
                        'V tomto priečinku nie sú žiadne .pro súbory.',
                      ),
                    )
                    : ValueListenableBuilder<String>(
                      valueListenable: _songSearchQuery,
                      builder:
                          (context, query, _) => _buildGroupedSongList(query),
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildSongSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: ValueListenableBuilder<String>(
        valueListenable: _songSearchQuery,
        builder:
            (context, query, _) => TextField(
              controller: _songSearchController,
              focusNode: _songSearchFocusNode,
              onChanged: (value) => _songSearchQuery.value = value,
              onSubmitted: (_) {
                _songSearchFocusNode.unfocus();
                _requestHotkeysFocus();
              },
              onTapOutside: (_) {
                if (_songSearchFocusNode.hasFocus) {
                  _songSearchFocusNode.unfocus();
                  _requestHotkeysFocus();
                }
              },
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Hľadať v aktuálnom priečinku',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    query.isNotEmpty
                        ? IconButton(
                          tooltip: 'Vymazať hľadanie',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _songSearchController.clear();
                            _songSearchQuery.value = '';
                          },
                        )
                        : null,
                border: const OutlineInputBorder(),
              ),
            ),
      ),
    );
  }

  /// Relatívny priečinok skladby voči koreňovému priečinku ('' = hlavný).
  String _relativeDirOf(String songPath) {
    var rel = songPath.replaceAll('\\', '/');
    final base = (_folderPath ?? '').replaceAll('\\', '/');
    if (base.isNotEmpty && rel.startsWith(base)) {
      rel = rel.substring(base.length).trimLeft();
      if (rel.startsWith('/')) rel = rel.substring(1);
    }
    final lastSlash = rel.lastIndexOf('/');
    return lastSlash <= 0 ? '' : rel.substring(0, lastSlash);
  }

  /// Aktuálny priečinok = priečinok práve vybranej skladby (inak hlavný).
  String get _currentRelativeDir {
    final selected = _selectedSong;
    return selected == null ? '' : _relativeDirOf(selected.path);
  }

  /// Malé písmená, bez diakritiky a bez ChordPro akordov/direktív.
  static String _normalizeForSearch(
    String input, {
    bool stripChordPro = false,
  }) {
    var text = input;
    if (stripChordPro) {
      text = text.replaceAll(RegExp(r'\[[^\]]*\]|\{[^}]*\}'), '');
    }
    const from = 'áäčďéěíĺľňóôöŕřšťúůüýž';
    const to = 'aacdeeillnooorrstuuuyz';
    final buffer = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      final idx = from.indexOf(ch);
      buffer.write(idx >= 0 ? to[idx] : ch);
    }
    return buffer.toString();
  }

  bool _songMatchesQuery(ProSongFile song, String normalizedQuery) {
    final words = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    final entry = _searchEntryFor(song);
    // Každé zadané slovo sa musí nachádzať v názve alebo v interpretovi (podnadpise).
    return words.every((w) => entry.haystack.contains(w));
  }

  /// Normalizovaný názov a interpret sa počíta len raz (a znovu až po zmene).
  _SongSearchEntry _searchEntryFor(ProSongFile song) {
    final cached = _songSearchIndex[song.path];
    if (cached != null &&
        cached.title == song.title &&
        cached.subtitle == song.subtitle) {
      return cached;
    }
    final entry = _SongSearchEntry(
      title: song.title,
      subtitle: song.subtitle,
      haystack: _normalizeForSearch('${song.title} ${song.subtitle ?? ''}'),
    );
    _songSearchIndex[song.path] = entry;
    return entry;
  }

  Widget _buildGroupedSongList(String query) {
    // group by relative directory under selected folder
    final groups = <String, List<ProSongFile>>{};

    for (var folder in _subfolders) {
      groups[folder] = [];
    }

    for (final song in _songs) {
      groups.putIfAbsent(_relativeDirOf(song.path), () => []).add(song);
    }

    final sortedKeys =
        groups.keys.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    for (final key in sortedKeys) {
      _applyCustomOrder(key, groups[key]!);
    }

    final normalizedQuery = _normalizeForSearch(query.trim());
    if (normalizedQuery.isNotEmpty) {
      // Hľadanie: zobrazí sa len aktuálny priečinok a v ňom zhodné skladby.
      final currentDir = _currentRelativeDir;
      final folderSongs = groups[currentDir] ?? <ProSongFile>[];
      final matches =
          folderSongs
              .where((song) => _songMatchesQuery(song, normalizedQuery))
              .toList();
      return ListView(
        children: [
          _buildFolderSection(
            currentDir,
            currentDir.isEmpty ? '(Hlavný priečinok)' : currentDir,
            folderSongs,
            visibleSongs: matches,
            isFiltering: true,
          ),
          if (matches.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nič sa nenašlo.'),
            ),
        ],
      );
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
    List<ProSongFile> songs, {
    List<ProSongFile>? visibleSongs,
    bool isFiltering = false,
  }) {
    final isMainFolder = relativeDir.isEmpty;
    // Pri filtrovaní sa preusporadúvanie vypína (indexy by nesedeli).
    final canReorder = !isMainFolder && !_isSelectionMode && !isFiltering;
    final canBuildPlaylist = songs.isNotEmpty;
    final shownSongs = visibleSongs ?? songs;

    return ExpansionTile(
      key: ValueKey(
        isFiltering ? 'search_folder_$relativeDir' : 'folder_$relativeDir',
      ),
      initiallyExpanded:
          isMainFolder ||
          isFiltering ||
          (_selectedSong != null &&
              _relativeDirOf(_selectedSong!.path) == relativeDir),
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
          for (final song in shownSongs)
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
    // Kolo playlistu (len mimo hlavného priečinka).
    final round =
        relativeDir.isEmpty
            ? null
            : SongFileOrder.roundOf(SongRepository.basename(song.path));
    final tile = ListTile(
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
      title:
          round == null
              ? Text(song.title)
              : Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Kolo $round',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  Expanded(child: Text(song.title)),
                ],
              ),
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
    return KeyedSubtree(
      key: key,
      child: isSelected ? KeyedSubtree(key: _selectedTileKey, child: tile) : tile,
    );
  }

  Future<void> _createSubfolder() async {
    final folderPath = _folderPath;
    if (folderPath == null) return;
    final name = await _showNewSubfolderDialog();
    if (name == null || name.trim().isEmpty) return;
    final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    try {
      if (kIsWeb) {
        await GoogleDriveRepository.instance.createFolder(safe);
      } else {
        final target = '$folderPath$_pathSeparator$safe';
        final dir = Directory(target);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
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

    try {
      if (kIsWeb) {
        await GoogleDriveRepository.instance.duplicateFolder(
          normalized,
          targetRelative,
        );
      } else {
        final sourcePath =
            '$folderPath$_pathSeparator${normalized.replaceAll('/', _pathSeparator)}';
        final targetPath =
            '$folderPath$_pathSeparator${targetRelative.replaceAll('/', _pathSeparator)}';
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
        await _copyDirectoryRecursively(sourceDir, targetDir);
      }
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

    try {
      if (kIsWeb) {
        await GoogleDriveRepository.instance.renameFolder(normalized, safeName);
      } else {
        final sourcePath =
            '$folderPath$_pathSeparator${normalized.replaceAll('/', _pathSeparator)}';
        final targetPath =
            '$folderPath$_pathSeparator${targetRelative.replaceAll('/', _pathSeparator)}';
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
        await sourceDir.rename(targetPath);
      }
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
          suffix.startsWith(_pathSeparator) ? suffix.substring(1) : suffix;
      final targetPath = '${target.path}$_pathSeparator$normalizedSuffix';

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
          '$folderPath$_pathSeparator${mappedRel.replaceAll('/', _pathSeparator)}',
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
          '$folderPath$_pathSeparator${mappedRel.replaceAll('/', _pathSeparator)}',
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

    try {
      if (kIsWeb) {
        await GoogleDriveRepository.instance.deleteFolder(relativeDir);
      } else {
        final targetPath =
            '$folderPath$_pathSeparator${relativeDir.replaceAll('/', _pathSeparator)}';
        final directory = Directory(targetPath);
        if (!directory.existsSync()) {
          _showMessage('Priečinok už neexistuje.');
          await _loadSongs();
          return;
        }
        await directory.delete(recursive: true);
      }
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
      if (kIsWeb) {
        await GoogleDriveRepository.instance.deleteSong(song.path);
      } else {
        final file = File(song.path);
        if (!file.existsSync()) {
          _showMessage('Súbor už neexistuje.');
          await _loadSongs();
          return;
        }
        await file.delete();
      }
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

  String get _pathSeparator => kIsWeb ? '/' : Platform.pathSeparator;

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
    final safeRel = relativeDir.replaceAll('\\', '/').trim();
    if (kIsWeb) {
      try {
        final targetPath = await GoogleDriveRepository.instance.copySong(
          song.path,
          safeRel,
        );
        await _loadSongs(preferredSongPath: targetPath);
        _showMessage('Súbor skopírovaný.');
      } catch (error) {
        _showMessage('Nepodarilo sa skopírovať súbor: $error');
      }
      return;
    }

    final file = File(song.path);
    if (!file.existsSync()) {
      _showMessage('Súbor neexistuje.');
      await _loadSongs();
      return;
    }
    final fileName = SongRepository.basename(song.path);
    final targetDirPath =
        safeRel.isEmpty
            ? folderPath
            : '$folderPath$_pathSeparator${safeRel.replaceAll('/', _pathSeparator)}';
    final targetDir = Directory(targetDirPath);
    try {
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }
      // V podpriečinku s očíslovanými skladbami sa kópia zaradí na koniec.
      final finalName = SongFileOrder.nameForCopy(
        sourceFileName: fileName,
        targetIsSubfolder: safeRel.isNotEmpty,
        existingNames: [
          for (final entity in targetDir.listSync())
            if (entity is File) SongRepository.basename(entity.path),
        ],
      );
      final finalTarget = '$targetDirPath$_pathSeparator$finalName';
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
    final safeRel = relativeDir.replaceAll('\\', '/').trim();
    if (kIsWeb) {
      try {
        await GoogleDriveRepository.instance.copySong(song.path, safeRel);
      } catch (error) {
        _showMessage('Nepodarilo sa skopírovať súbor: $error');
      }
      return;
    }

    final file = File(song.path);
    if (!file.existsSync()) {
      _showMessage('Súbor neexistuje: ${song.path}');
      return;
    }
    final fileName = SongRepository.basename(song.path);
    final targetDirPath =
        safeRel.isEmpty
            ? folderPath
            : '$folderPath$_pathSeparator${safeRel.replaceAll('/', _pathSeparator)}';
    final targetDir = Directory(targetDirPath);
    try {
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }
      // V podpriečinku s očíslovanými skladbami sa kópia zaradí na koniec.
      final finalName = SongFileOrder.nameForCopy(
        sourceFileName: fileName,
        targetIsSubfolder: safeRel.isNotEmpty,
        existingNames: [
          for (final entity in targetDir.listSync())
            if (entity is File) SongRepository.basename(entity.path),
        ],
      );
      final finalTarget = '$targetDirPath$_pathSeparator$finalName';
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // wide: všetko v jednom riadku, medium: tlačidlá pod názvom,
        // compact: tlačidlá bez popisov a menšie písmo pre mobil.
        final wide = constraints.maxWidth >= 980;
        final compact = constraints.maxWidth < 560;

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              parsedSong.title,
              style: Theme.of(context).textTheme.headlineSmall,
              maxLines: wide ? 1 : 2,
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
        );

        final transposeControls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
          ],
        );

        final VoidCallback? saveTranspositionAction =
            _isEditing || _transposeSemitones == 0
                ? null
                : _saveCurrentTransposition;
        final VoidCallback? printAction = _isEditing ? null : _printCurrentSong;

        final navOrder = _playlistOrderForSelected();
        final navIndex = navOrder.indexWhere(
          (song) => song.path == selectedSong.path,
        );
        final showNav = navOrder.length > 1 && navIndex >= 0;
        final navControls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed:
                  _isEditing || navIndex <= 0
                      ? null
                      : () => _moveSelectedSong(-1),
              tooltip: 'Predchádzajúca pieseň',
              icon: const Icon(Icons.skip_previous),
            ),
            Text(
              showNav ? _positionLabel(navOrder, navIndex) : '',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            IconButton(
              onPressed:
                  _isEditing || navIndex >= navOrder.length - 1
                      ? null
                      : () => _moveSelectedSong(1),
              tooltip: 'Nasledujúca pieseň',
              icon: const Icon(Icons.skip_next),
            ),
          ],
        );

        final actions = <Widget>[
          if (showNav) navControls,
          transposeControls,
          if (compact)
            IconButton(
              onPressed: saveTranspositionAction,
              tooltip: 'Uložiť transpozíciu',
              icon: const Icon(Icons.save_as),
            )
          else
            TextButton.icon(
              onPressed: saveTranspositionAction,
              icon: const Icon(Icons.save_as),
              label: const Text('Uložiť transpozíciu'),
            ),
          if (compact)
            IconButton(
              onPressed: printAction,
              tooltip: 'Tlačiť',
              icon: const Icon(Icons.print),
            )
          else
            TextButton.icon(
              onPressed: printAction,
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
        ];

        final header =
            wide
                ? Row(
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    ...actions,
                    const SizedBox(width: 8),
                  ],
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleBlock,
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: actions,
                    ),
                  ],
                );

        final fontScale = compact ? 0.85 : 1.0;
        Widget buildPreviewList() => ListView.builder(
          controller: _previewScrollController,
          itemCount: displayLines.length,
          itemBuilder: (context, index) {
            final line = displayLines[index];
            return ChordLineView(
              line: line.rawLine,
              inChorus: line.isChorus,
              transposeSemitones: _transposeSemitones,
              fontScale: fontScale,
            );
          },
        );

        Widget preview;
        if (compact) {
          // Riadky sa nezalamujú (akordy sú nad textom), preto sa na úzkej
          // obrazovke dá preview posúvať aj do strán.
          final longestLine = displayLines.fold<int>(
            0,
            (longest, line) => math.max(longest, line.rawLine.length),
          );
          final estimatedWidth = longestLine * 14 * fontScale * 0.62 + 24;
          preview = LayoutBuilder(
            builder: (context, box) {
              final contentWidth = math.max(box.maxWidth, estimatedWidth);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: contentWidth, child: buildPreviewList()),
              );
            },
          );
        } else {
          preview = buildPreviewList();
        }

        return Padding(
          padding: EdgeInsets.all(compact ? 8 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
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
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.all(compact ? 8 : 12),
                          // Na mobile a tablete otvorí fullscreen dvojklik na skladbu.
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onDoubleTap:
                                MediaQuery.sizeOf(context).width < 1100
                                    ? () => _openPerformanceMode(
                                      parsedSong,
                                      displayLines,
                                    )
                                    : null,
                            child: preview,
                          ),
                        ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Pomocné modely použité len interne pri zostavovaní PDF a playlistu pre túto stránku.
class _SongSearchEntry {
  const _SongSearchEntry({
    required this.title,
    required this.subtitle,
    required this.haystack,
  });

  final String title;
  final String? subtitle;
  final String haystack;
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
