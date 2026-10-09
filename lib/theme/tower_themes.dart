import 'package:flutter/material.dart';

/// Theme, block-style and difficulty catalog for Tower Stack.
///
/// Art direction: a warm construction yard full of real physical materials —
/// timber, brick, stone, rope and canvas. Skies change per theme (sunrise,
/// noon, sunset, night shift…), blocks feel heavy and solid. No neon, no
/// cyberpunk, no glowing AI-dashboard looks.
class TowerThemeDef {
  final String id;
  final String name;
  final Color skyTop;
  final Color skyBottom;
  final Color ground;
  final Color groundDark;
  final Color beamDark; // UI wood dark
  final Color beamMid; // UI wood mid
  final Color beamDeep; // UI wood deepest
  final Color accent; // rope / brass
  final Color accentLight;
  final Color accentDark;
  final Color ivory;
  final double hueStart; // block hue progression start
  final double hueStep; // hue shift per stacked block

  const TowerThemeDef({
    required this.id,
    required this.name,
    required this.skyTop,
    required this.skyBottom,
    required this.ground,
    required this.groundDark,
    required this.beamDark,
    required this.beamMid,
    required this.beamDeep,
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.ivory,
    required this.hueStart,
    required this.hueStep,
  });
}

class TowerThemes {
  /// First 4 are the FREE starter themes. The rest are PRO.
  static const List<String> freeThemeIds = [
    'sunrise',
    'noon',
    'sunset',
    'workshop',
  ];

