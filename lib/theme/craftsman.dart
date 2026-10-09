import 'package:flutter/material.dart';
import 'tower_themes.dart';

/// Craftsman UI kit for Tower Stack.
/// Warm construction-yard feel: timber, rope and canvas. No neon, no
/// cyberpunk, no generic Material look.
///
/// All widgets accept an optional [TowerThemeDef]; they default to the
/// Sunrise Yard theme so existing call sites keep working.
class Craft {
  static const displayFont = 'serif';

  static TextStyle display(double size,
          {Color? color, TowerThemeDef? theme}) =>
      TextStyle(
        fontFamily: displayFont,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? theme?.accentLight ?? const Color(0xFFF2D38A),
        letterSpacing: 1.2,
        shadows: const [
          Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 4),
        ],
      );

  static TextStyle body(double size, {Color? color, TowerThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? theme?.ivory ?? const Color(0xFFF7EFE0),
        height: 1.35,
      );

  static TextStyle label(double size, {Color? color, TowerThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? theme?.accentLight ?? const Color(0xFFF2D38A),
        letterSpacing: 0.8,
      );

  static ThemeData theme([TowerThemeDef? t]) {
    t ??= TowerThemes.byId('sunrise');
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: t.beamDark,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: t.accent,
        onPrimary: t.beamDeep,
        secondary: t.accentLight,
        onSecondary: t.beamDeep,
        surface: t.beamMid,
        onSurface: t.ivory,
        error: const Color(0xFFC0392B),
        onError: t.ivory,
      ),
      textTheme: TextTheme(
        displayLarge: display(34, theme: t),
        displayMedium: display(26, theme: t),
        titleLarge: display(22, theme: t),
        bodyLarge: body(16, theme: t),
        bodyMedium: body(14, theme: t),
        labelLarge: label(14, theme: t),
      ),
      dialogTheme: DialogThemeData(backgroundColor: t.beamMid),
    );
  }
}

/// Timber backdrop: wood-grain with a warm sky-wash at the top.
class TimberBackdrop extends StatelessWidget {
  final Widget child;
  final TowerThemeDef? theme;
  const TimberBackdrop({super.key, required this.child, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? TowerThemes.byId('sunrise');
    return Container(
      decoration: BoxDecoration(color: t.beamDark),
      child: CustomPaint(
        painter: _TimberPainter(t),
        child: child,
      ),
    );
  }
}

class _TimberPainter extends CustomPainter {
  final TowerThemeDef t;
  _TimberPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Sky wash at the top of menus.
    final wash = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.center,
      colors: [
        t.skyBottom.withValues(alpha: 0.28),
        t.skyBottom.withValues(alpha: 0.0),
      ],
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = wash.createShader(Offset.zero & size));
    final vignette = RadialGradient(
      center: const Alignment(0, -0.25),
      radius: 1.15,
      colors: [
        t.beamMid.withValues(alpha: 0.45),
        t.beamDark.withValues(alpha: 0.0),
        Colors.black.withValues(alpha: 0.5),
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = vignette.createShader(Offset.zero & size),
    );
    // Plank seams.
    final seam = Paint()
      ..color = t.beamDeep.withValues(alpha: 0.22)
      ..strokeWidth = 2.5;
    for (int i = 0; i < 12; i++) {
      final y = size.height * (i + 0.5) / 12;
      canvas.drawLine(Offset(0, y), Offset(size.width, y + (i % 2) * 6), seam);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A chunky timber button with rope trim — looks physically pressable.
class TimberButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double width;
  final double fontSize;
  final TowerThemeDef? theme;

  const TimberButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width = 240,
    this.fontSize = 19,
    this.theme,
  });

  @override
  State<TimberButton> createState() => _TimberButtonState();
}

class _TimberButtonState extends State<TimberButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? TowerThemes.byId('sunrise');
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: widget.width,
        padding: const EdgeInsets.symmetric(vertical: 15),
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: enabled
                ? [t.beamMid, t.beamDark, t.beamDeep]
                : [
                    t.beamDeep.withValues(alpha: 0.7),
                    t.beamDeep.withValues(alpha: 0.5)
                  ],
          ),
          border: Border.all(color: t.accent, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: t.accentLight.withValues(alpha: _pressed ? 0.05 : 0.22),
              offset: const Offset(0, -2),
              blurRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              offset: Offset(0, _pressed ? 2 : 6),
              blurRadius: _pressed ? 4 : 10,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: Craft.display(widget.fontSize,
              theme: t,
              color: enabled ? t.ivory : t.ivory.withValues(alpha: 0.45)),
        ),
      ),
    );
  }
}

/// A riveted steel plaque for titles.
class SteelPlaque extends StatelessWidget {
  final String title;
  final String? subtitle;
  final TowerThemeDef? theme;
  const SteelPlaque(
      {super.key, required this.title, this.subtitle, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? TowerThemes.byId('sunrise');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.beamDeep, t.beamDark],
        ),
        border: Border.all(color: t.accent, width: 3),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              offset: const Offset(0, 6),
              blurRadius: 12),
          BoxShadow(
              color: t.accentLight.withValues(alpha: 0.5),
              offset: const Offset(0, -1),
              blurRadius: 1),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: Craft.display(30, theme: t), textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: Craft.body(14,
                    theme: t, color: t.ivory.withValues(alpha: 0.75)),
                textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

/// A rope-pull toggle for settings.
class CraftToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final TowerThemeDef? theme;
  const CraftToggle(
      {super.key, required this.value, required this.onChanged, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? TowerThemes.byId('sunrise');
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 64,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          color: value ? t.accentDark : t.beamDeep,
          border: Border.all(color: t.accent, width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(0, 3),
                blurRadius: 5),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.accentLight, t.accent, t.accentDark],
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(0, 2),
                    blurRadius: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A wooden-bead volume slider on a steel rail.
class BeadSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final TowerThemeDef? theme;
  const BeadSlider(
      {super.key, required this.value, required this.onChanged, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? TowerThemes.byId('sunrise');
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 6,
        activeTrackColor: t.accent,
        inactiveTrackColor: t.beamDeep,
        thumbShape: _BeadThumb(t),
        overlayShape: SliderComponentShape.noOverlay,
      ),
      child: Slider(value: value, onChanged: onChanged),
    );
  }
}

class _BeadThumb extends SliderComponentShape {
  final TowerThemeDef t;
  const _BeadThumb(this.t);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(26, 26);

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final canvas = context.canvas;
    canvas.drawCircle(
        center + const Offset(0, 2),
        12,
        Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawCircle(
        center,
        11,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.5),
            radius: 1.0,
            colors: [t.accentLight, t.accent, t.accentDark],
          ).createShader(Rect.fromCircle(center: center, radius: 11)));
  }
}

/// Small helper: a labeled settings row.
class SettingRow extends StatelessWidget {
  final String label;
  final Widget control;
  final TowerThemeDef? theme;
  const SettingRow(
      {super.key, required this.label, required this.control, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? TowerThemes.byId('sunrise');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: t.beamDeep.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.accent.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Craft.body(16, theme: t))),
          control,
        ],
      ),
    );
  }
}
