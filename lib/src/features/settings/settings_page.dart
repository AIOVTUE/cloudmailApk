import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/theme_config.dart';
import '../../core/theme/theme_tokens.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _primaryController = TextEditingController();
  final _secondaryController = TextEditingController();
  final _tertiaryController = TextEditingController();

  @override
  void dispose() {
    _primaryController.dispose();
    _secondaryController.dispose();
    _tertiaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(themeConfigProvider);
    final notifier = ref.read(themeConfigProvider.notifier);
    final palette = config.resolvePalette();
    _primaryController.text = _toHex(config.customPrimary ?? palette.primary);
    _secondaryController.text = _toHex(config.customSecondary ?? palette.secondary);
    _tertiaryController.text = _toHex(config.customTertiary ?? palette.tertiary);
    return Scaffold(
      appBar: AppBar(title: const Text('主题外观设置')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          DropdownButtonFormField<ThemeMode>(
            initialValue: config.themeMode,
            decoration: const InputDecoration(labelText: '主题模式'),
            items: const [
              DropdownMenuItem(value: ThemeMode.system, child: Text('跟随系统')),
              DropdownMenuItem(value: ThemeMode.light, child: Text('浅色')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('深色')),
            ],
            onChanged: (mode) {
              if (mode != null) notifier.updateThemeMode(mode);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<AppThemePreset>(
            initialValue: config.preset,
            decoration: const InputDecoration(labelText: '主题预设'),
            items: AppThemePreset.values
                .map((e) => DropdownMenuItem<AppThemePreset>(value: e, child: Text(e.label)))
                .toList(),
            onChanged: (preset) {
              if (preset != null) notifier.updatePreset(preset);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            value: config.useCustomPalette,
            title: const Text('启用自定义配色'),
            subtitle: const Text('可覆盖 primary / secondary / tertiary'),
            onChanged: (value) => notifier.updateCustomPalette(enable: value),
          ),
          if (config.useCustomPalette) ...[
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _primaryController,
              decoration: const InputDecoration(labelText: 'Primary 色值（#RRGGBB）'),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _secondaryController,
              decoration: const InputDecoration(labelText: 'Secondary 色值（#RRGGBB）'),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _tertiaryController,
              decoration: const InputDecoration(labelText: 'Tertiary 色值（#RRGGBB）'),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final p = _parseHex(_primaryController.text);
                final s = _parseHex(_secondaryController.text);
                final t = _parseHex(_tertiaryController.text);
                if (p == null || s == null || t == null) {
                  messenger.showSnackBar(const SnackBar(content: Text('色值格式错误，请使用 #RRGGBB')));
                  return;
                }
                await notifier.updateCustomPalette(enable: true, primary: p, secondary: s, tertiary: t);
                if (!mounted) return;
                messenger.showSnackBar(const SnackBar(content: Text('自定义配色已应用')));
              },
              child: const Text('应用自定义配色'),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _ThemePreviewCard(palette: config.resolvePalette()),
        ],
      ),
    );
  }

  String _toHex(Color color) {
    final hex = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
    return '#$hex';
  }

  Color? _parseHex(String input) {
    final raw = input.trim().replaceAll('#', '');
    if (raw.length != 6) return null;
    final intValue = int.tryParse(raw, radix: 16);
    if (intValue == null) return null;
    return Color(0xFF000000 | intValue);
  }
}

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({required this.palette});

  final ThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('配色预览'),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _SwatchChip(name: 'Primary', color: palette.primary),
                _SwatchChip(name: 'Secondary', color: palette.secondary),
                _SwatchChip(name: 'Tertiary', color: palette.tertiary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SwatchChip extends StatelessWidget {
  const _SwatchChip({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 96, minHeight: AppSizes.minTapTarget),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: color),
      ),
      child: Text(name, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
