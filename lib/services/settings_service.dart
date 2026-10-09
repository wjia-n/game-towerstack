import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/tower_themes.dart';

/// Persisted settings + profile for Tower Stack. Survives app restarts.
///
/// The player profile (name + records) is stored as ONE JSON string.
/// NEVER use setStringList for ordered data on Android — SharedPreferences
/// stores StringLists as an unordered StringSet and scrambles the order.
class TowerSettings extends ChangeNotifier {
  static const _kMusic = 'towerstack_music_on';
  static const _kSfx = 'towerstack_sfx_on';
  static const _kVolume = 'towerstack_volume';
  static const _kTheme = 'towerstack_theme_id';
  static const _kBlockStyle = 'towerstack_block_style';
  static const _kDifficulty = 'towerstack_difficulty'; // 0 chill..3 master
  static const _kMode = 'towerstack_game_mode';
  static const _kPlayers = 'towerstack_player_count';
  static const _kBots = 'towerstack_bot_count';
  static const _kIsPro = 'towerstack_is_pro';
  static const _kNamesJson = 'towerstack_player_names_json';
  /// Profile: ONE JSON string {name, bestClassic, bestZen, bestBlitz,
  /// bestParty, bestVersus, games, perfects}.
  static const _kProfileJson = 'towerstack_profile_json';
  /// Legacy keys (migrated once, then removed).
  static const _kLegacyBest = 'towerstack_best';
  static const _kCustomPrefix = 'towerstack_custom_';

  static const defaultNames = ['Builder 1', 'Builder 2', 'Builder 3', 'Builder 4'];

  static String _cleanName(int i, Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? defaultNames[i] : s;
  }

  /// Decode player names; falls back to defaults on missing/corrupt data.
  static List<String> decodePlayerNames(String? raw) {
    if (raw == null) return List.of(defaultNames);
    try {
      final d = jsonDecode(raw);
      if (d is List && d.length == 4) {
        return [for (int i = 0; i < 4; i++) _cleanName(i, d[i])];
      }
    } catch (_) {}
    return List.of(defaultNames);
  }

  static String encodePlayerNames(List<String> names) => jsonEncode(names);

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  String themeId = 'sunrise';
  int blockStyle = 0;
  int difficulty = 1; // classic default
  int gameMode = 0; // classic climb
  int playerCount = 2;
  List<int> botSeats = [1];
  List<String> playerNames = List.of(defaultNames);
  bool isPro = false;

  // Profile (renameable, one JSON blob).
  String playerName = 'Builder';
  int bestClassic = 0;
  int bestZen = 0;
  int bestBlitz = 0;
  int gamesPlayed = 0;
  int perfects = 0;

