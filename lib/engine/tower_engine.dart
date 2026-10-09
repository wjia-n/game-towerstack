import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// One physical block. Positions are FRACTIONS of the view width (0..1), so
/// the math is deterministic and resolution-independent.
class TowerBlock {
  double x; // left edge, fraction of view width
  double w; // width, fraction of view width
  final double hue;
  TowerBlock(this.x, this.w, this.hue);
}

/// A sliced-off piece tumbling away (visual only).
class Tumble {
  double x, w; // fractions
  double y; // world y in block-height units (negative = above base)
  double vy, rot, vr;
  final double hue;
  Tumble(this.x, this.w, this.y, this.hue, Random rand)
      : vy = 0,
        rot = 0,
        vr = (rand.nextDouble() - 0.5) * 4;
}

/// Player seat: human or bot.
class TowerPlayer {
  String name;
  final bool isBot;
  bool alive = true;
  int height = 0; // blocks stacked this run
  int perfects = 0;
  int combo = 0;

  TowerPlayer({required this.name, required this.isBot});
}

/// Engine-owned phases. The UI only renders — it never drives state.
enum TowerPhase { ready, swinging, dropping, crashing, gameOver }

/// Deterministic result of a drop (testable, UI-agnostic).
enum DropKind { perfect, placed, missed }

class DropResult {
  final DropKind kind;
  final int combo;
  final List<Tumble> tumbles;
  final TowerBlock? placed;
  DropResult(this.kind, this.combo, this.tumbles, this.placed);
}

/// UI hook for sounds / haptics. Set by the screen.
enum TowerEvent {
  drop, // block landed (thunk)
  slice, // overhang sliced off
  perfect, // perfect placement
  missed, // total miss
  crash, // tower topples / game over
  win, // player won (party/versus)
  lose, // solo game over
  tickSecond, // score-attack countdown tick
  gameStart,
  invalid,
}

/// Tower Stack engine: deterministic rules, state, bot AI. UI-agnostic.
///
/// Modes (index): 0 classic (solo), 1 blitz 60s (solo), 2 zen (solo, no
/// shrink), 3 party pass-and-play (own towers, elimination), 4 versus bot.
///
/// The engine owns ALL phase transitions on its own single phase timer, plus
/// a watchdog that recovers any phase found without a live timer. Stuck
/// states are impossible by construction.
class TowerEngine extends ChangeNotifier {
  final List<TowerPlayer> players;
  final int mode; // 0 classic, 1 blitz, 2 zen, 3 party, 4 versus
  final int difficulty; // 0 chill, 1 classic, 2 turbo, 3 master
  final int botSkill; // 0 easy, 1 medium, 2 hard (versus mode)

  TowerPhase phase = TowerPhase.ready;
  int turn = 0;

  // Per-player tower state (each player builds their own tower).
  final List<List<TowerBlock>> _towers = [];
  double swingX = 0; // fraction
  double swingW = 0; // fraction
  double swingHue = 0;
  double swingT = 0;
  bool botAiming = false;
  double botTargetX = 0; // fraction, shown as aim marker

  final List<Tumble> tumbles = [];
  String banner = '';
  String popup = '';
  double popupT = 0;
  int totalPerfects = 0;
  int? winnerIndex;

  // Score attack.
  int timeLeft = 0; // seconds
  int blitzScore = 0;

  double viewWidth = 400; // set by the screen every build

  final _rand = Random();
  Timer? _timer; // single phase-transition timer
  Timer? _attackTimer; // 1s countdown ticks (blitz)
  Timer? _watchdog; // stuck-state recovery
  bool _disposed = false;
  bool paused = false;

  static const double blockH = 34; // logical block height px (renderer)
  static const double baseWidth = 0.72; // fraction of view width
  static const int blitzSeconds = 60;
  static const double dropAnimMs = 240;

  TowerEngine({
    required this.players,
    required this.mode,
    required this.difficulty,
    this.botSkill = 1,
  }) {
    for (int i = 0; i < players.length; i++) {
      _towers.add([]);
    }
    banner = _openingBanner();
    _watchdog = Timer.periodic(const Duration(seconds: 3), (_) => _recover());
  }

  void Function(TowerEvent event)? onEvent;

  int get n => players.length;
  TowerPlayer get current => players[turn];
  List<TowerBlock> get tower => _towers[turn];
  int get height => tower.length;
  bool get solo => mode <= 2;
  bool get isBlitz => mode == 1;
  bool get isZen => mode == 2;
  bool get awaitingDrop =>
      phase == TowerPhase.swinging && !current.isBot && !paused;

