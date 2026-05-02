import 'package:flutter/material.dart';

enum AppThemePreset { defaultBlue, purplePink, darkPro, eyeCareGreen, oceanBlue }

class ThemePalette {
  const ThemePalette({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.background,
    required this.surface,
    required this.accent,
    required this.error,
    required this.warning,
    required this.success,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color background;
  final Color surface;
  final Color accent;
  final Color error;
  final Color warning;
  final Color success;
}

class ThemeConfig {
  const ThemeConfig({
    this.themeMode = ThemeMode.system,
    this.preset = AppThemePreset.defaultBlue,
    this.useCustomPalette = false,
    this.customPrimary,
    this.customSecondary,
    this.customTertiary,
  });

  final ThemeMode themeMode;
  final AppThemePreset preset;
  final bool useCustomPalette;
  final Color? customPrimary;
  final Color? customSecondary;
  final Color? customTertiary;

  ThemeConfig copyWith({
    ThemeMode? themeMode,
    AppThemePreset? preset,
    bool? useCustomPalette,
    Color? customPrimary,
    Color? customSecondary,
    Color? customTertiary,
  }) {
    return ThemeConfig(
      themeMode: themeMode ?? this.themeMode,
      preset: preset ?? this.preset,
      useCustomPalette: useCustomPalette ?? this.useCustomPalette,
      customPrimary: customPrimary ?? this.customPrimary,
      customSecondary: customSecondary ?? this.customSecondary,
      customTertiary: customTertiary ?? this.customTertiary,
    );
  }

  ThemePalette resolvePalette() {
    final base = preset.palette;
    if (!useCustomPalette) return base;
    return ThemePalette(
      primary: customPrimary ?? base.primary,
      secondary: customSecondary ?? base.secondary,
      tertiary: customTertiary ?? base.tertiary,
      background: base.background,
      surface: base.surface,
      accent: base.accent,
      error: base.error,
      warning: base.warning,
      success: base.success,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.name,
      'preset': preset.name,
      'useCustomPalette': useCustomPalette,
      'customPrimary': customPrimary?.toARGB32(),
      'customSecondary': customSecondary?.toARGB32(),
      'customTertiary': customTertiary?.toARGB32(),
    };
  }

  static ThemeConfig fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ThemeConfig();
    return ThemeConfig(
      themeMode: _parseThemeMode(json['themeMode']?.toString()),
      preset: _parsePreset(json['preset']?.toString()),
      useCustomPalette: json['useCustomPalette'] == true,
      customPrimary: _parseColor(json['customPrimary']),
      customSecondary: _parseColor(json['customSecondary']),
      customTertiary: _parseColor(json['customTertiary']),
    );
  }

  static ThemeMode _parseThemeMode(String? raw) {
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static AppThemePreset _parsePreset(String? raw) {
    for (final value in AppThemePreset.values) {
      if (value.name == raw) return value;
    }
    return AppThemePreset.defaultBlue;
  }

  static Color? _parseColor(dynamic raw) {
    if (raw is int) return Color(raw);
    if (raw is String) {
      final value = int.tryParse(raw);
      if (value != null) return Color(value);
    }
    return null;
  }
}

extension AppThemePresetX on AppThemePreset {
  String get label => switch (this) {
        AppThemePreset.defaultBlue => 'Default Blue',
        AppThemePreset.purplePink => 'Purple Pink',
        AppThemePreset.darkPro => 'Dark Pro',
        AppThemePreset.eyeCareGreen => 'Eye Care Green',
        AppThemePreset.oceanBlue => 'Ocean Blue',
      };

  ThemePalette get palette => switch (this) {
        AppThemePreset.defaultBlue => const ThemePalette(
            primary: Color(0xFF4A90E2),
            secondary: Color(0xFF50E3C2),
            tertiary: Color(0xFF6F8CFF),
            background: Color(0xFFF5F8FC),
            surface: Color(0xFFFFFFFF),
            accent: Color(0xFF2F6FE4),
            error: Color(0xFFDC2626),
            warning: Color(0xFFF59E0B),
            success: Color(0xFF16A34A),
          ),
        AppThemePreset.purplePink => const ThemePalette(
            primary: Color(0xFF8E2DE2),
            secondary: Color(0xFFFF6FD8),
            tertiary: Color(0xFFB564F7),
            background: Color(0xFFF9F6FF),
            surface: Color(0xFFFFFFFF),
            accent: Color(0xFF7C3AED),
            error: Color(0xFFDC2626),
            warning: Color(0xFFF59E0B),
            success: Color(0xFF16A34A),
          ),
        AppThemePreset.darkPro => const ThemePalette(
            primary: Color(0xFF1DA1F2),
            secondary: Color(0xFF0F1419),
            tertiary: Color(0xFF36CFC9),
            background: Color(0xFF0B0F14),
            surface: Color(0xFF121821),
            accent: Color(0xFF4CC9F0),
            error: Color(0xFFF87171),
            warning: Color(0xFFFBBF24),
            success: Color(0xFF34D399),
          ),
        AppThemePreset.eyeCareGreen => const ThemePalette(
            primary: Color(0xFF2ECC71),
            secondary: Color(0xFF27AE60),
            tertiary: Color(0xFF6EDFA2),
            background: Color(0xFFF3FBF5),
            surface: Color(0xFFFFFFFF),
            accent: Color(0xFF1F9D55),
            error: Color(0xFFDC2626),
            warning: Color(0xFFF59E0B),
            success: Color(0xFF16A34A),
          ),
        AppThemePreset.oceanBlue => const ThemePalette(
            primary: Color(0xFF2563EB),
            secondary: Color(0xFF0EA5E9),
            tertiary: Color(0xFF14B8A6),
            background: Color(0xFFF2F8FF),
            surface: Color(0xFFFFFFFF),
            accent: Color(0xFF3B82F6),
            error: Color(0xFFDC2626),
            warning: Color(0xFFF59E0B),
            success: Color(0xFF16A34A),
          ),
      };
}