  static const List<TowerThemeDef> all = [
    TowerThemeDef(
      id: 'sunrise',
      name: 'Sunrise Yard',
      skyTop: Color(0xFF7FB3D5),
      skyBottom: Color(0xFFF6D8A8),
      ground: Color(0xFF8A6B4A),
      groundDark: Color(0xFF5C4630),
      beamDark: Color(0xFF4A3220),
      beamMid: Color(0xFF6B4A2E),
      beamDeep: Color(0xFF2E1E12),
      accent: Color(0xFFD9A441),
      accentLight: Color(0xFFF2D38A),
      accentDark: Color(0xFF96691F),
      ivory: Color(0xFFF7EFE0),
      hueStart: 200,
      hueStep: 14,
    ),
    TowerThemeDef(
      id: 'noon',
      name: 'High Noon Site',
      skyTop: Color(0xFF5AA7DE),
      skyBottom: Color(0xFFCDEBFA),
      ground: Color(0xFF9A7B52),
      groundDark: Color(0xFF67543A),
      beamDark: Color(0xFF54381F),
      beamMid: Color(0xFF7A5630),
      beamDeep: Color(0xFF33220F),
      accent: Color(0xFFC98F2B),
      accentLight: Color(0xFFF0C977),
      accentDark: Color(0xFF8A5F1C),
      ivory: Color(0xFFFFF6E6),
      hueStart: 45,
      hueStep: 12,
    ),
    TowerThemeDef(
      id: 'sunset',
      name: 'Sunset Crane',
      skyTop: Color(0xFF6B4E8E),
      skyBottom: Color(0xFFF2A56B),
      ground: Color(0xFF7A5A3E),
      groundDark: Color(0xFF4F3A28),
      beamDark: Color(0xFF3E2A18),
      beamMid: Color(0xFF5E4026),
      beamDeep: Color(0xFF241708),
      accent: Color(0xFFE0A83C),
      accentLight: Color(0xFFF7D98A),
      accentDark: Color(0xFF9A6B1E),
      ivory: Color(0xFFFBEFD8),
      hueStart: 10,
      hueStep: 13,
    ),
    TowerThemeDef(
      id: 'workshop',
      name: 'Timber Workshop',
      skyTop: Color(0xFF8FA3B8),
      skyBottom: Color(0xFFD9CDB4),
      ground: Color(0xFF6E5136),
      groundDark: Color(0xFF483524),
      beamDark: Color(0xFF3B2416),
      beamMid: Color(0xFF5C3A21),
      beamDeep: Color(0xFF241309),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF5EFE0),
      hueStart: 30,
      hueStep: 11,
    ),
    // ---------------- PRO themes ----------------
    TowerThemeDef(
      id: 'night',
      name: 'Night Shift',
      skyTop: Color(0xFF101B33),
      skyBottom: Color(0xFF2E3D63),
      ground: Color(0xFF3A3F52),
      groundDark: Color(0xFF23263A),
      beamDark: Color(0xFF1C2438),
      beamMid: Color(0xFF2C3A55),
      beamDeep: Color(0xFF101624),
      accent: Color(0xFFC0C6D4),
      accentLight: Color(0xFFE8ECF5),
      accentDark: Color(0xFF7E8698),
      ivory: Color(0xFFF2EEE4),
      hueStart: 210,
      hueStep: 10,
    ),
    TowerThemeDef(
      id: 'frost',
      name: 'Frosty Morning',
      skyTop: Color(0xFF9FC3DE),
      skyBottom: Color(0xFFEAF4FB),
      ground: Color(0xFFB9C7D2),
      groundDark: Color(0xFF8496A6),
      beamDark: Color(0xFF3E4C5C),
      beamMid: Color(0xFF5A6C7E),
      beamDeep: Color(0xFF26303C),
      accent: Color(0xFF7FB3D5),
      accentLight: Color(0xFFC4E0F2),
      accentDark: Color(0xFF4E7CA3),
      ivory: Color(0xFFFBFEFF),
      hueStart: 190,
      hueStep: 8,
    ),
    TowerThemeDef(
      id: 'desert',
      name: 'Desert Dunes',
      skyTop: Color(0xFF4EA3D8),
      skyBottom: Color(0xFFF7E3B0),
      ground: Color(0xFFD9B87A),
      groundDark: Color(0xFFA8844E),
      beamDark: Color(0xFF6B4A24),
      beamMid: Color(0xFF9A6F3A),
      beamDeep: Color(0xFF42290F),
      accent: Color(0xFFC66A2B),
      accentLight: Color(0xFFEEA968),
      accentDark: Color(0xFF8A4417),
      ivory: Color(0xFFFFF3DC),
      hueStart: 24,
      hueStep: 9,
    ),
    TowerThemeDef(
      id: 'harbor',
      name: 'Harbor Pier',
      skyTop: Color(0xFF3E7FB8),
      skyBottom: Color(0xFFBFE0EA),
      ground: Color(0xFF7C6A55),
      groundDark: Color(0xFF52463A),
      beamDark: Color(0xFF2E4038),
      beamMid: Color(0xFF4A655A),
      beamDeep: Color(0xFF182420),
      accent: Color(0xFFD97B2B),
      accentLight: Color(0xFFF2B26B),
      accentDark: Color(0xFF96521A),
      ivory: Color(0xFFF4EFE2),
      hueStart: 175,
      hueStep: 12,
    ),
    TowerThemeDef(
      id: 'forest',
      name: 'Forest Clearing',
      skyTop: Color(0xFF7FB069),
      skyBottom: Color(0xFFDDEBB8),
      ground: Color(0xFF6B7A44),
      groundDark: Color(0xFF47522E),
      beamDark: Color(0xFF2E3B22),
      beamMid: Color(0xFF4A5A34),
      beamDeep: Color(0xFF1A2312),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF7F2DF),
      hueStart: 100,
      hueStep: 14,
    ),
    TowerThemeDef(
      id: 'candy',
      name: 'Candy Workshop',
      skyTop: Color(0xFFF2A7C3),
      skyBottom: Color(0xFFFDEBD3),
      ground: Color(0xFFB98A94),
      groundDark: Color(0xFF8A5F68),
      beamDark: Color(0xFF5C3A45),
      beamMid: Color(0xFF8A5663),
      beamDeep: Color(0xFF3A2229),
      accent: Color(0xFFD94F70),
      accentLight: Color(0xFFF5A8BC),
      accentDark: Color(0xFF9A2F4C),
      ivory: Color(0xFFFFF6F0),
      hueStart: 320,
      hueStep: 16,
    ),
    TowerThemeDef(
      id: 'ember',
      name: 'Ember Quarry',
      skyTop: Color(0xFF3A2A33),
      skyBottom: Color(0xFF8A4A3A),
      ground: Color(0xFF5C4038),
      groundDark: Color(0xFF382722),
      beamDark: Color(0xFF3A2420),
      beamMid: Color(0xFF5E3A30),
      beamDeep: Color(0xFF221310),
      accent: Color(0xFFE07B2B),
      accentLight: Color(0xFFF5B06B),
      accentDark: Color(0xFF9A4F17),
      ivory: Color(0xFFF7E9D4),
      hueStart: 5,
      hueStep: 7,
    ),
    TowerThemeDef(
      id: 'rainy',
      name: 'Rainy Day',
      skyTop: Color(0xFF5C6E82),
      skyBottom: Color(0xFFB8C7D4),
      ground: Color(0xFF6E7A68),
      groundDark: Color(0xFF49523F),
      beamDark: Color(0xFF2E3B44),
      beamMid: Color(0xFF4A5C68),
      beamDeep: Color(0xFF1A2229),
      accent: Color(0xFF8FA3B8),
      accentLight: Color(0xFFC9D9E8),
      accentDark: Color(0xFF5C6E82),
      ivory: Color(0xFFF0F4F7),
      hueStart: 205,
      hueStep: 6,
    ),
    TowerThemeDef(
      id: 'orchard',
      name: 'Autumn Orchard',
      skyTop: Color(0xFF7FB3D5),
      skyBottom: Color(0xFFF7D9A0),
      ground: Color(0xFF8A6B44),
      groundDark: Color(0xFF5C472E),
      beamDark: Color(0xFF4A3220),
      beamMid: Color(0xFF744E2C),
      beamDeep: Color(0xFF2E1E10),
      accent: Color(0xFFB85C2B),
      accentLight: Color(0xFFE89B62),
      accentDark: Color(0xFF7E3C17),
      ivory: Color(0xFFFBF0DA),
      hueStart: 20,
      hueStep: 15,
    ),
    TowerThemeDef(
      id: 'sakura',
      name: 'Spring Blossom',
      skyTop: Color(0xFF8FBFE0),
      skyBottom: Color(0xFFFBE3EC),
      ground: Color(0xFF7A9A5C),
      groundDark: Color(0xFF526B3E),
      beamDark: Color(0xFF3A3226),
      beamMid: Color(0xFF5C4E38),
      beamDeep: Color(0xFF211C12),
      accent: Color(0xFFD98AA8),
      accentLight: Color(0xFFF2BFD2),
      accentDark: Color(0xFF9A5C74),
      ivory: Color(0xFFFFF8F2),
      hueStart: 300,
      hueStep: 13,
    ),
  ];

  static TowerThemeDef byId(String id, {TowerThemeDef? custom}) {
    if (id == 'custom' && custom != null) return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }

  static bool isProTheme(String id) =>
      !freeThemeIds.contains(id) && id != 'classic';
}

