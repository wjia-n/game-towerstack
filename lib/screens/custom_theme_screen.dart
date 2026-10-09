import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/craftsman.dart';
import '../theme/tower_themes.dart';

/// PRO: custom yard creator — pick sky, ground, timber and accent colors,
/// plus the block hue progression. Live preview, persisted per color.
class CustomThemeScreen extends StatefulWidget {
  final TowerAudio audio;
  final TowerSettings settings;

  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  TowerThemeDef get _t => TowerThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  // Curated yard-friendly palette choices.
  static const List<Color> palette = [
    Color(0xFF7FB3D5), Color(0xFF5AA7DE), Color(0xFF101B33),
    Color(0xFF6B4E8E), Color(0xFFF2A56B), Color(0xFFF6D8A8),
    Color(0xFF9FC3DE), Color(0xFFEAF4FB), Color(0xFF5C6E82),
    Color(0xFF8A6B4A), Color(0xFF5C4630), Color(0xFF3A2A1E),
    Color(0xFFD9B87A), Color(0xFFB98A94), Color(0xFF6B7A44),
    Color(0xFF4A3220), Color(0xFF6B4A2E), Color(0xFF2E1E12),
    Color(0xFF1C2438), Color(0xFF2C3A55), Color(0xFF3E4C5C),
    Color(0xFFD9A441), Color(0xFFF2D38A), Color(0xFF96691F),
    Color(0xFFC66A2B), Color(0xFFEEA968), Color(0xFFB87333),
    Color(0xFFC0C6D4), Color(0xFFE8ECF5), Color(0xFF7E8698),
    Color(0xFFF7EFE0), Color(0xFFFFF6E6), Color(0xFF2E2118),
    Color(0xFFD94F70), Color(0xFF7FB069), Color(0xFFD99A2B),
    Color(0xFFA31621), Color(0xFF1D4E9E), Color(0xFF1B7A4D),
  ];

  static const rows = [
    ('Sky top', 'skyTop'),
    ('Sky bottom', 'skyBottom'),
    ('Ground', 'ground'),
    ('Ground dark', 'groundDark'),
    ('Timber dark', 'beamDark'),
    ('Timber mid', 'beamMid'),
    ('Timber deep', 'beamDeep'),
    ('Accent rope', 'accent'),
    ('Accent light', 'accentLight'),
    ('Accent dark', 'accentDark'),
    ('Ivory text', 'ivory'),
  ];

  Future<void> _pick(String key, String label) async {
    final s = widget.settings;
    final current = Color(s.customColors[key]!);
    final chosen = await showDialog<Color>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [
              _t.beamMid,
              _t.beamDeep,
            ]),
            border: Border.all(color: _t.accent, width: 2.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pick $label', style: Craft.display(20, theme: _t)),
              const SizedBox(height: 14),
              SizedBox(
                width: 300,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: palette.length,
                  itemBuilder: (_, i) {
                    final c = palette[i];
                    final selected = c.value == current.value;
                    return GestureDetector(
                      onTap: () {
                        widget.audio.click();
                        Navigator.of(context).pop(c);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c,
                          border: Border.all(
                            color: selected
                                ? _t.accentLight
                                : Colors.black.withValues(alpha: 0.4),
                            width: selected ? 3 : 1.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              TimberButton(
                label: 'Cancel',
                width: 160,
                fontSize: 15,
                theme: _t,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null && mounted) {
      widget.audio.click();
      await s.setCustomColor(key, chosen.value);
      // Selecting a custom color auto-applies the custom theme.
      await s.setTheme('custom');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final preview = s.customTheme;
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
              widget.audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Yard Creator', style: Craft.display(22, theme: t)),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: () async {
                widget.audio.click();
                await s.resetCustomColors();
                if (mounted) setState(() {});
              },
              child: Text('Reset', style: Craft.label(13, theme: t)),
            ),
          ],
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: Column(
                children: [
                  // Live preview strip.
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(colors: [
                        preview.skyTop,
                        preview.skyBottom,
                      ]),
                      border:
                          Border.all(color: preview.accent, width: 2),
                    ),
                    child: Column(
                      children: [
                        Text('Live preview',
                            style: Craft.label(13, theme: preview)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (int i = 0; i < 4; i++)
                              Container(
                                width: 52,
                                height: 30,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  color: HSLColor.fromAHSL(
                                          1,
                                          (preview.hueStart +
                                                  i * preview.hueStep) %
                                              360,
                                          0.55,
                                          0.55)
                                      .toColor(),
                                  border: Border.all(
                                      color: preview.accentLight, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.5),
                                      offset: const Offset(0, 3),
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 26,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: preview.ground,
                            border: Border.all(
                                color: preview.accent.withValues(alpha: 0.6)),
                          ),
                          alignment: Alignment.center,
                          child: Text('Ground sample',
                              style: Craft.label(11, theme: preview)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final r in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: GestureDetector(
                        onTap: () => _pick(r.$2, r.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: t.beamDeep.withValues(alpha: 0.6),
                            border: Border.all(
                                color: t.accent.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(s.customColors[r.$2]!),
                                  border: Border.all(
                                      color: t.accentLight, width: 1.5),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(r.$1,
                                    style: Craft.body(15, theme: t)),
                              ),
                              Icon(Icons.palette,
                                  color: t.accentLight, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  SettingRow(
                    label: 'Block hue start',
                    theme: t,
                    control: SizedBox(
                      width: 150,
                      child: Slider(
                        value: s.customHueStart,
                        min: 0,
                        max: 360,
                        onChanged: (v) => s.setCustomHue(v, s.customHueStep),
                      ),
                    ),
                  ),
                  SettingRow(
                    label: 'Hue shift / block',
                    theme: t,
                    control: SizedBox(
                      width: 150,
                      child: Slider(
                        value: s.customHueStep,
                        min: -30,
                        max: 30,
                        onChanged: (v) => s.setCustomHue(s.customHueStart, v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TimberButton(
                    label: 'Use This Yard',
                    width: 260,
                    theme: t,
                    onTap: () async {
                      widget.audio.click();
                      await s.setTheme('custom');
                      if (mounted) Navigator.of(context).pop();
                    },
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
}
