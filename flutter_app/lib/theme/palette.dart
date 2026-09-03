import 'package:flutter/material.dart';

/// Central design system for PRAssist — every color used in the app
/// lives here so light/dark themes and glow effects stay consistent.
class AppPalette {
  AppPalette._();

  // ---- Brand ----
  static const Color primary = Color(0xFF6C5CE7); // indigo
  static const Color primaryDeep = Color(0xFF4F46E5);
  static const Color secondary = Color(0xFF3AB0FF); // sky
  static const Color accent = Color(0xFF8B5CF6); // violet
  static const Color accentPink = Color(0xFFF472B6);

  /// Signature brand gradient used on the logo & primary buttons.
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Secondary cyan→violet gradient for hero / highlights.
  static const LinearGradient heroGradient = LinearGradient(
    colors: [primaryDeep, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ---- Verdicts ----
  static const Color green = Color(0xFF10B981); // emerald
  static const Color yellow = Color(0xFFF59E0B); // amber
  static const Color red = Color(0xFFF43F5E); // rose

  static Color verdictColor(String? verdict) {
    switch ((verdict ?? '').toUpperCase()) {
      case 'GREEN':
        return green;
      case 'YELLOW':
        return yellow;
      case 'RED':
        return red;
      default:
        return secondary;
    }
  }

  static IconData verdictIcon(String? verdict) {
    switch ((verdict ?? '').toUpperCase()) {
      case 'GREEN':
        return Icons.check_circle_rounded;
      case 'YELLOW':
        return Icons.warning_amber_rounded;
      case 'RED':
        return Icons.cancel_rounded;
      default:
        return Icons.radio_button_unchecked_rounded;
    }
  }

  static String verdictLabel(String? verdict) {
    switch ((verdict ?? '').toUpperCase()) {
      case 'GREEN':
        return 'Ready to merge';
      case 'YELLOW':
        return 'Needs changes';
      case 'RED':
        return 'Block merge';
      default:
        return 'Needs review';
    }
  }

  // ---- Surfaces (dark) ----
  static const Color darkBg = Color(0xFF070B14);
  static const Color darkCard = Color(0xFF0F1524);
  static const Color darkCardAlt = Color(0xFF141B31);
  static const Color darkBorder = Color(0x12FFFFFF);

  // ---- Surfaces (light) ----
  static const Color lightBg = Color(0xFFF3F4FB);
  static const Color lightCard = Colors.white;

  /// Card surface color respecting the current brightness.
  static Color cardOf(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return light ? lightCard : darkCard;
  }

  /// Card surface color without a BuildContext (theme-building friendly).
  static Color cardOf2(bool isLight) => isLight ? lightCard : darkCard;

  /// Subtle elevated surface color.
  static Color cardAltOf(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return light ? const Color(0xFFF6F7FD) : darkCardAlt;
  }

  /// Background color respecting the current brightness.
  static Color bgOf(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return light ? lightBg : darkBg;
  }

  /// Border color that adapts to brightness.
  static Color borderOf(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return light ? const Color(0xFFE7E9F4) : darkBorder;
  }

  /// Secondary text color without a BuildContext.
  static Color textSecondaryOf(bool isLight) =>
      isLight ? const Color(0xFF6B7280) : const Color(0xFF9AA3B8);

  static Color textPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF171A26)
        : const Color(0xFFEDF0F8);
  }

  static Color textSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF6B7280)
        : const Color(0xFF9AA3B8);
  }

  /// Soft multi-stop background used behind hero cards.
  static LinearGradient glowGradient(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return LinearGradient(
      colors: light
          ? const [Color(0xFFFFFFFF), Color(0xFFF0F2FF)]
          : const [Color(0xFF121A33), Color(0xFF0D1326)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }
}