// Celoobrazovkové zobrazenie piesne pri hraní: automatické scrollovanie, transpozícia, rýchlosť.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';
import '../widgets/chord_line_view.dart';

/// Dáta skladby, na ktorú sa prepne šípkami vo fullscreene.
class PerformanceSong {
  const PerformanceSong({
    required this.title,
    required this.subtitle,
    required this.displayLines,
    required this.scrollSpeed,
    this.positionLabel,
  });

  final String title;
  final String? subtitle;
  final List<SongDisplayLine> displayLines;
  final double scrollSpeed;
  final String? positionLabel; // napr. "Kolo 2 · 3 / 12"
}

class SongPerformancePage extends StatefulWidget {
  const SongPerformancePage({
    required this.title,
    required this.subtitle,
    required this.displayLines,
    required this.initialTransposeSemitones,
    required this.initialScrollSpeedPixelsPerSecond,
    this.onSaveScrollSpeed,
    this.positionLabel,
    this.canChangeSong,
    this.onChangeSong,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<SongDisplayLine> displayLines;
  final int initialTransposeSemitones;
  final double initialScrollSpeedPixelsPerSecond;

  /// Uloží aktuálnu rýchlosť scrollovania do piesne. Pri chybe má vyhodiť výnimku.
  final Future<void> Function(double speedPixelsPerSecond)? onSaveScrollSpeed;

  /// Poloha v playliste na zobrazenie v dolnom paneli (napr. "Kolo 2 · 3 / 12").
  final String? positionLabel;

  /// Či existuje predchádzajúca (-1) / nasledujúca (+1) skladba.
  final bool Function(int delta)? canChangeSong;

  /// Prepne na predchádzajúcu/nasledujúcu skladbu a vráti jej dáta.
  final PerformanceSong? Function(int delta)? onChangeSong;

  @override
  State<SongPerformancePage> createState() => _SongPerformancePageState();
}

class _SongPerformancePageState extends State<SongPerformancePage> {
  late int _transposeSemitones = widget.initialTransposeSemitones;
  late String _title = widget.title;
  late String? _subtitle = widget.subtitle;
  late List<SongDisplayLine> _lines = widget.displayLines;
  late String? _positionLabel = widget.positionLabel;
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  late double _scrollSpeedPixelsPerSecond;
  bool _isAutoScrolling = true;
  bool _userTouching = false; // prst na displeji: automatický posun sa pozastaví
  Timer? _feedbackTimer;
  bool _feedbackVisible = false;
  IconData _feedbackIcon = Icons.pause;

  // Vlastné priblíženie textu (štiepenie prstami alebo tlačidlá). Násobí sa
  // s automatickou veľkosťou a pamätá si sa aj pre ďalšie skladby.
  static const String _prefZoom = 'performance_font_zoom';
  static const double _minZoom = 0.6;
  static const double _maxZoom = 3.5;
  double _zoom = 1.0;
  final Map<int, Offset> _pointers = {};
  double _pinchStartDistance = 0;
  double _pinchStartZoom = 1.0;
  bool _pinching = false;
  DateTime? _lastPinchAt;

  // Automatická veľkosť sa prepočíta len pri zmene rozmerov alebo transpozície.
  String? _autoKey;
  double _autoScale = 1.0;
  double _maxLineWidthAt1 = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scrollSpeedPixelsPerSecond = widget.initialScrollSpeedPixelsPerSecond;
    _loadZoom();
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
    _feedbackTimer?.cancel();
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

  Future<void> _saveScrollSpeed() async {
    final save = widget.onSaveScrollSpeed;
    if (save == null) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await save(_scrollSpeedPixelsPerSecond);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Rýchlosť ${_scrollSpeedPixelsPerSecond.round()} px/s bola uložená do piesne.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Nepodarilo sa uložiť rýchlosť: $error')),
      );
    }
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

  Future<void> _loadZoom() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getDouble(_prefZoom);
      if (stored != null && mounted) {
        setState(() {
          _zoom = stored.clamp(_minZoom, _maxZoom).toDouble();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveZoom() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefZoom, _zoom);
    } catch (_) {}
  }

  /// Nastaví priblíženie a udrží zhruba rovnaké miesto v skladbe.
  void _applyZoom(double newZoom) {
    final clamped = newZoom.clamp(_minZoom, _maxZoom).toDouble();
    final oldZoom = _zoom;
    if (clamped == oldZoom) return;
    setState(() {
      _zoom = clamped;
    });
    final ratio = clamped / oldZoom;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      position.jumpTo(
        (position.pixels * ratio).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    });
  }

  void _zoomBy(double factor) {
    _applyZoom(_zoom * factor);
    _saveZoom();
  }

  void _resetZoom() {
    _applyZoom(1.0);
    _saveZoom();
  }

  double _pinchDistance() {
    final points = _pointers.values.toList();
    return (points[0] - points[1]).distance;
  }

