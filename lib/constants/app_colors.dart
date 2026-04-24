import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFFFC107);
  static const Color primaryDark = Color(0xFFFFB300);
  static const Color primaryContainer = Color(0xFFFFE082);
  static const Color onPrimaryContainer = Color(0xFF2B1D00);

  static const Color bgDark = Color(0xFF0F1113);
  static const Color bgDark2 = Color(0xFF171A1D);
  static const Color bgDark3 = Color(0xFF1F2428);

  static const Color bgLight = Color(0xFFFFF8F1);
  static const Color bgLight2 = Color(0xFFFFFBF7);
  static const Color bgLight3 = Color(0xFFF7EEDF);

  static const Color textDark = Colors.white;
  static const Color textDarkSecondary = Color(0xFFB0B7BF);
  static const Color textLight = Color(0xFF1E1B16);
  static const Color textLightSecondary = Color(0xFF6C6357);

  static const Color success = Color(0xFF2E7D32);
  static const Color error = Color(0xFFD32F2F);

  static const Color outline = Color(0x22000000);
  static const Color outlineDark = Color(0x22FFFFFF);

  static const Color folderYellow = Color(0xFFFFC107);
  static const Color folderPink = Color(0xFFE91E63);
  static const Color folderBlue = Color(0xFF2196F3);
  static const Color folderGreen = Color(0xFF4CAF50);

  static const List<Color> noteColors = [
    Color(0xFF171A1D),
    Color(0xFFFFF8E1),
    Color(0xFFFFF3E0),
    Color(0xFFE8F5E9),
    Color(0xFFE3F2FD),
    Color(0xFFF3E5F5),
    Color(0xFFFFEBEE),
    Color(0xFFE0F7FA),
  ];

  static Color bg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? bgDark : bgLight;

  static Color bg2(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? bgDark2 : bgLight2;

  static Color bg3(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? bgDark3 : bgLight3;

  static Color text(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? textDark : textLight;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? textDarkSecondary
          : textLightSecondary;

  static Color surface(BuildContext context) => bg2(context);

  static Color surfaceVariant(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF24292E)
          : const Color(0xFFF2E6D5);

  static Color outlineColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? outlineDark : outline;
}
