import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Material 3 themes for EduFocus, built from the semantic palettes.
///
/// Both modes share one construction path so spacing, radii and typography
/// stay identical — only the palette changes. The light theme is tuned like
/// a Craft/Notion canvas: porcelain background, white floating cards with
/// soft ink shadows, lavender hairlines, calm violet primary.
abstract final class AppTheme {
  static ThemeData get dark => _build(AppPaletteData.dark);
  static ThemeData get light => _build(AppPaletteData.light);

  static ThemeData _build(AppPaletteData p) {
    final isLight = p.isLight;

    final scheme = ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: p.brightness,
      primary: p.accent,
      secondary: p.indigo,
      error: p.red,
      surface: p.surface,
    );

    final baseText = isLight ? ThemeData.light() : ThemeData.dark();
    final textTheme = GoogleFonts.interTextTheme(
      baseText.textTheme,
    ).apply(bodyColor: p.textPrimary, displayColor: p.textPrimary);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      extensions: [AppPalette(p)],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: p.textPrimary,
        iconTheme: IconThemeData(color: p.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: isLight ? p.card : p.surfaceGlass,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.border),
        ),
        margin: EdgeInsets.zero,
        shadowColor: p.shadow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceSecondary,
        hintStyle: TextStyle(color: p.textMuted),
        labelStyle: TextStyle(color: p.textSecondary),
        prefixIconColor: p.textMuted,
        suffixIconColor: p.textMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: inputBorder(p.border),
        enabledBorder: inputBorder(p.border),
        focusedBorder: inputBorder(p.accent, 1.5),
        errorBorder: inputBorder(p.red),
        focusedErrorBorder: inputBorder(p.red, 1.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textSecondary,
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.accentText),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // Dark toast on light canvas (Craft-style), soft surface on dark.
        backgroundColor: isLight ? const Color(0xFF232332) : p.surfaceHover,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: p.divider, thickness: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.surfaceHover,
        circularTrackColor: p.surfaceHover,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: p.border),
        ),
        titleTextStyle: GoogleFonts.inter(
          color: p.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isLight ? p.surface : p.surfaceHover,
        surfaceTintColor: Colors.transparent,
        elevation: isLight ? 8 : 4,
        shadowColor: p.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: p.border),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: p.textMuted, width: 1.6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? Colors.white : p.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.surfaceHover,
        ),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
      ),
      sliderTheme: SliderThemeData(
        inactiveTrackColor: p.surfaceHover,
        overlayColor: p.accent.withValues(alpha: .12),
      ),
      iconTheme: IconThemeData(color: p.textSecondary),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceSecondary,
        side: BorderSide(color: p.border),
        labelStyle: TextStyle(color: p.textSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: Colors.white,
        elevation: isLight ? 6 : 8,
      ),
    );
  }
}