  void _onPointerDown(PointerDownEvent event) {
    _userTouching = true;
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2) {
      _pinchStartDistance = _pinchDistance();
      _pinchStartZoom = _zoom;
      setState(() {
        _pinching = true;
      });
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2 && _pinchStartDistance > 0) {
      _applyZoom(_pinchStartZoom * (_pinchDistance() / _pinchStartDistance));
    }
  }

  void _onPointerEnd(PointerEvent event) {
    final wasPinching = _pointers.length >= 2;
    _pointers.remove(event.pointer);
    if (wasPinching) {
      _lastPinchAt = DateTime.now();
      _saveZoom();
      if (_pinching) {
        setState(() {
          _pinching = false;
        });
      }
    }
    if (_pointers.isEmpty) {
      _userTouching = false;
    }
  }

  /// Prepne na predchádzajúcu (-1) alebo nasledujúcu (+1) skladbu playlistu.
  void _changeSong(int delta) {
    final handler = widget.onChangeSong;
    if (handler == null) return;
    final next = handler(delta);
    if (next == null) return;

    setState(() {
      _title = next.title;
      _subtitle = next.subtitle;
      _lines = next.displayLines;
      _positionLabel = next.positionLabel;
      _scrollSpeedPixelsPerSecond = next.scrollSpeed;
      _transposeSemitones = 0;
      _isAutoScrolling = true;
      _autoKey = null; // prepočítaj automatickú veľkosť písma
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _startAutoScroll();
  }

  /// Jedno klepnutie na skladbu pozastaví alebo znovu spustí scrollovanie.
  void _onBodyTap() {
    // Po štiepení prstami nespúšťaj pauzu.
    final lastPinch = _lastPinchAt;
    if (lastPinch != null &&
        DateTime.now().difference(lastPinch) <
            const Duration(milliseconds: 400)) {
      return;
    }
    _toggleAutoScroll();
    setState(() {
      _feedbackIcon = _isAutoScrolling ? Icons.play_arrow : Icons.pause;
      _feedbackVisible = true;
    });
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _feedbackVisible = false;
        });
      }
    });
  }

  /// Na úzkej obrazovke sú ovládacie prvky v spodnom paneli, aby sa neprekrývali.
  void _showControlsSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder: (context, setSheetState) {
              void update(VoidCallback change) {
                change();
                setSheetState(() {});
              }

              final textTheme = Theme.of(context).textTheme;
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Transpozícia', style: textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          IconButton.filledTonal(
                            onPressed: () => update(() => _changeTransposeBy(-1)),
                            tooltip: 'Transpozícia -1',
                            icon: const Icon(Icons.remove),
                          ),
                          SizedBox(
                            width: 56,
                            child: Center(
                              child: Text(
                                '$_transposeSemitones',
                                style: textTheme.titleLarge,
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: () => update(() => _changeTransposeBy(1)),
                            tooltip: 'Transpozícia +1',
                            icon: const Icon(Icons.add),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed:
                                () => update(() {
                                  setState(() {
                                    _transposeSemitones = 0;
                                  });
                                }),
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Veľkosť textu (aj štiepením prstami)',
                        style: textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          IconButton.filledTonal(
                            onPressed: () => update(() => _zoomBy(1 / 1.15)),
                            tooltip: 'Zmenšiť text',
                            icon: const Icon(Icons.text_decrease),
                          ),
                          SizedBox(
                            width: 72,
                            child: Center(
                              child: Text(
                                '${(_zoom * 100).round()} %',
                                style: textTheme.titleMedium,
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: () => update(() => _zoomBy(1.15)),
                            tooltip: 'Zväčšiť text',
                            icon: const Icon(Icons.text_increase),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => update(_resetZoom),
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Rýchlosť scrollovania', style: textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          IconButton.filledTonal(
                            onPressed:
                                () => update(() => _changeScrollSpeedBy(-4)),
                            tooltip: 'Spomaliť scrollovanie',
                            icon: const Icon(Icons.remove),
                          ),
                          SizedBox(
                            width: 88,
                            child: Center(
                              child: Text(
                                '${_scrollSpeedPixelsPerSecond.round()} px/s',
                                style: textTheme.titleMedium,
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed:
                                () => update(() => _changeScrollSpeedBy(4)),
                            tooltip: 'Zrýchliť scrollovanie',
                            icon: const Icon(Icons.add),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed:
                                widget.onSaveScrollSpeed == null
                                    ? null
                                    : () {
                                      Navigator.of(sheetContext).pop();
                                      _saveScrollSpeed();
                                    },
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Uložiť'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted ||
          !_isAutoScrolling ||
          _userTouching ||
          !_scrollController.hasClients) {
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
    final key =
        '${constraints.maxWidth.round()}x${constraints.maxHeight.round()}'
        '|$_transposeSemitones';
    if (key != _autoKey) {
      _autoScale = _computeAutoScale(constraints, lines);
      _autoKey = key;
    }
    return _autoScale;
  }

  double _computeAutoScale(
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

    _maxLineWidthAt1 = maxLineWidth;
    if (maxLineWidth <= 1) {
      return 1.0;
    }

    final reservedWidth = constraints.maxWidth < 700 ? 28.0 : 44.0;
    final widthByContent =
        (constraints.maxWidth - reservedWidth) / (maxLineWidth + 12);
    final heightBoost = (constraints.maxHeight / 900).clamp(1.0, 1.35);
    final scale = widthByContent * 0.95 * heightBoost;
    return scale.clamp(0.55, 2.8);
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
    final width = MediaQuery.sizeOf(context).width;
    final isPhone = width < 700;
    final useCompactActions = width < 1000;

    final playPauseButton = IconButton(
      onPressed: _toggleAutoScroll,
      tooltip: _isAutoScrolling ? 'Zastaviť scrollovanie' : 'Spustiť scrollovanie',
      icon: Icon(_isAutoScrolling ? Icons.pause_circle : Icons.play_circle),
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: isPhone ? 0 : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (_subtitle != null)
              Text(
                _subtitle!,
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
        actions:
            isPhone
                ? [
                  playPauseButton,
                  IconButton(
                    onPressed: _showControlsSheet,
                    tooltip: 'Transpozícia a rýchlosť',
                    icon: const Icon(Icons.tune),
                  ),
                ]
                : [
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
                  Center(
                    child: Text('${_scrollSpeedPixelsPerSecond.round()} px/s'),
                  ),
                  IconButton(
                    onPressed: () => _changeScrollSpeedBy(4),
                    tooltip: 'Zrýchliť scrollovanie',
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  IconButton(
                    onPressed:
                        widget.onSaveScrollSpeed == null
                            ? null
                            : _saveScrollSpeed,
                    tooltip: 'Uložiť rýchlosť scrollovania do piesne',
                    icon: const Icon(Icons.save_outlined),
                  ),
                  if (width >= 900) ...[
                    IconButton(
                      onPressed: () => _zoomBy(1 / 1.15),
                      tooltip: 'Zmenšiť text',
                      icon: const Icon(Icons.text_decrease),
                    ),
                    IconButton(
                      onPressed: () => _zoomBy(1.15),
                      tooltip: 'Zväčšiť text',
                      icon: const Icon(Icons.text_increase),
                    ),
                  ],
                  playPauseButton,
                  if (useCompactActions)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _transposeSemitones = 0;
                        });
                      },
                      tooltip: 'Reset transpozície',
                      icon: const Icon(Icons.restart_alt),
                    )
                  else
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _transposeSemitones = 0;
                        });
                      },
                      child: const Text('Reset'),
                    ),
                  const SizedBox(width: 4),
                ],
      ),
      bottomNavigationBar:
          widget.onChangeSong == null
              ? null
              : BottomAppBar(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed:
                          (widget.canChangeSong?.call(-1) ?? false)
                              ? () => _changeSong(-1)
                              : null,
                      tooltip: 'Predchádzajúca pieseň',
                      icon: const Icon(Icons.skip_previous),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          _positionLabel ?? '',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed:
                          (widget.canChangeSong?.call(1) ?? false)
                              ? () => _changeSong(1)
                              : null,
                      tooltip: 'Nasledujúca pieseň',
                      icon: const Icon(Icons.skip_next),
                    ),
                  ],
                ),
              ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final autoScale = _fontScaleForSingleColumn(
            constraints,
            _lines,
          );
          final fontScale = (autoScale * _zoom).clamp(0.3, 6.0).toDouble();
          final sidePadding = constraints.maxWidth < 700 ? 8.0 : 16.0;

          // Po priblížení môže byť najdlhší riadok širší než displej:
          // vtedy sa skladba dá posúvať aj do strán.
          final contentWidth =
              (_maxLineWidthAt1 + 12) * fontScale + 2 * sidePadding + 8;
          Widget songList = ListView.builder(
            controller: _scrollController,
            physics: _pinching ? const NeverScrollableScrollPhysics() : null,
            padding: EdgeInsets.fromLTRB(sidePadding, 16, sidePadding, 32),
            itemCount: _lines.length,
            itemBuilder: (context, index) {
              final line = _lines[index];
              return ChordLineView(
                line: line.rawLine,
                inChorus: line.isChorus,
                transposeSemitones: _transposeSemitones,
                fontScale: fontScale,
              );
            },
          );
          if (contentWidth > constraints.maxWidth + 1) {
            songList = SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: _pinching ? const NeverScrollableScrollPhysics() : null,
              child: SizedBox(width: contentWidth, child: songList),
            );
          }

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
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Prst na displeji pozastaví automatický posun, aby sa
                // nebil s ručným posúvaním. Jedno klepnutie ho zastaví/spustí.
                Listener(
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerEnd,
                  onPointerCancel: _onPointerEnd,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onBodyTap,
                    child: songList,
                  ),
                ),
                Center(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _feedbackVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _feedbackIcon,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