  /// Custom theme colors (ARGB ints). Defaults mirror Sunrise Yard.
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'skyTop': 0xFF7FB3D5,
    'skyBottom': 0xFFF6D8A8,
    'ground': 0xFF8A6B4A,
    'groundDark': 0xFF5C4630,
    'beamDark': 0xFF4A3220,
    'beamMid': 0xFF6B4A2E,
    'beamDeep': 0xFF2E1E12,
    'accent': 0xFFD9A441,
    'accentLight': 0xFFF2D38A,
    'accentDark': 0xFF96691F,
    'ivory': 0xFFF7EFE0,
  };
  static const double _defaultHueStart = 200;
  static const double _defaultHueStep = 14;

  double customHueStart = _defaultHueStart;
  double customHueStep = _defaultHueStep;

  /// Builds the user-designed custom theme from stored colors.
  TowerThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return TowerThemeDef(
      id: 'custom',
      name: 'My Yard',
      skyTop: c('skyTop'),
      skyBottom: c('skyBottom'),
      ground: c('ground'),
      groundDark: c('groundDark'),
      beamDark: c('beamDark'),
      beamMid: c('beamMid'),
      beamDeep: c('beamDeep'),
      accent: c('accent'),
      accentLight: c('accentLight'),
      accentDark: c('accentDark'),
      ivory: c('ivory'),
      hueStart: customHueStart,
      hueStep: customHueStep,
    );
  }

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    themeId = p.getString(_kTheme) ?? 'sunrise';
    blockStyle = (p.getInt(_kBlockStyle) ?? 0)
        .clamp(0, BlockStyles.names.length - 1);
    difficulty = (p.getInt(_kDifficulty) ?? 1).clamp(0, 3);
    gameMode = (p.getInt(_kMode) ?? 0).clamp(0, GameModes.ids.length - 1);
    playerCount = (p.getInt(_kPlayers) ?? 2).clamp(2, 4);
    final bots = p.getInt(_kBots) ?? 1;
    botSeats = [
      for (int i = 1; i <= bots && i < playerCount; i++) i,
    ];
    isPro = p.getBool(_kIsPro) ?? false;
    playerNames = decodePlayerNames(p.getString(_kNamesJson));

    // Profile: order-safe JSON. Migrate the legacy single int best once.
    final profileRaw = p.getString(_kProfileJson);
    if (profileRaw != null) {
      _decodeProfile(profileRaw);
    } else {
      bestClassic = p.getInt(_kLegacyBest) ?? 0;
      playerName = 'Builder';
    }
    for (final k in _defaultCustomColors.keys) {
      customColors[k] = p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    customHueStart =
        p.getDouble('${_kCustomPrefix}hueStart') ?? _defaultHueStart;
    customHueStep =
        p.getDouble('${_kCustomPrefix}hueStep') ?? _defaultHueStep;
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  void _decodeProfile(String raw) {
    try {
      final d = jsonDecode(raw);
      if (d is Map) {
        final n = (d['name'] as String?)?.trim();
        playerName = (n == null || n.isEmpty) ? 'Builder' : n;
        bestClassic = (d['bestClassic'] as int?) ?? 0;
        bestZen = (d['bestZen'] as int?) ?? 0;
        bestBlitz = (d['bestBlitz'] as int?) ?? 0;
        gamesPlayed = (d['games'] as int?) ?? 0;
        perfects = (d['perfects'] as int?) ?? 0;
        return;
      }
    } catch (_) {}
    playerName = 'Builder';
  }

  String _encodeProfile() => jsonEncode({
        'name': playerName,
        'bestClassic': bestClassic,
        'bestZen': bestZen,
        'bestBlitz': bestBlitz,
        'games': gamesPlayed,
        'perfects': perfects,
      });

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setString(_kTheme, themeId);
    await p.setInt(_kBlockStyle, blockStyle);
    await p.setInt(_kDifficulty, difficulty);
    await p.setInt(_kMode, gameMode);
    await p.setInt(_kPlayers, playerCount);
    await p.setInt(_kBots, botSeats.length);
    await p.setBool(_kIsPro, isPro);
    await p.setString(_kNamesJson, encodePlayerNames(playerNames));
    await p.setString(_kProfileJson, _encodeProfile());
    await p.remove(_kLegacyBest); // drop the legacy key for good
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
    await p.setDouble('${_kCustomPrefix}hueStart', customHueStart);
    await p.setDouble('${_kCustomPrefix}hueStep', customHueStep);
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || TowerThemes.isProTheme(themeId)) {
      themeId = 'sunrise';
      changed = true;
    }
    if (BlockStyles.isPro(blockStyle)) {
      blockStyle = 0;
      changed = true;
    }
    if (Difficulties.isPro(difficulty)) {
      difficulty = 1;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  /// Profile name: COMMIT (focus loss / done / game start). Trims and falls
  /// back to the default so engine-facing names are always displayable.
  Future<void> setPlayerName(String name) async {
    final clean = name.trim();
    playerName = clean.isEmpty ? 'Builder' : clean;
    notifyListeners();
    await _save();
  }

  /// Profile name: RAW keystroke save. Persists exactly what was typed
  /// (even half-typed) on EVERY keystroke so a process kill can never lose
  /// it. The next commit (focus loss / done / play) cleans it up.
  Future<void> setPlayerNameRaw(String raw) async {
    playerName = raw;
    notifyListeners();
    await _save();
  }

  /// Force a commit of the raw profile name (e.g. right before a game).
  Future<void> commitPlayerName() => setPlayerName(playerName);

  /// Pass-and-play seat name: COMMIT (focus loss / done / game start).
  Future<void> setPassPlayName(int index, String name) async {
    if (index < 0 || index > 3) return;
    playerNames[index] = _cleanName(index, name);
    notifyListeners();
    await _save();
  }

  /// Pass-and-play seat name: RAW keystroke save. See [setPlayerNameRaw].
  Future<void> setPassPlayNameRaw(int index, String raw) async {
    if (index < 0 || index > 3) return;
    playerNames[index] = raw;
    notifyListeners();
    await _save();
  }

  /// Force a commit of the raw seat name.
  Future<void> commitPassPlayName(int i) =>
      setPassPlayName(i, playerNames[i]);

  /// Record a finished run: best heights per mode + lifetime stats.
  Future<void> recordGame(
      {required int mode, required int height, required int perfectCount}) async {
    gamesPlayed++;
    perfects += perfectCount;
    switch (mode) {
      case 1:
        if (height > bestBlitz) bestBlitz = height;
      case 2:
        if (height > bestZen) bestZen = height;
      default:
        if (height > bestClassic) bestClassic = height;
    }
    notifyListeners();
    await _save();
  }

  int bestForMode(int mode) {
    switch (mode) {
      case 1:
        return bestBlitz;
      case 2:
        return bestZen;
      default:
        return bestClassic;
    }
  }

  /// Multiplayer finished: only lifetime games count (no per-mode records).
  Future<void> recordPartyGame() async {
    gamesPlayed++;
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && (id == 'custom' || TowerThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setBlockStyle(int v) async {
    v = v.clamp(0, BlockStyles.names.length - 1);
    if (!isPro && BlockStyles.isPro(v)) return;
    blockStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setDifficulty(int v) async {
    v = v.clamp(0, Difficulties.names.length - 1);
    if (!isPro && Difficulties.isPro(v)) return;
    difficulty = v;
    notifyListeners();
    await _save();
  }

  Future<void> setGameMode(int v) async {
    gameMode = v.clamp(0, GameModes.ids.length - 1);
    notifyListeners();
    await _save();
  }

  /// Pass-and-play / versus-bot setup: [players] 2..4 seats, [botSeats] the
  /// seats that are bots (never all seats — at least one human must play).
  Future<void> setSetup(
      {required int players, required List<int> botSeats}) async {
    playerCount = players.clamp(2, 4);
    this.botSeats = [
      for (final s in botSeats)
        if (s >= 0 && s < playerCount) s
    ];
    if (this.botSeats.length >= playerCount) {
      this.botSeats = this.botSeats.sublist(0, playerCount - 1);
    }
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return; // custom theme creator is a Pro feature
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> setCustomHue(double start, double step) async {
    if (!isPro) return;
    customHueStart = start.clamp(0, 360);
    customHueStep = step.clamp(-30, 30);
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    customHueStart = _defaultHueStart;
    customHueStep = _defaultHueStep;
    notifyListeners();
    await _save();
  }
}
