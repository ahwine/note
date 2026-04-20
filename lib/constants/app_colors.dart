import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color primary = Color(0xFFFFC107);
  static const Color primaryDark = Color(0xFFFFB300);

  // Background
  static const Color bgDark = Color(0xFF121212);
  static const Color bgDark2 = Color(0xFF1E1E1E);
  static const Color bgDark3 = Color(0xFF2C2C2C);
  static const Color bgLight = Color(0xFFF5F5F5);
  static const Color bgLight2 = Color(0xFFFFFFFF);
  static const Color bgLight3 = Color(0xFFEEEEEE);

  // Text
  static const Color textDark = Color(0xFFFFFFFF);
  static const Color textDarkSecondary = Color(0xFF9E9E9E);
  static const Color textLight = Color(0xFF121212);
  static const Color textLightSecondary = Color(0xFF757575);

  // Note Label Colors (8 pilihan)
  static const List<Color> noteColors = [
    Color(0xFF1E1E1E), // default (dark)
    Color(0xFFD32F2F), // red
    Color(0xFFE64A19), // deep orange
    Color(0xFFF9A825), // amber
    Color(0xFF388E3C), // green
    Color(0xFF1565C0), // blue
    Color(0xFF6A1B9A), // purple
    Color(0xFF00838F), // teal
  ];

  // Folder icon colors
  static const Color folderYellow = Color(0xFFFFC107);
  static const Color folderPink = Color(0xFFE91E63);
  static const Color folderBlue = Color(0xFF2196F3);
  static const Color folderGreen = Color(0xFF4CAF50);

  // Helper — ambil warna berdasarkan brightness
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
}