  String _openingBanner() {
    if (solo) return 'Tap to place the first block!';
    return '${current.name} starts — tap to drop!';
  }

  /// Screen reports its width every build (fraction math needs it only for
  /// the perfect window and bot pixel-free aiming).
  void setViewWidth(double w) {
    if (w > 0) viewWidth = w;
  }

  double get _perfectWindow {
    double px;
    switch (difficulty) {
      case 0:
        px = 13;
      case 2:
        px = 5;
      case 3:
        px = 3.2;
      default:
        px = 7.5;
    }
    return px / viewWidth;
  }

  double _swingSpeed() {
    final blocks = height;
    switch (difficulty) {
      case 0:
        return 1.15 + blocks * 0.030;
      case 2:
        return 2.2 + blocks * 0.060;
      case 3:
        return 2.9 + blocks * 0.075;
      default:
        return 1.6 + blocks * 0.045;
    }
  }

  // ------------------------------------------------------------- lifecycle
  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _attackTimer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  void _arm(Duration d, void Function() fn) {
    if (_disposed || paused) return;
    _timer?.cancel();
    _timer = Timer(d, () {
      _timer = null;
      if (!_disposed && !paused) fn();
    });
  }

  /// Freeze all timers. Resume re-arms the current phase.
  void setPaused(bool v) {
    if (paused == v || _disposed) return;
    paused = v;
    if (v) {
      _timer?.cancel();
      _timer = null;
      _attackTimer?.cancel();
      _attackTimer = null;
    } else {
      _recover();
      if (isBlitz && timeLeft > 0 && phase != TowerPhase.gameOver) {
        _startAttackClock();
      }
    }
    notifyListeners();
  }

  /// Watchdog: recover any phase found without a live timer. Respects pause.
  void _recover() {
    if (_disposed || paused) return;
    if (phase == TowerPhase.gameOver) return;
    if (_timer != null) return; // a transition is already pending
    if (phase == TowerPhase.dropping) {
      _afterDrop(); // landing anim lost its timer: finish immediately
    } else if (phase == TowerPhase.crashing) {
      _resolveMiss(); // crash beat lost its timer: resolve immediately
    } else if (phase == TowerPhase.swinging && current.isBot) {
      _botAim(); // bot aim lost its timer: re-arm
    } else if (isBlitz && phase != TowerPhase.ready && timeLeft <= 0) {
      _finishBlitz();
    }
  }

  // --------------------------------------------------------------- game flow
  /// Start a run. Called once (tap on the ready screen).
  void start() {
    if (phase != TowerPhase.ready || _disposed || paused) return;
    onEvent?.call(TowerEvent.gameStart);
    _newSwing();
    phase = TowerPhase.swinging;
    if (isBlitz) {
      timeLeft = blitzSeconds;
      blitzScore = 0;
      _startAttackClock();
    }
    banner = current.isBot ? '${current.name} is aiming…' : 'Tap to drop!';
    notifyListeners();
    _afterPhase();
  }

  void _newSwing() {
    swingW = tower.isEmpty ? baseWidth : tower.last.w;
    swingT = 0;
    swingX = (1 - swingW) * 0.5;
    swingHue = _themeHueStart + height * _themeHueStep;
    botAiming = false;
  }

  // Theme hue progression — injected by the screen (kept UI-side so the
  // engine stays theme-free and testable).
  double _themeHueStart = 200;
  double _themeHueStep = 14;
  void setThemeHues(double start, double step) {
    _themeHueStart = start;
    _themeHueStep = step;
  }

