import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';

class EmailDropdownMenu extends StatefulWidget {
  const EmailDropdownMenu({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onSelect,
    this.width = 260,
  });

  final List<EmailMenuItem> items;
  final int? selectedValue;
  final ValueChanged<int> onSelect;
  final double width;

  @override
  State<EmailDropdownMenu> createState() => _EmailDropdownMenuState();
}

class _EmailDropdownMenuState extends State<EmailDropdownMenu> with SingleTickerProviderStateMixin {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  AnimationController? _controller;
  Animation<double>? _opacity;
  Animation<double>? _scale;

  @override
  void initState() {
    super.initState();
    final controller = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
      reverseDuration: AppMotion.fast,
    );
    _controller = controller;
    _opacity = CurvedAnimation(parent: controller, curve: AppMotion.curve);
    _scale = Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(parent: controller, curve: AppMotion.curve));
  }

  @override
  void dispose() {
    _remove(immediate: true);
    _controller?.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_entry != null) {
      _remove();
    } else {
      _show();
    }
  }

  void _show() {
    final overlay = Overlay.of(context);

    _entry = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final bg = theme.brightness == Brightness.dark
            ? const Color(0xFF1C1C1E)
            : colors.surface;
        final divider = theme.brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.10) : colors.outlineVariant;

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _remove,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 8),
              child: Material(
                color: Colors.transparent,
                child: FadeTransition(
                  opacity: _opacity!,
                  child: ScaleTransition(
                    scale: _scale!,
                    alignment: Alignment.topRight,
                    child: Container(
                      width: widget.width.clamp(220, 280),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.45 : 0.12),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(color: divider.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...widget.items.map((it) {
                            final selected = it.value == widget.selectedValue;
                            return _MenuRow(
                              height: 46,
                              label: it.label,
                              leading: selected ? const Icon(Icons.check_rounded, size: 18) : null,
                              selected: selected,
                              onTap: () {
                                _remove();
                                widget.onSelect(it.value);
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_entry!);
    _controller?.forward(from: 0);
  }

  Future<void> _remove({bool immediate = false}) async {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    if (!immediate) {
      await _controller?.reverse();
    }
    entry.remove();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: IconButton(
        tooltip: '切换邮箱',
        onPressed: _toggle,
        icon: const Icon(Icons.more_horiz_rounded),
      ),
    );
  }
}

class EmailMenuItem {
  const EmailMenuItem({required this.value, required this.label});
  final int value;
  final String label;
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.height,
    required this.label,
    required this.onTap,
    this.leading,
    this.selected = false,
  });

  final double height;
  final String label;
  final VoidCallback onTap;
  final Widget? leading;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bg = selected ? colors.primaryContainer.withValues(alpha: 0.35) : Colors.transparent;
    final fg = colors.onSurface;
    return SizedBox(
      height: height,
      child: InkWell(
        onTap: onTap,
        splashFactory: InkSparkle.splashFactory,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: bg,
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

