import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:in_app_review/in_app_review.dart';
import '../engine/tower_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/craftsman.dart';
import '../theme/tower_themes.dart';

/// Tower Stack game screen: renders the engine, plays its sounds, handles
/// pause/resume and the game-over results. All rules live in [TowerEngine].
class GameScreen extends StatefulWidget {
  final TowerEngine engine;
  final TowerAudio audio;
  final TowerSettings settings;

  const GameScreen(
      {super.key,
      required this.engine,
      required this.audio,
      required this.settings});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late Ticker _ticker;
  Duration _last = Duration.zero;
  double camOffset = 0;
  double squash = 1; // landing squash animation 0..1
  TowerPhase _lastPhase = TowerPhase.ready;
  bool _recorded = false;
  bool _pausedUi = false;

  TowerEngine get _e => widget.engine;
  TowerThemeDef get _t => TowerThemes.byId(widget.settings.themeId,
      custom: widget.settings.customTheme);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _e.onEvent = _onEvent;
    _e.setThemeHues(_t.hueStart, _t.hueStep);
    _ticker = createTicker(_tick)..start();
    _e.addListener(_onEngine);
    widget.audio.startGameMusic();
  }

  void _onEngine() {
    if (!mounted) return;
    // Start the landing-squash animation when a drop lands.
    if (_lastPhase != TowerPhase.dropping &&
        _e.phase == TowerPhase.dropping &&
        _e.popup != 'MISS!') {
      squash = 0;
    }
    _lastPhase = _e.phase;
    if (_e.phase == TowerPhase.gameOver && !_recorded) {
      _recorded = true;
      _recordGame();
    }
  }

  void _onEvent(TowerEvent e) {
    final a = widget.audio;
    switch (e) {
      case TowerEvent.drop:
        a.thunk();
      case TowerEvent.slice:
        a.slice();
      case TowerEvent.perfect:
        a.perfect();
      case TowerEvent.missed:
        break; // crash lands right after
      case TowerEvent.crash:
        a.crash();
      case TowerEvent.win:
        a.win();
      case TowerEvent.lose:
        a.lose();
      case TowerEvent.tickSecond:
        if (_e.timeLeft <= 3 && _e.timeLeft > 0) a.tick();
      case TowerEvent.gameStart:
        a.gameStart();
      case TowerEvent.invalid:
        a.invalid();
    }
  }

  Future<void> _recordGame() async {
    final s = widget.settings;
    final e = _e;
    if (e.solo) {
      final score = e.isBlitz ? e.blitzScore : e.height;
      await s.recordGame(
          mode: e.mode, height: score, perfectCount: e.totalPerfects);
    } else {
      await s.recordPartyGame();
    }
    // Sensible review moment: every 4th finished game, after results show.
    if (s.gamesPlayed % 4 == 0) {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      try {
        final review = InAppReview.instance;
        if (await review.isAvailable()) {
          await review.requestReview();
        }
      } catch (_) {}
    }
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.016
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (!mounted) return;
    _e.step(dt.clamp(0.0, 0.05));
    // Camera follows the tower top (and the swinging block).
    // Painter math lives here; the engine stays camera-free.
    setState(() {
      if (squash < 1) squash = (squash + dt * 5).clamp(0.0, 1.0);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseGame();
    }
  }

  void _pauseGame() {
    if (_e.phase == TowerPhase.gameOver || _pausedUi) return;
    widget.audio.click();
    _e.setPaused(true);
    setState(() => _pausedUi = true);
  }

  void _resumeGame() {
    widget.audio.click();
    setState(() => _pausedUi = false);
    _e.setPaused(false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _e.removeListener(_onEngine);
    _e.dispose();
    super.dispose();
  }

  void _tap() {
    if (_e.phase == TowerPhase.ready) {
      _e.start();
    } else if (_e.awaitingDrop) {
      _e.drop();
    } else if (_e.phase == TowerPhase.gameOver) {
      // Tapping the results backdrop does nothing — use the buttons.
    } else {
      widget.audio.click();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: t.skyTop,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (_, c) {
            final view = Size(c.maxWidth, c.maxHeight);
            _e.setViewWidth(view.width);
            // Smooth camera toward the tower top.
            const bh = TowerEngine.blockH;
            final baseY = view.height * 0.88;
            final topWorld = baseY - (_e.height + 1) * bh;
            final target = topWorld - view.height * 0.44;
            camOffset += (target - camOffset) * 0.08;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _tap,
              child: Stack(
                children: [
                  ListenableBuilder(
                    listenable: _e,
                    builder: (_, _) => CustomPaint(
                      size: Size.infinite,
                      painter: _TowerPainter(
                        engine: _e,
                        theme: t,
                        blockStyle: widget.settings.blockStyle,
                        camOffset: camOffset,
                        squash: squash,
                        best: widget.settings.bestForMode(_e.mode),
                      ),
                    ),
                  ),
                  _hud(t),
                  if (_e.n > 1) _playerStrip(t),
                  if (_pausedUi) _pauseOverlay(t),
                  if (_e.phase == TowerPhase.gameOver) _resultsOverlay(t),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _hud(TowerThemeDef t) {
    final e = _e;
    return Positioned(
      top: 10,
      left: 12,
      right: 12,
      child: ListenableBuilder(
        listenable: e,
        builder: (_, _) => Row(
          children: [
            _chip(t, '🧱 ${e.solo ? (e.isBlitz ? e.blitzScore : e.height) : e.height}'),
            if (e.current.combo >= 2 && e.phase != TowerPhase.gameOver)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _chip(t, '⚡ x${e.current.combo}'),
              ),
            if (e.isBlitz && e.phase != TowerPhase.gameOver)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _chip(t, '⏱ ${e.timeLeft}s',
                    alert: e.timeLeft <= 10),
              ),
            const Spacer(),
            if (e.solo) _chip(t, '🏆 ${widget.settings.bestForMode(e.mode)}'),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _pauseGame,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.beamDeep.withValues(alpha: 0.75),
                  border: Border.all(color: t.accent, width: 2),
                ),
                child: Icon(Icons.pause, color: t.accentLight, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(TowerThemeDef t, String s, {bool alert = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: t.beamDeep.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: alert ? const Color(0xFFE08A8A) : t.accent.withValues(alpha: 0.5)),
        ),
        child: Text(s,
            style: Craft.label(15,
                theme: t, color: alert ? const Color(0xFFFFB3B3) : t.ivory)),
      );

  /// Pass-and-play / versus: every seat visible, current highlighted.
  Widget _playerStrip(TowerThemeDef t) {
    final e = _e;
    return Positioned(
      top: 62,
      left: 0,
      right: 0,
      child: ListenableBuilder(
        listenable: e,
        builder: (_, _) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (int i = 0; i < e.n; i++)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: i == e.turn && e.phase != TowerPhase.gameOver
                        ? t.accent.withValues(alpha: 0.9)
                        : t.beamDeep.withValues(alpha: 0.7),
                    border: Border.all(
                        color: t.accentLight,
                        width: i == e.turn ? 2.5 : 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!e.players[i].alive)
                        const Text('💀 ', style: TextStyle(fontSize: 13)),
                      if (e.players[i].isBot)
                        const Text('🤖 ', style: TextStyle(fontSize: 13)),
                      Text(
                        '${e.players[i].name} · ${e.players[i].height}',
                        style: Craft.label(12,
                            theme: t,
                            color: i == e.turn &&
                                    e.phase != TowerPhase.gameOver
                                ? t.beamDeep
                                : e.players[i].alive
                                    ? t.ivory
                                    : t.ivory.withValues(alpha: 0.45)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pauseOverlay(TowerThemeDef t) => Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                  colors: [t.beamMid, t.beamDeep],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter),
              border: Border.all(color: t.accent, width: 3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Paused', style: Craft.display(30, theme: t)),
                const SizedBox(height: 18),
                TimberButton(
                    label: '▶  Resume', theme: t, onTap: _resumeGame),
                const SizedBox(height: 10),
                TimberButton(
                  label: '↻  Restart',
                  theme: t,
                  onTap: () {
                    widget.audio.click();
                    setState(() {
                      _pausedUi = false;
                      _recorded = false;
                    });
                    _e.setPaused(false);
                    _e.restart();
                  },
                ),
                const SizedBox(height: 10),
                TimberButton(
                  label: '🏠  Menu',
                  theme: t,
                  onTap: () {
                    widget.audio.click();
                    _e.setPaused(false);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      );

  Widget _resultsOverlay(TowerThemeDef t) {
    final e = _e;
    final s = widget.settings;
    final isBest = e.solo &&
        (e.isBlitz ? e.blitzScore : e.height) >= s.bestForMode(e.mode) &&
        (e.isBlitz ? e.blitzScore : e.height) > 0;
    String headline;
    if (e.solo) {
      headline = e.isBlitz
          ? '⏱ Time! ${e.blitzScore} blocks!'
          : '🗼 Tower toppled at ${e.height}!';
    } else if (e.winnerIndex != null) {
      headline = '🏆 ${e.players[e.winnerIndex!].name} wins!';
    } else {
      headline = '💥 Everyone toppled!';
    }
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                  colors: [t.beamMid, t.beamDeep],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter),
              border: Border.all(color: t.accent, width: 3),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    offset: const Offset(0, 8),
                    blurRadius: 16),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(headline,
                    style: Craft.display(24, theme: t),
                    textAlign: TextAlign.center),
                if (isBest) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: t.accent.withValues(alpha: 0.3),
                      border: Border.all(color: t.accentLight),
                    ),
                    child: Text('🥇 NEW BEST!',
                        style: Craft.label(15, theme: t)),
                  ),
                ],
                const SizedBox(height: 14),
                if (e.solo) ...[
                  _statRow(t, 'Blocks stacked',
                      '${e.isBlitz ? e.blitzScore : e.height}'),
                  _statRow(t, 'Perfect drops', '${e.totalPerfects}'),
                  _statRow(t, 'Best combo', 'x${_bestCombo()}'),
                  _statRow(t, 'All-time best',
                      '${s.bestForMode(e.mode)}'),
                ] else ...[
                  for (int i = 0; i < e.n; i++)
                    _statRow(
                        t,
                        '${e.players[i].isBot ? '🤖 ' : ''}${e.players[i].name}',
                        '${e.players[i].height} blocks'),
                ],
                const SizedBox(height: 18),
                TimberButton(
                  label: '↻  Play Again',
                  theme: t,
                  onTap: () {
                    widget.audio.click();
                    setState(() => _recorded = false);
                    _e.restart();
                    _e.start();
                  },
                ),
                const SizedBox(height: 10),
                TimberButton(
                  label: '🏠  Menu',
                  theme: t,
                  onTap: () {
                    widget.audio.click();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _bestCombo() {
    // The engine tracks per-player combos; the run best is approximated
    // from the current player's final combo and the popup history.
    var m = 0;
    for (final p in _e.players) {
      m = max(m, p.combo);
    }
    return m;
  }

  Widget _statRow(TowerThemeDef t, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: Craft.body(14, theme: t)),
            Text(v, style: Craft.label(14, theme: t)),
          ],
        ),
      );
}

// ===========================================================================
/// Paints the whole yard: sky, clouds, ground, the tower (with 10 physical
/// block styles), the swinging crane block, tumbling cut pieces, popups.
class _TowerPainter extends CustomPainter {
  final TowerEngine e;
  final TowerThemeDef theme;
  final int blockStyle;
  final double camOffset;
  final double squash; // 0..1 landing squash
  final int best;

  _TowerPainter({
    required this.e,
    required this.theme,
    required this.blockStyle,
    required this.camOffset,
    required this.squash,
    required this.best,
  });

  static const double bh = TowerEngine.blockH;

  Color _blockBase(double hue) {
    switch (blockStyle) {
      case 0: // timber
        return HSLColor.fromAHSL(1, hue % 360, 0.52, 0.55).toColor();
      case 1: // brick
        return HSLColor.fromAHSL(1, hue % 360, 0.58, 0.5).toColor();
      case 2: // stone
        return HSLColor.fromAHSL(1, hue % 360, 0.14, 0.56).toColor();
      case 3: // marble
        return HSLColor.fromAHSL(1, hue % 360, 0.3, 0.78).toColor();
      case 4: // steel
        return HSLColor.fromAHSL(1, hue % 360, 0.1, 0.46).toColor();
      case 5: // bamboo
        return HSLColor.fromAHSL(1, hue % 360, 0.58, 0.5).toColor();
      case 6: // candy
        return HSLColor.fromAHSL(1, hue % 360, 0.8, 0.66).toColor();
      case 7: // obsidian
        return HSLColor.fromAHSL(1, hue % 360, 0.25, 0.16).toColor();
      case 8: // mossy stone
        return HSLColor.fromAHSL(1, hue % 360, 0.32, 0.44).toColor();
      default: // golden beam
        return HSLColor.fromAHSL(1, hue % 360, 0.85, 0.55).toColor();
    }
  }

  void _drawBlock(Canvas canvas, double x, double w, double topY, double hue,
      {double rot = 0, Offset? pivot, double squashY = 1}) {
    if (w <= 0) return;
    canvas.save();
    if (rot != 0 && pivot != null) {
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(rot);
      canvas.translate(-pivot.dx, -pivot.dy);
    }
    // Squash around the block's bottom edge (landing impact).
    final hgt = bh * squashY;
    final y0 = topY + bh - hgt;
    final base = _blockBase(hue);
    final r = RRect.fromLTRBR(x, y0, x + w, y0 + hgt, const Radius.circular(7));
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRRect(r, Paint()..color = base);
    _texture(canvas, Rect.fromLTRBR(x, y0, x + w, y0 + hgt), hue, base);
    // Top bevel (light) + bottom shadow: pseudo-3D weight.
    canvas.drawRect(
        Rect.fromLTRBR(x, y0, x + w, y0 + 6),
        Paint()..color = Colors.white.withValues(alpha: 0.28));
    canvas.drawRect(
        Rect.fromLTRBR(x, y0 + hgt - 7, x + w, y0 + hgt),
        Paint()..color = Colors.black.withValues(alpha: 0.25));
    // Left/right edge shading.
    canvas.drawRect(Rect.fromLTRBR(x, y0, x + 4, y0 + hgt),
        Paint()..color = Colors.black.withValues(alpha: 0.12));
    canvas.drawRect(Rect.fromLTRBR(x + w - 4, y0, x + w, y0 + hgt),
        Paint()..color = Colors.black.withValues(alpha: 0.12));
    canvas.restore();
    canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.black.withValues(alpha: 0.35)
          ..strokeWidth = 2);
    canvas.restore();
  }

  /// Physical material texture per block style, drawn inside the clipped rect.
  void _texture(Canvas canvas, Rect r, double hue, Color base) {
    final dark = HSLColor.fromColor(base)
        .withLightness((HSLColor.fromColor(base).lightness - 0.16).clamp(0.0, 1.0))
        .toColor();
    final light = HSLColor.fromColor(base)
        .withLightness((HSLColor.fromColor(base).lightness + 0.18).clamp(0.0, 1.0))
        .toColor();
    switch (blockStyle) {
      case 0: // timber grain
        final p = Paint()
          ..color = dark.withValues(alpha: 0.5)
          ..strokeWidth = 1.6;
        for (int i = 1; i < 4; i++) {
          final y = r.top + r.height * i / 4;
          canvas.drawLine(Offset(r.left + 4, y),
              Offset(r.right - 4, y + (i % 2) * 3 - 1.5), p);
        }
      case 1: // brick courses
        final p = Paint()
          ..color = light.withValues(alpha: 0.55)
          ..strokeWidth = 2;
        final midY = r.top + r.height / 2;
        canvas.drawLine(Offset(r.left, midY), Offset(r.right, midY), p);
        for (double bx = r.left + r.width / 4; bx < r.right; bx += r.width / 4) {
          canvas.drawLine(Offset(bx, r.top), Offset(bx, midY), p);
        }
        for (double bx = r.left + r.width / 8;
            bx < r.right;
            bx += r.width / 4) {
          canvas.drawLine(Offset(bx, midY), Offset(bx, r.bottom), p);
        }
      case 2: // stone speckle
        final rnd = Random(hue.round());
        final p = Paint()..color = dark.withValues(alpha: 0.6);
        for (int i = 0; i < 8; i++) {
          canvas.drawCircle(
              Offset(r.left + rnd.nextDouble() * r.width,
                  r.top + rnd.nextDouble() * r.height),
              1.6,
              p);
        }
      case 3: // marble veins
        final rnd = Random((hue * 7).round());
        final p = Paint()
          ..color = Colors.white.withValues(alpha: 0.65)
          ..strokeWidth = 1.4;
        for (int i = 0; i < 3; i++) {
          final y0 = r.top + rnd.nextDouble() * r.height;
          final path = Path()..moveTo(r.left, y0);
          for (double x = r.left; x <= r.right; x += 14) {
            path.lineTo(x, y0 + sin(x / 12 + i) * 4);
          }
          canvas.drawPath(path, p);
        }
      case 4: // steel rivets
        final p = Paint()..color = light.withValues(alpha: 0.8);
        for (double bx = r.left + 12; bx < r.right - 6; bx += 26) {
          canvas.drawCircle(Offset(bx, r.top + r.height / 2), 2.6, p);
        }
      case 5: // bamboo segments
        final p = Paint()
          ..color = dark.withValues(alpha: 0.55)
          ..strokeWidth = 2.4;
        for (double bx = r.left + r.width / 3; bx < r.right; bx += r.width / 3) {
          canvas.drawLine(Offset(bx, r.top + 2), Offset(bx, r.bottom - 2), p);
        }
      case 6: // candy swirl stripes
        final p = Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..strokeWidth = 5;
        for (double bx = r.left - r.height;
            bx < r.right;
            bx += 26) {
          canvas.drawLine(Offset(bx, r.bottom), Offset(bx + r.height, r.top), p);
        }
      case 7: // obsidian sheen
        final p = Paint()
          ..color = Colors.white.withValues(alpha: 0.22)
          ..strokeWidth = 3;
        canvas.drawLine(Offset(r.left + 8, r.bottom - 4),
            Offset(r.left + r.width * 0.4, r.top + 4), p);
      case 8: // moss patches
        final rnd = Random((hue * 13).round());
        final p = Paint()..color = const Color(0xFF5C8A3C).withValues(alpha: 0.85);
        for (int i = 0; i < 5; i++) {
          canvas.drawCircle(
              Offset(r.left + rnd.nextDouble() * r.width,
                  r.top + 4 + rnd.nextDouble() * 8),
              3.4,
              p);
        }
      default: // golden shine
        final p = Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..strokeWidth = 4;
        canvas.drawLine(Offset(r.left + r.width * 0.25, r.top + 3),
            Offset(r.left + r.width * 0.45, r.bottom - 3), p);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = theme;
    // Sky.
    final sky = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [t.skyTop, t.skyBottom],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..shader = sky);

    // Sun / moon disc.
    canvas.drawCircle(
        Offset(size.width * 0.82, size.height * 0.12 - camOffset * 0.15),
        34,
        Paint()..color = t.accentLight.withValues(alpha: 0.85));
    canvas.drawCircle(
        Offset(size.width * 0.82, size.height * 0.12 - camOffset * 0.15),
        44,
        Paint()..color = t.accentLight.withValues(alpha: 0.18));

    // Drifting clouds (parallax with camera).
    final cloudP = Paint()..color = Colors.white.withValues(alpha: 0.5);
    final rnd = Random(7);
    for (int i = 0; i < 6; i++) {
      final cx = rnd.nextDouble() * size.width;
      final cy = rnd.nextDouble() * size.height * 0.7 -
          (camOffset * (0.1 + i * 0.03)) % (size.height * 1.4);
      final cw = 50 + rnd.nextDouble() * 60;
      canvas.drawRRect(
          RRect.fromLTRBR(cx, cy, cx + cw, cy + 16, const Radius.circular(8)),
          cloudP);
      canvas.drawCircle(Offset(cx + cw * 0.3, cy + 6), 14, cloudP);
      canvas.drawCircle(Offset(cx + cw * 0.65, cy + 4), 18, cloudP);
    }

    // Ground platform.
    final groundTop = size.height * 0.88 - camOffset;
    canvas.drawRect(
        Rect.fromLTWH(0, groundTop, size.width, size.height),
        Paint()..color = t.ground);
    canvas.drawRect(
        Rect.fromLTWH(0, groundTop, size.width, 10),
        Paint()..color = t.groundDark);
    // Scaffold poles at the edges.
    final poleP = Paint()..color = t.beamDeep.withValues(alpha: 0.85);
    canvas.drawRect(Rect.fromLTWH(10, groundTop - 130, 12, 130), poleP);
    canvas.drawRect(
        Rect.fromLTWH(size.width - 22, groundTop - 130, 12, 130), poleP);

    double worldY(int blockIndex) =>
        size.height * 0.88 - (blockIndex + 1) * bh - camOffset;

    final tower = e.tower;
    // Stacked blocks.
    for (int i = 0; i < tower.length; i++) {
      final b = tower[i];
      final isTop = i == tower.length - 1;
      final sy = isTop && e.phase == TowerPhase.dropping
          ? 1 - 0.16 * sin(pi * squash.clamp(0.0, 1.0))
          : 1;
      _drawBlock(canvas, b.x * size.width, b.w * size.width, worldY(i), b.hue,
          squashY: sy);
    }

    // Landing guide: dashed line where the block will rest.
    if (e.phase == TowerPhase.swinging || e.phase == TowerPhase.ready) {
      final gy = worldY(tower.length) + bh;
      final gp = Paint()
        ..color = t.ivory.withValues(alpha: 0.35)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      for (double gx = 6; gx < size.width - 10; gx += 22) {
        canvas.drawLine(Offset(gx, gy), Offset(gx + 11, gy), gp);
      }
    }

    // Swinging crane block + cable + hook.
    if (e.phase == TowerPhase.swinging) {
      final bx = e.swingX * size.width;
      final bw = e.swingW * size.width;
      final topY = worldY(tower.length);
      final cx = bx + bw / 2;
      // Cable.
      canvas.drawLine(
          Offset(cx, 0),
          Offset(cx, topY - 14),
          Paint()
            ..color = t.beamDeep.withValues(alpha: 0.9)
            ..strokeWidth = 4);
      // Hook.
      canvas.drawCircle(Offset(cx, topY - 8), 7,
          Paint()..color = t.accentDark);
      canvas.drawCircle(Offset(cx, topY - 8), 7,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = t.accentLight
            ..strokeWidth = 2);
      _drawBlock(canvas, bx, bw, topY, e.swingHue);
      // Bot aim marker: the crane's target, visible while aiming.
      if (e.botAiming) {
        final pulse = 0.55 + 0.35 * sin(DateTime.now().millisecond / 130);
        canvas.drawRRect(
            RRect.fromLTRBR(e.botTargetX * size.width, topY,
                (e.botTargetX + e.swingW) * size.width, topY + bh,
                const Radius.circular(7)),
            Paint()
              ..style = PaintingStyle.stroke
              ..color = t.accentLight.withValues(alpha: pulse)
              ..strokeWidth = 3);
      }
    }

    // Tumbling cut pieces.
    for (final f in e.tumbles) {
      final fy = size.height * 0.88 + f.y * bh - camOffset;
      _drawBlock(canvas, f.x * size.width, f.w * size.width, fy, f.hue,
          rot: f.rot, pivot: Offset((f.x + f.w / 2) * size.width, fy + bh / 2));
    }

    // Popup (PERFECT! / MISS!).
    if (e.popup.isNotEmpty) {
      final a = e.popupT.clamp(0.0, 1.0);
      final scale = 1 + 0.25 * (1 - a);
      canvas.save();
      canvas.translate(size.width / 2, size.height * 0.32);
      canvas.scale(scale);
      final tp = TextPainter(
        text: TextSpan(
            text: e.popup,
            style: TextStyle(
                color: Colors.white.withValues(alpha: a),
                fontSize: 32,
                fontWeight: FontWeight.w900,
                shadows: const [
                  Shadow(color: Colors.black54, offset: Offset(0, 3), blurRadius: 6)
                ])),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // Ready hint.
    if (e.phase == TowerPhase.ready) {
      final tp = TextPainter(
        text: TextSpan(
            text: 'Tap to start!\nTap again to drop each block 👇',
            style: TextStyle(
                color: t.ivory, fontSize: 18, fontWeight: FontWeight.w700,
                shadows: const [
                  Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4)
                ])),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: size.width * 0.8);
      tp.paint(
          canvas,
          Offset((size.width - tp.width) / 2,
              size.height * 0.5 - camOffset * 0.2));
    }

    // Turn banner (bottom).
    if (e.banner.isNotEmpty && e.phase != TowerPhase.gameOver) {
      final tp = TextPainter(
        text: TextSpan(
            text: e.banner,
            style: TextStyle(
                color: t.ivory.withValues(alpha: 0.95),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                shadows: const [
                  Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4)
                ])),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: size.width * 0.9);
      tp.paint(canvas,
          Offset((size.width - tp.width) / 2, size.height - tp.height - 26));
    }
  }

  @override
  bool shouldRepaint(covariant _TowerPainter old) => true;
}
