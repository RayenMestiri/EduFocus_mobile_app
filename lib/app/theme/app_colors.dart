import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// EduFocus Design System — semantic palettes
///
/// Two hand-tuned palettes share one semantic vocabulary:
///  · DARK  — deep-space canvas, electric-violet accent (original identity).
///  · LIGHT — warm porcelain canvas, ink typography, calmer violet. Designed
///    from scratch (not inverted): soft off-whites, lavender-tinted borders,
///    desaturated semantic colors comfortable for long study sessions.
///
/// Widgets read colors through [AppColors] (static bridge, theme-aware) or
/// through the [AppPalette] ThemeExtension for lerp-animated transitions.
/// ═══════════════════════════════════════════════════════════════════════════

@immutable
class AppPaletteData {
  const AppPaletteData({
    required this.brightness,
    required this.bg,
    required this.bgMesh,
    required this.surface,
    required this.surfaceGlass,
    required this.surfaceSecondary,
    required this.surfaceHover,
    required this.card,
    required this.border,
    required this.borderBright,
    required this.divider,
    required this.shadow,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentHover,
    required this.accentBright,
    required this.accentText,
    required this.accentDeep,
    required this.indigo,
    required this.green,
    required this.yellow,
    required this.red,
    required this.blue,
    required this.cyan,
    required this.heroGradient,
  });

  final Brightness brightness;

  // Canvas layers
  final Color bg;
  final Color bgMesh;
  final Color surface;
  final Color surfaceGlass;
  final Color surfaceSecondary;
  final Color surfaceHover;
  final Color card;

  // Strokes
  final Color border;
  final Color borderBright;
  final Color divider;
  final Color shadow;

  // Typography
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // Brand accent (violet family)
  final Color accent;
  final Color accentHover;
  final Color accentBright;
  final Color accentText;
  final Color accentDeep;
  final Color indigo;

  // Semantic
  final Color green;
  final Color yellow;
  final Color red;
  final Color blue;
  final Color cyan;

  final LinearGradient heroGradient;

  bool get isLight => brightness == Brightness.light;

  // ── DARK — deep space, jewel accents (original EduFocus identity) ──
  static const dark = AppPaletteData(
    brightness: Brightness.dark,
    bg: Color(0xFF04040A),
    bgMesh: Color(0xFF07071A),
    surface: Color(0xFF0D0D1A),
    surfaceGlass: Color(0xE6121224),
    surfaceSecondary: Color(0xFF0F0F1E),
    surfaceHover: Color(0xFF16162A),
    card: Color(0xFF10101F),
    border: Color(0x1A8B5CF6),
    borderBright: Color(0x338B5CF6),
    divider: Color(0x148B5CF6),
    shadow: Color(0x99000000),
    textPrimary: Color(0xFFF0F0FF),
    textSecondary: Color(0xFF9898C0),
    textMuted: Color(0xFF4E4E74),
    accent: Color(0xFF8B5CF6),
    accentHover: Color(0xFF7C3AED),
    accentBright: Color(0xFFA78BFA),
    accentText: Color(0xFFC4B5FD),
    accentDeep: Color(0xFF6D28D9),
    indigo: Color(0xFF6366F1),
    green: Color(0xFF34D399),
    yellow: Color(0xFFFBBF24),
    red: Color(0xFFF87171),
    blue: Color(0xFF60A5FA),
    cyan: Color(0xFF22D3EE),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF6366F1)],
    ),
  );

  // ── LIGHT — porcelain & ink, calm violet (designed, not inverted) ──
  static const light = AppPaletteData(
    brightness: Brightness.light,
    bg: Color(0xFFF7F7FB), // soft lavender-tinted porcelain, never pure white
    bgMesh: Color(0xFFF1F1F8),
    surface: Color(0xFFFFFFFF),
    surfaceGlass: Color(0xD9FFFFFF), // frosted white for glass cards
    surfaceSecondary: Color(0xFFF1F2F8),
    surfaceHover: Color(0xFFE9EAF3),
    card: Color(0xFFFFFFFF),
    border: Color(0x1F6D28D9), // lavender hairline
    borderBright: Color(0x336D28D9),
    divider: Color(0xFFE9E9F2),
    shadow: Color(0x14171724), // very soft ink shadow
    textPrimary: Color(0xFF17172B), // ink, not pure black
    textSecondary: Color(0xFF585C7B),
    textMuted: Color(0xFF9295B0),
    accent: Color(0xFF7C3AED),
    accentHover: Color(0xFF6D28D9),
    accentBright: Color(0xFF8B5CF6),
    accentText: Color(0xFF6D28D9), // readable violet on white
    accentDeep: Color(0xFF5B21B6),
    indigo: Color(0xFF4F46E5),
    green: Color(0xFF059669),
    yellow: Color(0xFFD97706),
    red: Color(0xFFDC2626),
    blue: Color(0xFF2563EB),
    cyan: Color(0xFF0891B2),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6), Color(0xFF6366F1)],
    ),
  );

  AppPaletteData lerpTo(AppPaletteData other, double t) {
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPaletteData(
      brightness: t < .5 ? brightness : other.brightness,
      bg: c(bg, other.bg),
      bgMesh: c(bgMesh, other.bgMesh),
      surface: c(surface, other.surface),
      surfaceGlass: c(surfaceGlass, other.surfaceGlass),
      surfaceSecondary: c(surfaceSecondary, other.surfaceSecondary),
      surfaceHover: c(surfaceHover, other.surfaceHover),
      card: c(card, other.card),
      border: c(border, other.border),
      borderBright: c(borderBright, other.borderBright),
      divider: c(divider, other.divider),
      shadow: c(shadow, other.shadow),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textMuted: c(textMuted, other.textMuted),
      accent: c(accent, other.accent),
      accentHover: c(accentHover, other.accentHover),
      accentBright: c(accentBright, other.accentBright),
      accentText: c(accentText, other.accentText),
      accentDeep: c(accentDeep, other.accentDeep),
      indigo: c(indigo, other.indigo),
      green: c(green, other.green),
      yellow: c(yellow, other.yellow),
      red: c(red, other.red),
      blue: c(blue, other.blue),
      cyan: c(cyan, other.cyan),
      heroGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          c(heroGradient.colors[0], other.heroGradient.colors[0]),
          c(heroGradient.colors[1], other.heroGradient.colors[1]),
          c(heroGradient.colors[2], other.heroGradient.colors[2]),
        ],
      ),
    );
  }
}