  void _startAttackClock() {
    _attackTimer?.cancel();
    _attackTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || paused || phase == TowerPhase.gameOver) return;
      timeLeft--;
      onEvent?.call(TowerEvent.tickSecond);
      if (timeLeft <= 3 && timeLeft > 0) {
        banner = '$timeLeft…';
      }
      if (timeLeft <= 0) {
        _finishBlitz();
      } else {
        notifyListeners();
      }
    });
  }

  /// Advance the swing (called by the UI ticker each frame).
  void step(double dt) {
    if (_disposed || paused) return;
    if (phase != TowerPhase.swinging) return;
    if (current.isBot && botAiming) return; // frozen while the bot aims
    swingT += dt * _swingSpeed();
    final maxX = 1 - swingW;
    swingX = maxX * (0.5 + 0.5 * sin(swingT * 2 - pi / 2));

    for (final t in tumbles) {
      t.vy += 6.5 * dt;
      t.y += t.vy * dt;
      t.rot += t.vr * dt;
    }
    tumbles.removeWhere((t) => t.y > 12);

    if (popupT > 0) {
      popupT -= dt;
      if (popupT <= 0) popup = '';
    }
  }

  /// Human tap (or bot drop). Guarded: only in swinging phase.
  void drop() {
    if (phase != TowerPhase.swinging || paused) return;
    if (current.isBot) return; // bots drop through _botDrop only
    _applyDrop(swingX);
  }

  /// Pure deterministic drop resolution. Returns the result; mutates tower.
  @visibleForTesting
  DropResult applyDrop(double xFrac) {
    final prev = tower.isEmpty
        ? TowerBlock((1 - baseWidth) / 2, baseWidth, swingHue)
        : tower.last;
    if (tower.isEmpty) tower.add(prev);

    final a0 = xFrac, a1 = xFrac + swingW;
    final b0 = prev.x, b1 = prev.x + prev.w;
    final o0 = max(a0, b0), o1 = min(a1, b1);
    final overlap = o1 - o0;
    final newTumbles = <Tumble>[];

    if (overlap <= 0) {
      // Total miss — the block tumbles away.
      newTumbles.add(Tumble(a0, swingW, -height.toDouble(), swingHue, _rand));
      return DropResult(DropKind.missed, 0, newTumbles, null);
    }

    final perfect = (o0 - b0).abs() <= _perfectWindow &&
        (o1 - b1).abs() <= _perfectWindow;
    final fullWidth = perfect || isZen;
    if (fullWidth) {
      // Snap to full support width — no trimming (zen never trims).
      final placed = TowerBlock(b0, b1 - b0, swingHue);
      tower.add(placed);
      final combo = perfect ? current.combo + 1 : 0;
      return DropResult(
          perfect ? DropKind.perfect : DropKind.placed, combo, newTumbles, placed);
    }

    // Slice off the overhang — both sides tumble with rotation.
    if (a0 < o0) {
      newTumbles.add(Tumble(a0, o0 - a0, -height.toDouble(), swingHue, _rand));
    }
    if (a1 > o1) {
      newTumbles.add(Tumble(o1, a1 - o1, -height.toDouble(), swingHue, _rand));
    }
    final placed = TowerBlock(o0, overlap, swingHue);
    tower.add(placed);
    return DropResult(DropKind.placed, 0, newTumbles, placed);
  }

  void _applyDrop(double xFrac) {
    final result = applyDrop(xFrac);
    tumbles.addAll(result.tumbles);
    final p = current;

    if (result.kind == DropKind.missed) {
      p.combo = 0;
      popup = 'MISS!';
      popupT = 1.2;
      onEvent?.call(TowerEvent.missed);
      onEvent?.call(TowerEvent.crash);
      _eliminateOrEnd();
      return;
    }

    if (result.kind == DropKind.perfect) {
      p.combo = result.combo;
      totalPerfects++;
      p.perfects++;
      final c = p.combo;
      popup = c >= 2 ? 'PERFECT x$c!' : 'PERFECT!';
      popupT = 1.0;
      onEvent?.call(TowerEvent.perfect);
    } else {
      p.combo = 0;
      onEvent?.call(TowerEvent.slice);
    }
    p.height = height;
    onEvent?.call(TowerEvent.drop);
    if (isBlitz) blitzScore++; // cumulative blocks stacked, survives resets

    phase = TowerPhase.dropping;
    notifyListeners();
    _arm(Duration(milliseconds: dropAnimMs.round()), _afterDrop);
  }

  /// Landing animation finished — advance the turn.
  void _afterDrop() {
    if (_disposed || phase != TowerPhase.dropping || paused) return;
    if (isBlitz && timeLeft <= 0) {
      _finishBlitz();
      return;
    }
    _nextTurn();
  }

  void _nextTurn() {
    if (phase == TowerPhase.gameOver) return;
    if (solo) {
      _newSwing();
      phase = TowerPhase.swinging;
      banner = 'Tap to drop!';
      notifyListeners();
      _afterPhase();
      return;
    }
    // Party / versus: next ALIVE player. Each keeps their own tower.
    int next = turn;
    for (int i = 0; i < n; i++) {
      next = (next + 1) % n;
      if (players[next].alive) break;
    }
    turn = next;
    _newSwing();
    phase = TowerPhase.swinging;
    banner = current.isBot ? '${current.name} is aiming…' : '${current.name} — tap to drop!';
    notifyListeners();
    _afterPhase();
  }

  /// A player missed: eliminate them (party/versus) or end the run (solo).
  /// The crash beat (phase crashing) is separate from the drop landing phase
  /// so the watchdog can never resolve one as the other.
  void _eliminateOrEnd() {
    phase = TowerPhase.crashing;
    notifyListeners();
    _arm(const Duration(milliseconds: 900), _resolveMiss);
  }

  void _resolveMiss() {
    if (_disposed || paused || phase != TowerPhase.crashing) return;
    if (solo) {
      if (isBlitz) {
        // Blitz: a miss resets the tower but the clock keeps running.
        _towers[turn] = [];
        _newSwing();
        phase = TowerPhase.swinging;
        banner = 'Rebuilding — keep going!';
        notifyListeners();
        _afterPhase();
      } else {
        _finishSolo();
      }
      return;
    }
    current.alive = false;
    final alive = [for (int i = 0; i < n; i++) if (players[i].alive) i];
    if (alive.length <= 1) {
      _finishParty(alive.isEmpty ? null : alive.first);
    } else {
      banner = '${current.name} is out!';
      notifyListeners();
      _arm(const Duration(milliseconds: 700), _nextTurn);
    }
  }

  void _finishSolo() {
    phase = TowerPhase.gameOver;
    _attackTimer?.cancel();
    onEvent?.call(TowerEvent.lose);
    banner = 'Tower toppled at ${height} blocks!';
    notifyListeners();
  }

  void _finishBlitz() {
    if (phase == TowerPhase.gameOver) return;
    phase = TowerPhase.gameOver;
    _attackTimer?.cancel();
    onEvent?.call(TowerEvent.lose);
    banner = 'Time! $blitzScore blocks stacked!';
    notifyListeners();
  }

  void _finishParty(int? winner) {
    phase = TowerPhase.gameOver;
    winnerIndex = winner;
    if (winner != null) {
      onEvent?.call(TowerEvent.win);
      banner = '${players[winner].name} wins the yard!';
    } else {
      onEvent?.call(TowerEvent.lose);
      banner = 'Everyone toppled!';
    }
    notifyListeners();
  }

  /// Called whenever we enter swinging: bots aim themselves.
  void _afterPhase() {
    if (phase != TowerPhase.swinging || _disposed || paused) return;
    if (current.isBot) _botAim();
  }

  // ---------------------------------------------------------------- bot AI
  /// Bot aim error (fraction of block width) per skill — RULES.md §11.
  double _botSigma() {
    switch (botSkill) {
      case 0:
        return 0.30; // easy: clumsy, often trims
      case 2:
        return 0.055; // hard: near-perfect, rare miss
      default:
        return 0.14; // medium
    }
  }

  void _botAim() {
    if (phase != TowerPhase.swinging || !current.isBot || _disposed || paused) {
      return;
    }
    botAiming = true;
    // Ideal drop = centered on the block below.
    final prev = tower.isEmpty
        ? TowerBlock((1 - baseWidth) / 2, baseWidth, swingHue)
        : tower.last;
    final idealX = prev.x + prev.w / 2 - swingW / 2;
    // Gaussian-ish error via summed uniforms.
    final noise = ((_rand.nextDouble() + _rand.nextDouble() + _rand.nextDouble()) - 1.5) / 1.5;
    var target = idealX + noise * _botSigma() * swingW * 2;
    if (botSkill == 2 && _rand.nextDouble() < 0.04) {
      // Hard bot very rarely misjudges badly.
      target += (swingW * 0.9) * (_rand.nextBool() ? 1 : -1);
    }
    botTargetX = target.clamp(-0.05, 1.05 - swingW);
    banner = '${current.name} is aiming…';
    notifyListeners();
    _arm(const Duration(milliseconds: 950), _botDrop);
  }

  void _botDrop() {
    if (phase != TowerPhase.swinging ||
        !current.isBot ||
        _disposed ||
        paused) {
      return;
    }
    botAiming = false;
    swingX = botTargetX; // the crane visibly swings to the aim point
    notifyListeners();
    _arm(const Duration(milliseconds: 180), () => _applyDrop(swingX));
  }

  /// Best (tallest) height across all players — for party results.
  int get bestHeight {
    var m = 0;
    for (final p in players) {
      m = max(m, p.height);
    }
    return max(m, height);
  }

  void restart() {
    _timer?.cancel();
    _attackTimer?.cancel();
    paused = false;
    phase = TowerPhase.ready;
    turn = 0;
    tumbles.clear();
    popup = '';
    popupT = 0;
    totalPerfects = 0;
    winnerIndex = null;
    timeLeft = 0;
    blitzScore = 0;
    botAiming = false;
    for (int i = 0; i < n; i++) {
      _towers[i] = [];
      players[i].alive = true;
      players[i].height = 0;
      players[i].perfects = 0;
      players[i].combo = 0;
    }
    banner = _openingBanner();
    notifyListeners();
  }
}
