import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Tower Stack — tap to drop the swinging block; overhang gets sliced.
class TowerStackScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;

  const TowerStackScreen({super.key, required this.players, required this.callbacks});

  @override
  State<TowerStackScreen> createState() => _TowerStackScreenState();
}

class _Block {
  double x, w;
  final double hue;
  _Block(this.x, this.w, this.hue);
}

class _Falling {
  double x, w, y, vy, rot, vr;
  final double hue;
  _Falling(this.x, this.w, this.hue)
      : y = 0,
        vy = 0,
        rot = 0,
        vr = (Random().nextDouble() - 0.5) * 4;
}

class _TowerStackScreenState extends State<TowerStackScreen> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _last = Duration.zero;

  static const double _bh = 34; // block height

  bool started = false, over = false, dropping = false;
  final List<_Block> tower = [];
  final List<_Falling> falling = [];
  double curX = 0, curW = 0; // swinging block
  double swingT = 0;
  double dropY = 0; // falling animation offset for the active block
  double camY = 0;
  int combo = 0, bestCombo = 0;
  int best = 0;
  double hue = 200;
  Size view = Size.zero;
  String? popup;
  double popupT = 0;
  final rng = Random();

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => best = p.getInt('towerstack_best') ?? 0);
    });
    _ticker = createTicker(_tick)..start();
  }

  void _begin(Size s) {
    tower.clear();
    falling.clear();
    final w = s.width * 0.7;
    tower.add(_Block((s.width - w) / 2, w, 200));
    curW = w;
    curX = 0;
    swingT = 0;
    camY = 0;
    combo = 0;
    bestCombo = 0;
    hue = 200;
    popup = null;
    over = false;
    dropping = false;
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero ? 0.016 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (!mounted || over || !started) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    setState(() => _step(dt.clamp(0.0, 0.05)));
  }

  double _swingSpeed() => 1.6 + tower.length * 0.045;

  void _step(double dt) {
    swingT += dt * _swingSpeed();
    final maxX = view.width - curW;
    curX = maxX * (0.5 + 0.5 * sin(swingT * 2 - pi / 2));

    // falling cut pieces
    for (final f in falling) {
      f.vy += 1400 * dt;
      f.y += f.vy * dt;
      f.rot += f.vr * dt;
    }
    falling.removeWhere((f) => f.y > view.height * 1.6);

    if (popupT > 0) {
      popupT -= dt;
      if (popupT <= 0) {
        popup = null;
      }
    }

    // camera follows tower top
    final topY = -tower.length * _bh;
    final target = topY + view.height * 0.62;
    camY += (target - camY) * min(1, dt * 4);
  }

  void _drop() {
    if (!started || over || dropping) return;
    dropping = true;
    final prev = tower.last;
    final a0 = curX, a1 = curX + curW;
    final b0 = prev.x, b1 = prev.x + prev.w;
    final o0 = max(a0, b0), o1 = min(a1, b1);
    final overlap = o1 - o0;

    if (overlap <= 0) {
      // total miss — game over
      final f = _Falling(curX, curW, hue)..y = -tower.length * _bh;
      falling.add(f);
      Sfx.lose();
      _gameOver();
      return;
    }

    final perfect = (overlap - curW).abs() < 1 && (o0 - curX).abs() < 7 || (o0 - b0).abs() < 7 && (o1 - b1).abs() < 7;
    if (perfect) {
      // snap!
      tower.add(_Block(b0, b1 - b0, hue));
      combo++;
      bestCombo = max(bestCombo, combo);
      popup = combo >= 2 ? 'PERFECT x$combo! ⚡' : 'PERFECT! ✨';
      popupT = 1.0;
      Sfx.win();
    } else {
      // slice off the overhang
      if (a0 < o0) {
        final f = _Falling(a0, o0 - a0, hue)..y = -tower.length * _bh;
        falling.add(f);
      }
      if (a1 > o1) {
        final f = _Falling(o1, a1 - o1, hue)..y = -tower.length * _bh;
        falling.add(f);
      }
      tower.add(_Block(o0, overlap, hue));
      combo = 0;
      Sfx.tap();
    }
    hue = (hue + 14) % 360;
    curW = tower.last.w;
    dropping = false;
  }

  Future<void> _gameOver() async {
    over = true;
    final height = tower.length - 1;
    widget.players[0].score = height;
    widget.callbacks.refreshHud();
    final prefs = await SharedPreferences.getInstance();
    final isBest = height > best;
    if (isBest) {
      await prefs.setInt('towerstack_best', height);
      if (mounted) {
        setState(() => best = height);
      }
    }
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    widget.callbacks.finish(
      headline: 'Tower toppled at $height! 🗼',
      subline: isBest
          ? 'NEW BEST! 🥇  Best combo: x$bestCombo'
          : 'Best: $best blocks. Best combo: x$bestCombo',
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    return LayoutBuilder(
      builder: (_, c) {
        view = Size(c.maxWidth, c.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!started && !over) {
              setState(() {
                _begin(view);
                started = true;
              });
            } else {
              _drop();
            }
          },
          child: Stack(
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: _TowerPainter(
                  tower: tower, falling: falling, curX: curX, curW: curW,
                  camY: camY, hue: hue, popup: popup, popupT: popupT,
                  started: started, theme: t, bh: _bh,
                ),
              ),
              Positioned(
                top: 12, left: 16, right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _hud('🧱 ${tower.isEmpty ? 0 : tower.length - 1}', t),
                    if (combo >= 2) _hud('⚡ x$combo', t),
                    _hud('🏆 $best', t),
                  ],
                ),
              ),
              if (!started && !over)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
                    decoration: BoxDecoration(color: t.surface, borderRadius: t.radius),
                    child: Text('Tap to start!\nTap again to drop each block 👇',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: t.text, fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _hud(String s, GameTheme t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            color: t.surface.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(14)),
        child: Text(s, style: TextStyle(color: t.text, fontWeight: FontWeight.w800, fontSize: 15)),
      );
}

