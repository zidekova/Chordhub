// Celoobrazovkové zobrazenie piesne pri hraní: automatické scrollovanie, transpozícia, rýchlosť.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/song.dart';
import '../widgets/chord_line_view.dart';

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
