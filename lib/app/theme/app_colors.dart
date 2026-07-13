import 'package:flutter/material.dart';

/// EduFocus design tokens.
///
/// Mirrors the CSS custom properties of the Angular dashboard
/// (frontend/src/app/components/dashboard/dashboard.component.css) so both
/// clients share one visual language: deep-space backgrounds, electric-violet
/// accent, jewel-tone semantics.
abstract final class AppColors {
  // ── Backgrounds (dark) ──
  static const bg = Color(0xFF04040A);
  static const bgMesh = Color(0xFF07071A);
  static const surface = Color(0xFF0D0D1A);
  static const surfaceGlass = Color(0xE6121224);
  static const surfaceSecondary = Color(0xFF0F0F1E);
  static const surfaceHover = Color(0xFF16162A);

  // ── Typography (dark) ──
  static const textPrimary = Color(0xFFF0F0FF);
  static const textSecondary = Color(0xFF9898C0);
  static const textMuted = Color(0xFF4E4E74);

  // ── Accent: electric violet ──
  static const accent = Color(0xFF8B5CF6);
  static const accentHover = Color(0xFF7C3AED);
  static const accentBright = Color(0xFFA78BFA);
  static const accentText = Color(0xFFC4B5FD);
  static const accentDeep = Color(0xFF6D28D9);
  static const indigo = Color(0xFF6366F1);

  // ── Semantic ──
  static const green = Color(0xFF34D399);
  static const yellow = Color(0xFFFBBF24);
  static const red = Color(0xFFF87171);
  static const blue = Color(0xFF60A5FA);
  static const cyan = Color(0xFF22D3EE);

  // ── Borders ──
  static const border = Color(0x1A8B5CF6);
  static const borderBright = Color(0x338B5CF6);

  /// Hero gradient used across the Angular dashboard hero and hub cards.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentDeep, accentHover, indigo],
  );
}
