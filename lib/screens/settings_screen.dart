import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/craftsman.dart';
import '../theme/tower_themes.dart';

/// Settings: builder name, music/SFX toggles, volume.
class SettingsScreen extends StatefulWidget {
  final TowerAudio audio;
  final TowerSettings settings;

  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TowerThemeDef get _t => TowerThemes.byId(widget.settings.themeId,
      custom: widget.settings.customTheme);
  late final TextEditingController _name;
  late final FocusNode _nameFocus;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.settings.playerName);
    _nameFocus = FocusNode();
    // Commit on focus loss — the name the user walks away with sticks.
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) widget.settings.setPlayerName(_name.text);
    });
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final a = widget.audio;
    return TimberBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.accentLight),
            onPressed: () {
              a.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Settings', style: Craft.display(22, theme: t)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: Column(
                children: [
                  SettingRow(
                    label: 'Builder name',
                    theme: t,
                    control: SizedBox(
                      width: 150,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.black.withValues(alpha: 0.3),
                          border: Border.all(
                              color: t.accent.withValues(alpha: 0.5)),
                        ),
                        child: TextField(
                          controller: _name,
                          focusNode: _nameFocus,
                          style: Craft.body(15, theme: t),
                          maxLength: 14,
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                          ),
                          // Save on EVERY keystroke (raw); commit on focus
                          // loss or keyboard done.
                          onChanged: (v) => s.setPlayerNameRaw(v),
                          onSubmitted: (v) {
                            a.click();
                            s.setPlayerName(v);
                          },
                          onEditingComplete: () =>
                              s.setPlayerName(_name.text),
                        ),
                      ),
                    ),
                  ),
                  SettingRow(
                    label: 'Music',
                    theme: t,
                    control: CraftToggle(
                      value: s.musicOn,
                      theme: t,
                      onChanged: (v) {
                        a.click();
                        s.setMusic(v);
                        a.configure(
                            musicOn: v, sfxOn: s.sfxOn, volume: s.volume);
                        if (v) {
                          a.startMenuMusic();
                        }
                      },
                    ),
                  ),
                  SettingRow(
                    label: 'Sound effects',
                    theme: t,
                    control: CraftToggle(
                      value: s.sfxOn,
                      theme: t,
                      onChanged: (v) {
                        s.setSfx(v);
                        a.configure(
                            musicOn: s.musicOn, sfxOn: v, volume: s.volume);
                        if (v) a.click();
                      },
                    ),
                  ),
                  SettingRow(
                    label: 'Volume',
                    theme: t,
                    control: SizedBox(
                      width: 170,
                      child: BeadSlider(
                        value: s.volume,
                        theme: t,
                        onChanged: (v) {
                          s.setVolume(v);
                          a.configure(
                              musicOn: s.musicOn,
                              sfxOn: s.sfxOn,
                              volume: v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: t.beamDeep.withValues(alpha: 0.65),
                      border: Border.all(
                          color: t.accent.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        Text('Yard records',
                            style: Craft.display(18, theme: t)),
                        const SizedBox(height: 10),
                        _row(t, 'Best classic climb', '${s.bestClassic}'),
                        _row(t, 'Best 60-sec blitz', '${s.bestBlitz}'),
                        _row(t, 'Best zen tower', '${s.bestZen}'),
                        _row(t, 'Games played', '${s.gamesPlayed}'),
                        _row(t, 'Perfect drops', '${s.perfects}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(TowerThemeDef t, String k, String v) => Padding(
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
