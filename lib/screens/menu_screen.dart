import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/tower_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/craftsman.dart';
import '../theme/tower_themes.dart';
import 'custom_theme_screen.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

/// Main menu — Tower Stack craftsman edition.
class MenuScreen extends StatefulWidget {
  final TowerAudio audio;
  final TowerSettings settings;

  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final StoreService _store = StoreService();

  TowerSettings get _s => widget.settings;
  TowerThemeDef get _t => TowerThemes.byId(_s.themeId, custom: _s.customTheme);

  @override
  void initState() {
    super.initState();
    widget.audio.startMenuMusic();
    _store.init().then((_) {
      if (mounted) setState(() {});
    });
    _store.lastThanks.addListener(_onThanks);
    _store.proPurchased.addListener(_onPro);
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Craft.body(15, theme: _t)),
        backgroundColor: _t.beamDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _store.lastThanks.value = null;
  }

  void _onPro() {
    if (_store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      _store.proPurchased.value = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.proPurchased.removeListener(_onPro);
    _store.dispose();
    super.dispose();
  }

  /// Real in-app review flow: the Play in-app review sheet when available,
  /// otherwise fall back to opening the store listing. No fake dialogs.
  Future<void> _requestReview() async {
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await review.openStoreListing(appStoreId: null);
      }
    } catch (_) {
      // Review UI unavailable on this device/build: stay silent, no fake UI.
    }
  }

  Future<void> _play() async {
    widget.audio.gameStart();
    // Commit any raw half-typed names before the run so engine-facing
    // names are always cleaned and displayable.
    await _s.commitPlayerName();
    for (int i = 0; i < _s.playerCount; i++) {
      await _s.commitPassPlayName(i);
    }
    final mode = _s.gameMode;
    late final List<TowerPlayer> players;
    if (mode == 3) {
      // Party: each seat gets its own name + bot flag.
      players = [
        for (int i = 0; i < _s.playerCount; i++)
          TowerPlayer(
              name: _s.playerNames[i], isBot: _s.botSeats.contains(i)),
      ];
    } else if (mode == 4) {
      players = [
        TowerPlayer(name: _s.playerName, isBot: false),
        TowerPlayer(name: 'Crane Bot 🤖', isBot: true),
      ];
    } else {
      players = [TowerPlayer(name: _s.playerName, isBot: false)];
    }
    final engine = TowerEngine(
      players: players,
      mode: mode,
      difficulty: _s.difficulty,
      botSkill: mode == 4 ? _s.difficulty.clamp(0, 2) : 1,
    );
    // App-scoped music: keep playing across screens. GameScreen switches
    // to the game track on entry; we switch back to menu music on return.
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => GameScreen(
        engine: engine,
        audio: widget.audio,
        settings: _s,
      ),
    ))
        .then((_) {
      if (mounted) widget.audio.startMenuMusic();
    });
  }

  Future<void> _goPro() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProScreen(
        audio: widget.audio,
        settings: _s,
        store: _store,
      ),
    ));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return TimberBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _s,
            builder: (_, _) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Logo plaque.
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: t.accent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          offset: const Offset(0, 8),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/towerstack_logo.png',
                        fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 14),
                  Text('TOWER STACK', style: Craft.display(42, theme: t)),
                  Text(
                    'BUILD IT TALL, BUILD IT TRUE',
                    style: Craft.label(12, theme: t),
                  ),
                  const SizedBox(height: 22),
                  TimberButton(label: '▶  Play', onTap: _play, theme: t, width: 260),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      widget.audio.click();
                      _goPro();
                    },
                    child: Container(
                      width: 260,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(colors: [
                          t.accent.withValues(alpha: 0.9),
                          t.accentDark,
                        ]),
                        border: Border.all(color: t.accentLight, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            offset: const Offset(0, 4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _s.isPro ? '✦  PRO ACTIVE' : '✦  Get PRO',
                        style: Craft.label(17, theme: t, color: t.beamDeep),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _ModeCard(theme: t),
                  const SizedBox(height: 14),
                  _DifficultyCard(theme: t),
                  const SizedBox(height: 14),
                  if (_s.gameMode == 3 || _s.gameMode == 4)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _PartyCard(theme: t),
                    ),
                  _StyleCard(theme: t),
                  const SizedBox(height: 14),
                  _ProfileCard(theme: t),
                  const SizedBox(height: 14),
                  _SupportCard(theme: t, store: _store),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MenuIcon(
                        theme: t,
                        icon: Icons.share,
                        label: 'Share',
                        onTap: () async {
                          widget.audio.click();
                          // ignore: deprecated_member_use
                          await Share.share(
                              'Stack with me in Tower Stack! https://play.google.com/store/apps/details?id=com.gameswajiha.towerstack');
                        },
                      ),
                      const SizedBox(width: 22),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.star_rate,
                        label: 'Rate',
                        onTap: () async {
                          widget.audio.click();
                          await _requestReview();
                        },
                      ),
                      const SizedBox(width: 22),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.settings,
                        label: 'Settings',
                        onTap: () async {
                          widget.audio.click();
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              audio: widget.audio,
                              settings: _s,
                            ),
                          ));
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(width: 26),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.help_outline,
                        label: 'How to Play',
                        onTap: () {
                          widget.audio.click();
                          _showHowTo(context, t);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_s.gamesPlayed > 0)
                    Text(
                      'Games: ${_s.gamesPlayed}   •   Perfects: ${_s.perfects}   •   Best climb: ${_s.bestClassic}',
                      style: Craft.label(12, theme: t),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/wajiha_logo.png',
                          width: 22, height: 22, fit: BoxFit.contain),
                      const SizedBox(width: 8),
                      Text('Credits: WAJIHA',
                          style: Craft.label(12, theme: t)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHowTo(BuildContext context, TowerThemeDef t) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
                colors: [t.beamMid, t.beamDeep],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            border: Border.all(color: t.accent, width: 3),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('How to Play', style: Craft.display(24, theme: t)),
                const SizedBox(height: 12),
                for (final line in [
                  '• A block swings on the crane — tap to drop it.',
                  '• Line it up over the tower: overhang gets sliced off.',
                  '• A total miss topples your tower. Game over!',
                  '• Land it perfectly to keep full width and build a combo.',
                  '• Zen mode never trims blocks — pure flow.',
                  '• 60-Second Blitz: misses just reset your tower.',
                  '• Pass & Play: one tower each, last builder standing wins.',
                  '• Vs Bot: take turns against the crane bot.',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(line, style: Craft.body(14, theme: t)),
                  ),
                const SizedBox(height: 16),
                Center(
                  child: TimberButton(
                    label: 'Got it!',
                    width: 180,
                    fontSize: 16,
                    theme: t,
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _MenuIcon extends StatelessWidget {
  final TowerThemeDef theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuIcon(
      {required this.theme,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.beamMid, theme.beamDeep],
              ),
              border: Border.all(color: theme.accent, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: theme.accentLight, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: Craft.label(12, theme: theme)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Game mode picker: 5 modes.
class _ModeCard extends StatelessWidget {
  final TowerThemeDef theme;
  const _ModeCard({required this.theme});

  static const icons = ['🗼', '⏱', '🧘', '👥', '🤖'];

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    return _Card(
      theme: theme,
      title: 'Game Mode',
      child: Column(
        children: [
          for (int i = 0; i < GameModes.ids.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _Chip(
                theme: theme,
                label: '${icons[i]}  ${GameModes.names[i]}',
                sub: GameModes.descriptions[i],
                selected: s.gameMode == i,
                onTap: () {
                  audio.click();
                  s.setGameMode(i);
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Difficulty tiers: Chill / Classic / Turbo / Master (PRO).
class _DifficultyCard extends StatelessWidget {
  final TowerThemeDef theme;
  const _DifficultyCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    return _Card(
      theme: theme,
      title: 'Crane Speed',
      child: Column(
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              for (int d = 0; d < Difficulties.names.length; d++)
                _Chip(
                  theme: theme,
                  label:
                      '${Difficulties.isPro(d) && !s.isPro ? '🔒 ' : ''}${Difficulties.names[d]}',
                  sub: Difficulties.descriptions[d],
                  selected: s.difficulty == d,
                  onTap: () {
                    audio.click();
                    if (Difficulties.isPro(d) && !s.isPro) {
                      screen._goPro();
                      return;
                    }
                    s.setDifficulty(d);
                  },
                ),
            ],
          ),
          if (s.gameMode == 4)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Bot skill matches crane speed: ${Difficulties.names[s.difficulty.clamp(0, 2)]}',
                style: Craft.body(13,
                    theme: theme,
                    color: theme.ivory.withValues(alpha: 0.7)),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Pass-and-play / versus setup: player count + per-seat human/bot.
class _PartyCard extends StatelessWidget {
  final TowerThemeDef theme;
  const _PartyCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    final isVersus = s.gameMode == 4;
    return _Card(
      theme: theme,
      title: isVersus ? 'Bot Match' : 'Pass & Play',
      child: Column(
        children: [
          if (!isVersus)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Builders:', style: Craft.body(15, theme: theme)),
                const SizedBox(width: 12),
                for (final c in [2, 3, 4])
                  _Chip(
                    theme: theme,
                    label: '$c',
                    selected: s.playerCount == c,
                    onTap: () {
                      audio.click();
                      final bots = s.botSeats.where((b) => b < c).toList();
                      s.setSetup(players: c, botSeats: bots);
                    },
                  ),
              ],
            ),
          if (!isVersus) const SizedBox(height: 12),
          for (int i = 0; i < (isVersus ? 1 : s.playerCount); i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: _NameField(
                      theme: theme,
                      initial: s.playerNames[i],
                      hint: 'Builder ${i + 1}',
                      onDone: (v) => s.setPassPlayName(i, v),
                      onEdit: (v) => s.setPassPlayNameRaw(i, v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!isVersus) ...[
                    _Chip(
                      theme: theme,
                      label: 'Human',
                      selected: !s.botSeats.contains(i),
                      onTap: () {
                        audio.click();
                        final bots = [...s.botSeats]..remove(i);
                        s.setSetup(
                            players: s.playerCount, botSeats: bots);
                      },
                    ),
                    const SizedBox(width: 6),
                    _Chip(
                      theme: theme,
                      label: 'Bot',
                      selected: s.botSeats.contains(i),
                      onTap: () {
                        audio.click();
                        final bots = {...s.botSeats, i}.toList();
                        s.setSetup(
                            players: s.playerCount, botSeats: bots);
                      },
                    ),
                  ],
                ],
              ),
            ),
          if (isVersus)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'You and the Crane Bot take turns stacking — miss and you\'re out!',
                style: Craft.body(13,
                    theme: theme,
                    color: theme.ivory.withValues(alpha: 0.7)),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Block style + theme picker.
class _StyleCard extends StatelessWidget {
  final TowerThemeDef theme;
  const _StyleCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    final isPro = s.isPro;
    return _Card(
      theme: theme,
      title: 'Yard Style',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Block material:', style: Craft.body(15, theme: theme)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (int i = 0; i < BlockStyles.names.length; i++)
                _Chip(
                  theme: theme,
                  label:
                      '${BlockStyles.isPro(i) && !isPro ? '🔒 ' : ''}${BlockStyles.names[i]}',
                  selected: s.blockStyle == i,
                  onTap: () {
                    audio.click();
                    if (BlockStyles.isPro(i) && !isPro) {
                      screen._goPro();
                      return;
                    }
                    s.setBlockStyle(i);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Sky theme:', style: Craft.body(15, theme: theme)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final th in TowerThemes.all)
                _ThemeTile(
                  theme: theme,
                  th: th,
                  selected: s.themeId == th.id,
                  locked: TowerThemes.isProTheme(th.id) && !isPro,
                  onTap: () {
                    audio.click();
                    if (TowerThemes.isProTheme(th.id) && !isPro) {
                      screen._goPro();
                      return;
                    }
                    s.setTheme(th.id);
                  },
                ),
              _ThemeTile(
                theme: theme,
                th: s.customTheme,
                selected: s.themeId == 'custom',
                locked: !isPro,
                custom: true,
                onTap: () {
                  audio.click();
                  if (!isPro) {
                    screen._goPro();
                    return;
                  }
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CustomThemeScreen(
                      audio: audio,
                      settings: s,
                    ),
                  ));
                },
              ),
            ],
          ),
          if (!isPro)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '🔒 ${TowerThemes.all.length - TowerThemes.freeThemeIds.length} more skies in PRO',
                style: Craft.label(12, theme: theme),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final TowerThemeDef theme;
  final TowerThemeDef th;
  final bool selected;
  final bool locked;
  final bool custom;
  final VoidCallback onTap;
  const _ThemeTile({
    required this.theme,
    required this.th,
    required this.selected,
    required this.locked,
    required this.onTap,
    this.custom = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 96,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                  colors: [th.skyTop, th.skyBottom],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter),
              border: Border.all(
                color: selected
                    ? th.accentLight
                    : th.accent.withValues(alpha: 0.35),
                width: selected ? 3 : 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 18,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: th.beamMid,
                    border: Border.all(color: th.accentLight, width: 1),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  custom ? '🎨 My Yard' : th.name,
                  style: Craft.label(10, theme: th),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (locked)
            Container(
              width: 96,
              height: 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.black.withValues(alpha: 0.55),
              ),
              child:
                  Icon(Icons.lock, color: theme.accentLight, size: 22),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Renameable profile.
class _ProfileCard extends StatelessWidget {
  final TowerThemeDef theme;
  const _ProfileCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    return _Card(
      theme: theme,
      title: 'Your Builder',
      child: Column(
        children: [
          _NameField(
            theme: theme,
            initial: s.playerName,
            hint: 'Builder name',
            onDone: (v) => s.setPlayerName(v),
            onEdit: (v) => s.setPlayerNameRaw(v),
          ),
          const SizedBox(height: 8),
          Text(
            'Your name rides every tower — and the winner podium.',
            style: Craft.body(12,
                theme: theme,
                color: theme.ivory.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NameField extends StatefulWidget {
  final TowerThemeDef theme;
  final String initial;
  final String hint;

  /// Commit: cleaning save (focus loss / keyboard done).
  final ValueChanged<String> onDone;

  /// Every keystroke: raw save, no cleaning.
  final ValueChanged<String> onEdit;

  const _NameField(
      {required this.theme,
      required this.initial,
      required this.hint,
      required this.onDone,
      required this.onEdit});

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _c;
  late final FocusNode _f;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
    _f = FocusNode();
    // Commit on focus loss — the name the user walks away with is the
    // name that sticks (cleaned, never empty).
    _f.addListener(() {
      if (!_f.hasFocus) widget.onDone(_c.text);
    });
  }

  @override
  void didUpdateWidget(covariant _NameField old) {
    super.didUpdateWidget(old);
    if (old.initial != widget.initial && _c.text != widget.initial) {
      _c.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _f.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(color: widget.theme.accent.withValues(alpha: 0.5)),
      ),
      child: TextField(
        controller: _c,
        focusNode: _f,
        style: Craft.body(15, theme: widget.theme),
        maxLength: 14,
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,
          hintText: widget.hint,
          hintStyle: Craft.body(14,
              theme: widget.theme,
              color: widget.theme.ivory.withValues(alpha: 0.4)),
        ),
        onChanged: widget.onEdit, // save on EVERY keystroke
        onSubmitted: widget.onDone,
        onEditingComplete: () => widget.onDone(_c.text),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Tip jar (IAP).
class _SupportCard extends StatelessWidget {
  final TowerThemeDef theme;
  final StoreService store;
  const _SupportCard({required this.theme, required this.store});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final audio = screen.widget.audio;
    return _Card(
      theme: theme,
      title: 'Support Wajiha',
      child: Column(
        children: [
          Text(
            'Tower Stack is 100% free. If it made you smile, a small tip keeps the yard running!',
            style: Craft.body(14, theme: theme),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Builder(builder: (_) {
            final tips = [
              store.coffeeProduct,
              store.chocolateProduct,
            ].whereType<ProductDetails>().toList();
            if (!store.storeReady) {
              return Text(
                store.error ?? 'Loading…',
                style: Craft.body(13,
                    theme: theme,
                    color: theme.ivory.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
              );
            }
            if (tips.isEmpty) {
              return Text('Tips coming soon.',
                  style: Craft.body(13,
                      theme: theme,
                      color: theme.ivory.withValues(alpha: 0.6)));
            }
            return Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final p in tips)
                  _Chip(
                    theme: theme,
                    label: p.id == StoreService.chocolateId
                        ? '🍫 ${p.price}'
                        : '☕ ${p.price}',
                    selected: false,
                    onTap: () {
                      audio.click();
                      store.buyTip(p);
                    },
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _Card extends StatelessWidget {
  final TowerThemeDef theme;
  final String title;
  final Widget child;
  const _Card(
      {required this.theme, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.beamMid.withValues(alpha: 0.85),
            theme.beamDeep.withValues(alpha: 0.9),
          ],
        ),
        border: Border.all(color: theme.accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(0, 5),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(title, style: Craft.display(20, theme: theme)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final TowerThemeDef theme;
  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.theme,
      required this.label,
      this.sub,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? theme.accent.withValues(alpha: 0.85)
              : Colors.black.withValues(alpha: 0.3),
          border: Border.all(
            color: selected
                ? theme.accentLight
                : theme.accent.withValues(alpha: 0.5),
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Craft.label(13,
                  theme: theme,
                  color: selected ? theme.beamDeep : theme.ivory),
              textAlign: TextAlign.center,
            ),
            if (sub != null)
              Text(
                sub!,
                style: Craft.body(11,
                    theme: theme,
                    color: (selected ? theme.beamDeep : theme.ivory)
                        .withValues(alpha: 0.75)),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