/// Theme-aware static bridge.
///
/// Every widget in the app reads `AppColors.x`; the active palette is swapped
/// by [AppColors.setPalette] (called by the theme controller before the
/// MaterialApp rebuilds), so the whole tree repaints with the right colors.
abstract final class AppColors {
  static AppPaletteData _current = AppPaletteData.dark;

  static AppPaletteData get palette => _current;
  static bool get isLight => _current.isLight;

  static void setPalette(AppPaletteData palette) => _current = palette;

  static Color get bg => _current.bg;
  static Color get bgMesh => _current.bgMesh;
  static Color get surface => _current.surface;
  static Color get surfaceGlass => _current.surfaceGlass;
  static Color get surfaceSecondary => _current.surfaceSecondary;
  static Color get surfaceHover => _current.surfaceHover;
  static Color get card => _current.card;

  static Color get border => _current.border;
  static Color get borderBright => _current.borderBright;
  static Color get divider => _current.divider;
  static Color get shadow => _current.shadow;

  static Color get textPrimary => _current.textPrimary;
  static Color get textSecondary => _current.textSecondary;
  static Color get textMuted => _current.textMuted;

  static Color get accent => _current.accent;
  static Color get accentHover => _current.accentHover;
  static Color get accentBright => _current.accentBright;
  static Color get accentText => _current.accentText;
  static Color get accentDeep => _current.accentDeep;
  static Color get indigo => _current.indigo;

  static Color get green => _current.green;
  static Color get yellow => _current.yellow;
  static Color get red => _current.red;
  static Color get blue => _current.blue;
  static Color get cyan => _current.cyan;

  static LinearGradient get heroGradient => _current.heroGradient;
}

/// ThemeExtension wrapper — lets widgets opt into lerp-animated theme colors
/// via `Theme.of(context).extension<AppPalette>()!` (or `context.palette`).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette(this.data);

  final AppPaletteData data;

  @override
  AppPalette copyWith({AppPaletteData? data}) => AppPalette(data ?? this.data);

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(data.lerpTo(other.data, t));
  }
}

extension AppPaletteContext on BuildContext {
  AppPaletteData get palette =>
      Theme.of(this).extension<AppPalette>()?.data ?? AppColors.palette;
}
