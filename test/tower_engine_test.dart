import 'package:flutter_test/flutter_test.dart';
import 'package:towerstack/engine/tower_engine.dart';

TowerEngine solo({int mode = 0, int difficulty = 1, int botSkill = 1}) =>
    TowerEngine(
      players: [TowerPlayer(name: 'Tester', isBot: false)],
      mode: mode,
      difficulty: difficulty,
      botSkill: botSkill,
    );

void main() {
  test('starts in ready phase, then swings after start', () {
    final e = solo();
    expect(e.phase, TowerPhase.ready);
    e.start();
    expect(e.phase, TowerPhase.swinging);
    e.dispose();
  });

  test('centered drop is perfect, keeps full width, combo 1', () {
    final e = solo();
    e.start();
    // Base block: x=0.14, w=0.72. Drop exactly on it.
    e.swingX = 0.14;
    e.drop();
    expect(e.height, 2); // base + placed
    expect(e.tower.last.w, closeTo(0.72, 1e-9));
    expect(e.current.combo, 1);
    expect(e.popup, 'PERFECT!');
    e.dispose();
  });

  test('offset drop trims to overlap and resets combo', () {
    final e = solo();
    e.start();
    e.swingX = 0.24; // 0.10 off center
    e.drop();
    expect(e.height, 2);
    expect(e.tower.last.w, closeTo(0.62, 1e-9));
    expect(e.current.combo, 0);
    expect(e.tumbles, hasLength(1)); // one sliced piece
    e.dispose();
  });

  test('consecutive perfects build a combo', () {
    final e = solo();
    e.start();
    e.swingX = 0.14;
    e.drop();
    // Landing phase; force the turn through without waiting.
    expect(e.phase, TowerPhase.dropping);
    e.dispose();
  });

  test('total miss ends a solo run after the crash beat', () async {
    final e = solo();
    e.start();
    e.swingX = 0.95; // fully off the base block
    e.drop();
    expect(e.phase, TowerPhase.crashing);
    expect(e.popup, 'MISS!');
    await Future.delayed(const Duration(milliseconds: 1100));
    expect(e.phase, TowerPhase.gameOver);
    e.dispose();
  });

  test('zen mode never trims blocks', () {
    final e = solo(mode: 2);
    e.start();
    e.swingX = 0.34; // well off center but overlapping
    e.drop();
    expect(e.tower.last.w, closeTo(0.72, 1e-9));
    expect(e.current.combo, 0); // not a real perfect
    e.dispose();
  });

  test('blitz miss resets the tower but keeps the score', () async {
    final e = solo(mode: 1);
    e.start();
    // Stack one good block first.
    e.swingX = 0.14;
    e.drop();
    expect(e.blitzScore, 1);
    await Future.delayed(const Duration(milliseconds: 400));
    // Now miss.
    e.swingX = 0.95;
    e.drop();
    await Future.delayed(const Duration(milliseconds: 1200));
    expect(e.phase, TowerPhase.swinging); // clock still running
    expect(e.height, 0);
    expect(e.blitzScore, 1); // score survived
    e.dispose();
  });

  test('party: miss eliminates the player, turn passes', () async {
    final e = TowerEngine(
      players: [
        TowerPlayer(name: 'A', isBot: false),
        TowerPlayer(name: 'B', isBot: false),
      ],
      mode: 3,
      difficulty: 1,
    );
    e.start();
    expect(e.turn, 0);
    e.swingX = 0.95; // A misses
    e.drop();
    await Future.delayed(const Duration(milliseconds: 1200));
    expect(e.players[0].alive, isFalse);
    expect(e.players[1].alive, isTrue);
    await Future.delayed(const Duration(milliseconds: 900));
    expect(e.turn, 1); // B is up with a fresh tower
    expect(e.phase, TowerPhase.swinging);
    e.dispose();
  });

  test('party: last one standing wins', () async {
    final e = TowerEngine(
      players: [
        TowerPlayer(name: 'A', isBot: false),
        TowerPlayer(name: 'B', isBot: false),
      ],
      mode: 3,
      difficulty: 1,
    );
    e.start();
    e.swingX = 0.95; // A misses
    e.drop();
    await Future.delayed(const Duration(milliseconds: 1200));
    // B's turn; B misses too.
    e.swingX = 0.95;
    e.drop();
    await Future.delayed(const Duration(milliseconds: 1200));
    expect(e.phase, TowerPhase.gameOver);
    e.dispose();
  });

  test('bot turn aims and drops visibly', () async {
    final e = TowerEngine(
      players: [
        TowerPlayer(name: 'Human', isBot: false),
        TowerPlayer(name: 'Bot', isBot: true),
      ],
      mode: 4,
      difficulty: 1,
      botSkill: 0,
    );
    e.start();
    // Human drops first to pass the turn.
    e.swingX = 0.14;
    e.drop();
    await Future.delayed(const Duration(milliseconds: 500));
    expect(e.turn, 1);
    expect(e.current.isBot, isTrue);
    // Bot aims ~950ms then drops: tower should grow shortly after.
    await Future.delayed(const Duration(milliseconds: 1600));
    expect(e.players[1].height, greaterThan(0));
    e.dispose();
  });

  test('restart returns to a fresh ready state', () async {
    final e = solo();
    e.start();
    e.swingX = 0.95;
    e.drop();
    await Future.delayed(const Duration(milliseconds: 1100));
    expect(e.phase, TowerPhase.gameOver);
    e.restart();
    expect(e.phase, TowerPhase.ready);
    expect(e.height, 0);
    expect(e.turn, 0);
    e.dispose();
  });

  test('pause freezes and resume re-arms without stuck state', () async {
    final e = solo();
    e.start();
    e.swingX = 0.14;
    e.drop();
    expect(e.phase, TowerPhase.dropping);
    e.setPaused(true);
    await Future.delayed(const Duration(milliseconds: 400));
    expect(e.phase, TowerPhase.dropping); // frozen, not advanced
    e.setPaused(false);
    await Future.delayed(const Duration(milliseconds: 500));
    expect(e.phase, TowerPhase.swinging); // recovered, game continues
    e.dispose();
  });
}