/// Physical block styles — how each stacked block is rendered.
/// First 3 free, the rest PRO.
class BlockStyles {
  static const names = [
    'Timber Plank', // 0 free
    'Red Brick', // 1 free
    'Gray Stone', // 2 free
    'Marble Slab', // 3 pro
    'Steel Beam', // 4 pro
    'Bamboo Pole', // 5 pro
    'Candy Block', // 6 pro
    'Obsidian', // 7 pro
    'Mossy Stone', // 8 pro
    'Golden Beam', // 9 pro
  ];

  static const descriptions = [
    'Warm pine with grain',
    'Classic fired brick',
    'Quarried gray stone',
    'Polished veined marble',
    'Riveted steel girder',
    'Fresh-cut bamboo',
    'Swirled candy slab',
    'Volcanic black glass',
    'Stone kissed with moss',
    'Gilded hardwood beam',
  ];

  static const freeCount = 3;
  static bool isPro(int index) => index >= freeCount;
}

/// Difficulty tiers: swing speed, perfect window and block shrink scaling.
class Difficulties {
  static const names = ['Chill', 'Classic', 'Turbo', 'Master'];
  static const descriptions = [
    'Slow crane, forgiving',
    'The standard climb',
    'Fast crane, tight timing',
    'PRO: blistering speed',
  ];

  /// 3 = Master is a PRO feature.
  static bool isPro(int index) => index >= 3;

  /// Swing frequency base per difficulty (rad/s-ish factor).
  static double swingSpeed(int difficulty, int blocks) {
    switch (difficulty) {
      case 0:
        return 1.15 + blocks * 0.030;
      case 1:
        return 1.6 + blocks * 0.045;
      case 2:
        return 2.2 + blocks * 0.060;
      default:
        return 2.9 + blocks * 0.075;
    }
  }

  /// Perfect-window in logical px per difficulty.
  static double perfectWindow(int difficulty) {
    switch (difficulty) {
      case 0:
        return 12;
      case 1:
        return 7;
      case 2:
        return 4.5;
      default:
        return 3.0;
    }
  }
}

/// Game modes.
class GameModes {
  static const ids = ['classic', 'attack', 'zen', 'party', 'versus'];
  static const names = [
    'Classic Climb',
    '60-Second Blitz',
    'Zen Tower',
    'Pass & Play',
    'Vs Bot',
  ];
  static const descriptions = [
    'Stack until one block misses. Beat your best.',
    'How tall can you build in 60 seconds?',
    'No shrinking blocks — pure flow, endless calm.',
    '2–4 friends, one tower each, last one standing.',
    'Take turns stacking against the crane bot.',
  ];

  /// Versus-bot difficulty maps 1:1 to bot skill (0 easy, 1 medium, 2 hard);
  /// Master difficulty is PRO-gated elsewhere.
  static String id(int index) => ids[index.clamp(0, ids.length - 1)];
}