class _TowerPainter extends CustomPainter {
  final List<_Block> tower;
  final List<_Falling> falling;
  final double curX, curW, camY, hue, popupT, bh;
  final String? popup;
  final bool started;
  final GameTheme theme;

  _TowerPainter({
    required this.tower, required this.falling, required this.curX, required this.curW,
    required this.camY, required this.hue, required this.popup, required this.popupT,
    required this.started, required this.theme, required this.bh,
  });

  Color _c(double h, [double s = 0.65, double l = 0.6]) {
    final c = HSLColor.fromAHSL(1, h % 360, s, l);
    return c.toColor();
  }

  void _drawBlock(Canvas canvas, double x, double w, double topY, double h, {double rot = 0, Offset? pivot}) {
    canvas.save();
    if (rot != 0 && pivot != null) {
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(rot);
      canvas.translate(-pivot.dx, -pivot.dy);
    }
    final r = RRect.fromLTRBR(x, topY, x + w, topY + bh, const Radius.circular(8));
    canvas.drawRRect(r, Paint()..color = _c(h, 0.6, 0.58));
    canvas.drawRRect(r, Paint()..style = PaintingStyle.stroke..color = Colors.white.withValues(alpha: 0.35)..strokeWidth = 2);
    // shine
    canvas.drawRRect(
        RRect.fromLTRBR(x + 6, topY + 5, x + w - 6, topY + 13, const Radius.circular(4)),
        Paint()..color = Colors.white.withValues(alpha: 0.3));
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    // sky gradient
    final sky = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [const Color(0xFF1A2340), const Color(0xFF2E1A4D)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..shader = sky);

    // faint grid
    final gp = Paint()..color = Colors.white.withValues(alpha: 0.04);
    for (double gx = 0; gx < size.width; gx += 40) {
      canvas.drawLine(Offset(gx, 0), Offset(gx, size.height), gp);
    }

    canvas.save();
    canvas.translate(0, -camY);

    // draw tower blocks (world coords: base block top sits at 90% of view)
    for (int i = 0; i < tower.length; i++) {
      final b = tower[i];
      final topY = -(i + 1) * bh + (size.height * 0.9 - bh);
      _drawBlock(canvas, b.x, b.w, topY, b.hue);
    }

    // swinging block above tower
    if (started) {
      final topY = -(tower.length + 1) * bh + (size.height * 0.9 - bh);
      // guide line
      final glp = Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (double gx = 8; gx < size.width; gx += 20) {
        canvas.drawLine(Offset(gx, topY + bh + 8), Offset(gx + 10, topY + bh + 8), glp);
      }
      _drawBlock(canvas, curX, curW, topY, hue);
    }

    // falling cut pieces
    for (final f in falling) {
      _drawBlock(canvas, f.x, f.w, f.y, f.hue,
          rot: f.rot, pivot: Offset(f.x + f.w / 2, f.y + bh / 2));
    }

    canvas.restore();

    // popup
    if (popup != null) {
      final a = popupT.clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
            text: popup,
            style: TextStyle(
                color: Colors.white.withValues(alpha: a),
                fontSize: 30,
                fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.3));
    }
  }

  @override
  bool shouldRepaint(covariant _TowerPainter old) => true;
}
