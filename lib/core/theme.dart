import 'package:flutter/material.dart';

/// 新光云设计基线：主色采用方案一（深海军蓝 + 暖金），
/// Agent 头像带采用方案二（日出珊瑚橙 → 紫罗兰渐变）。
class XgColors {
  static const navy = Color(0xFF0F2A5F);
  static const navyDark = Color(0xFF081B40);
  static const navyLight = Color(0xFF1E3F7F);
  static const gold = Color(0xFFF5B942);
  static const goldDark = Color(0xFFD99A1E);
  static const bg = Color(0xFFF4F6FA);
  static const card = Colors.white;
  static const textPrimary = Color(0xFF14213D);
  static const textSecondary = Color(0xFF6B7280);
  static const divider = Color(0xFFE5E7EB);
  static const success = Color(0xFF1F8A70);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF2563EB);

  // 方案二渐变（Agent 头像带 / 光芒值卡片）
  static const coral = Color(0xFFFF7A59);
  static const violet = Color(0xFF7C3AED);
  static const sunrise = LinearGradient(
    colors: [coral, Color(0xFFE0559A), violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const navyGradient = LinearGradient(
    colors: [navyDark, navy, navyLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<Color> agentGradient(int index) {
    const pairs = [
      [Color(0xFFFF7A59), Color(0xFFFF4D8D)],
      [Color(0xFF7C3AED), Color(0xFFA855F7)],
      [Color(0xFF0EA5E9), Color(0xFF2563EB)],
      [Color(0xFFF59E0B), Color(0xFFF97316)],
      [Color(0xFF10B981), Color(0xFF059669)],
      [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      [Color(0xFFEC4899), Color(0xFFDB2777)],
      [Color(0xFF14B8A6), Color(0xFF0D9488)],
    ];
    return pairs[index % pairs.length];
  }
}

ThemeData buildXgTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: XgColors.navy,
    primary: XgColors.navy,
    secondary: XgColors.gold,
    surface: XgColors.card,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: XgColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: XgColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: XgColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: XgColors.divider),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: XgColors.bg,
      side: BorderSide.none,
      labelStyle: const TextStyle(fontSize: 12, color: XgColors.textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: XgColors.navy,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: XgColors.navy,
        side: const BorderSide(color: XgColors.navy),
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: XgColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: XgColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: XgColors.navy, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: XgColors.navy.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: s.contains(WidgetState.selected)
              ? XgColors.navy
              : XgColors.textSecondary,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? XgColors.navy
              : XgColors.textSecondary,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: XgColors.divider, space: 1),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w700,
        color: XgColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.w700,
        color: XgColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w600,
        color: XgColors.textPrimary,
      ),
      bodyMedium: TextStyle(color: XgColors.textPrimary),
      bodySmall: TextStyle(color: XgColors.textSecondary),
    ),
  );
}
