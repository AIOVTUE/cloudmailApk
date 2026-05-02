import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/parser.dart' as html_parser;

import '../../core/auth/admin_guard.dart';
import '../../core/providers.dart';
import '../../core/theme/theme_tokens.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/email_dropdown_menu.dart';
import 'mail_repository.dart';

const int allMailAccountId = -1;
const double _detailTopBarHeight = 46;

final adminAccessProvider = FutureProvider<bool>((ref) async {
  final sessionPerms = ref.read(sessionProvider).permKeys;
  if (hasAdminPerm(sessionPerms)) return true;
  try {
    final response = await ref.read(dioProvider).get('/my/loginUserInfo');
    final info = ref.read(parserProvider).parse<Map<String, dynamic>>(
      response.data as Map<String, dynamic>,
      (d) => d as Map<String, dynamic>,
    );
    final livePerms = ((info['permKeys'] as List?) ?? const []).map((e) => e.toString()).toList();
    ref.read(sessionProvider.notifier).updatePermKeys(livePerms);
    return isAdminFromUserInfo(info);
  } catch (_) {
    return false;
  }
});

final mailAccountListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ref.read(dioProvider).get('/account/list', queryParameters: {'accountId': 0, 'size': 30});
  return ref.read(parserProvider).parse<List<Map<String, dynamic>>>(response.data as Map<String, dynamic>, (d) {
    return ((d as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  });
});

final selectedMailAccountIdProvider = StateProvider<int?>((_) => null);

final accountSwitcherProvider = Provider.family<List<DropdownMenuItem<int>>, bool>((ref, includeAllMail) {
  final accountAsync = ref.watch(mailAccountListProvider);
  final canQueryAllMail = ref.watch(adminAccessProvider).maybeWhen(data: (v) => v, orElse: () => false);
  return accountAsync.maybeWhen(
    data: (accounts) {
      final items = <DropdownMenuItem<int>>[];
      if (includeAllMail && canQueryAllMail) {
        items.add(const DropdownMenuItem<int>(
          value: allMailAccountId,
          child: Text(
            '全部邮件',
            overflow: TextOverflow.ellipsis,
          ),
        ));
      }
      items.addAll(
        accounts.map(
          (e) => DropdownMenuItem<int>(
            value: e['accountId'] as int?,
            child: Text(
              e['email']?.toString() ?? '',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
      return items;
    },
    orElse: () => const [],
  );
});

final mailListProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, int>((ref, type) async {
  final accounts = await ref.watch(mailAccountListProvider.future);
  if (accounts.isEmpty) return const [];
  final selected = ref.watch(selectedMailAccountIdProvider);
  final fallback = (accounts.first['accountId'] as int?) ?? 0;
  final accountId = selected ?? fallback;
  if (selected == null) {
    ref.read(selectedMailAccountIdProvider.notifier).state = accountId;
  }
  final canQueryAllMail = ref.watch(adminAccessProvider).maybeWhen(data: (v) => v, orElse: () => false);
  if (type == 0 && canQueryAllMail && accountId == allMailAccountId) {
    return ref.read(mailRepositoryProvider).fetchAllMailList();
  }
  final safeAccountId = (type == 1 && accountId == allMailAccountId) ? fallback : accountId;
  return ref.read(mailRepositoryProvider).fetchList(accountId: safeAccountId, type: type);
});

final starsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(mailRepositoryProvider).stars();
});

final draftListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final raw = ref.read(storageReadyProvider).draft;
  if (raw == null || raw.isEmpty) return const [];
  try {
    final map = Map<String, dynamic>.from(jsonDecode(raw) as Map<String, dynamic>);
    return [
      {
        'emailId': -1,
        'subject': map['subject']?.toString() ?? '(草稿无主题)',
        'fromEmail': ref.read(sessionProvider).email,
        'text': map['content']?.toString() ?? '',
        'isRead': 1,
        'isStar': 0,
        'type': 2,
      }
    ];
  } catch (_) {
    return const [];
  }
});

Future<bool> _showDeleteConfirmDialog(
  BuildContext context, {
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确认删除', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('删除'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result == true;
}

class _DesktopDragScrollBehavior extends MaterialScrollBehavior {
  const _DesktopDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        ...super.dragDevices,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class MailListPage extends ConsumerStatefulWidget {
  const MailListPage({super.key, required this.inbox});
  final bool inbox;

  @override
  ConsumerState<MailListPage> createState() => _MailListPageState();
}

class _MailListPageState extends ConsumerState<MailListPage> {
  Map<String, dynamic>? _selected;
  final Set<int> _optimisticallyRemovedIds = <int>{};

  @override
  Widget build(BuildContext context) {
    final type = widget.inbox ? 0 : 1;
    final listState = ref.watch(mailListProvider(type));
    return listState.when(
      data: (data) {
        final visible = data.where((e) {
          final id = e['emailId'] as int? ?? 0;
          return id <= 0 ? true : !_optimisticallyRemovedIds.contains(id);
        }).toList();
        if (visible.isEmpty) {
          return const AppEmptyView(message: '暂无邮件');
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            final list = RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(mailListProvider(type));
                await ref.read(mailListProvider(type).future);
              },
              child: ScrollConfiguration(
                behavior: const _DesktopDragScrollBehavior(),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: visible.length,
                  itemBuilder: (_, index) {
                    final item = visible[index];
                    final isSelected = _selected?['emailId'] == item['emailId'];
                    return Dismissible(
                      key: ValueKey('mail-$type-${item['emailId'] ?? index}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                      confirmDismiss: (_) => _confirmDelete(context),
                      onDismissed: (_) async {
                        final id = item['emailId'] as int? ?? 0;
                        if (id > 0) {
                          setState(() => _optimisticallyRemovedIds.add(id));
                        }
                        await _deleteRemoteMail(item, type);
                      },
                      child: _MailListCard(
                        item: item,
                        selected: isSelected,
                        onStar: () async {
                          await ref.read(mailRepositoryProvider).star(item['emailId'] as int? ?? 0, item['isStar'] != 1);
                          ref.invalidate(starsProvider);
                          ref.invalidate(mailListProvider(type));
                        },
                        onTap: () {
                          if (isWide) {
                            setState(() => _selected = item);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => MailDetailPage(item: item, type: type)),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            );
            if (!isWide) return list;
            final preview = _selected ?? data.first;
            return Row(
              children: [
                Expanded(flex: 5, child: list),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 6,
                  child: _MailPreviewPanel(item: preview),
                ),
              ],
            );
          },
        );
      },
      loading: () => const _MailSkeletonList(),
      error: (e, _) => AppErrorView(message: '邮件加载失败：$e', onRetry: () => ref.invalidate(mailListProvider(type))),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return _showDeleteConfirmDialog(
      context,
      message: '确定删除这封邮件吗？',
    );
  }

  Future<void> _deleteRemoteMail(Map<String, dynamic> item, int type) async {
    final id = item['emailId'] as int? ?? 0;
    if (id <= 0) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    try {
      await ref.read(mailRepositoryProvider).deleteEmails([id]);
      if (mounted) {
        setState(() => _optimisticallyRemovedIds.remove(id));
      }
      ref.invalidate(mailListProvider(type));
      ref.invalidate(starsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('邮件已删除')));
    } catch (e) {
      // 有些服务端实现会“删除成功但返回非 2xx/非预期响应”，Dio 会抛错。
      // 这里以刷新后的列表结果为准：如果邮件已不在列表中，则视为删除成功，避免错误提示闪现。
      ref.invalidate(mailListProvider(type));
      ref.invalidate(starsProvider);
      try {
        final refreshed = await ref.read(mailListProvider(type).future);
        final stillExists = refreshed.any((m) => (m['emailId'] as int? ?? 0) == id);
        if (mounted) {
          setState(() {
            if (stillExists) {
              _optimisticallyRemovedIds.remove(id);
            } else {
              _optimisticallyRemovedIds.remove(id);
            }
          });
        }
        messenger.showSnackBar(
          SnackBar(content: Text(stillExists ? '删除失败：$e' : '邮件已删除')),
        );
      } catch (_) {
        if (mounted) {
          setState(() => _optimisticallyRemovedIds.remove(id));
        }
        messenger.showSnackBar(SnackBar(content: Text('删除失败：$e')));
      }
    }
  }
}

class _MailListCard extends StatelessWidget {
  const _MailListCard({
    required this.item,
    required this.onTap,
    required this.onStar,
    required this.selected,
  });

  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback onStar;
  final bool selected;

  bool get _isUnread => (item['isRead'] == 0) || (item['read'] == 0);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final subject = item['subject']?.toString().trim();
    final senderRaw = (item['fromEmail']?.toString() ?? '').trim().isNotEmpty
        ? item['fromEmail']?.toString() ?? ''
        : (item['sendEmail']?.toString() ?? '').trim().isNotEmpty
            ? item['sendEmail']?.toString() ?? ''
            : (item['email']?.toString() ?? item['toEmail']?.toString() ?? '');
    final previewRaw = item['text']?.toString() ?? item['content']?.toString() ?? '';
    final timeText = _formatTime(_tryParseTime(item));
    final initials = _initials(senderRaw);
    final avatarColor = _pastelColorFromString(senderRaw, colors: colors);
    final textPrimary = colors.onSurface;
    final textSecondary = colors.onSurfaceVariant;

    final itemHeight = 68.0; // 64~72
    final horizontalPadding = AppSpacing.md; // 16
    final unreadDot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: colors.primary,
        shape: BoxShape.circle,
      ),
    );

    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: 0.30)
          : _isUnread
              ? colors.primaryContainer.withValues(alpha: 0.12)
              : colors.surface,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          height: itemHeight,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: avatarColor.withValues(alpha: 0.22),
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: avatarColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_isUnread)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: unreadDot,
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      senderRaw.isEmpty ? '(未知发件人)' : senderRaw,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.1,
                        fontWeight: _isUnread ? FontWeight.w600 : FontWeight.w500,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _previewLine(subject: subject, preview: previewRaw),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.1,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeText,
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  const SizedBox(height: 6),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    icon: Icon((item['isStar'] == 1) ? Icons.star : Icons.star_border),
                    color: (item['isStar'] == 1) ? colors.tertiary : textSecondary,
                    onPressed: onStar,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MailSkeletonList extends StatelessWidget {
  const _MailSkeletonList();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    return ListView.builder(
      itemCount: 8,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemBuilder: (_, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: base,
          ),
        ),
      ),
    );
  }
}

String _previewLine({required String? subject, required String preview}) {
  final s = (subject ?? '').trim();
  final p = preview.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.isNotEmpty && p.isNotEmpty) return '$s · $p';
  if (s.isNotEmpty) return s;
  return p.isEmpty ? '(无内容)' : p;
}

DateTime? _tryParseTime(Map<String, dynamic> item) {
  final candidates = [
    item['createTime'],
    item['sendTime'],
    item['time'],
    item['date'],
  ];
  for (final c in candidates) {
    final raw = c?.toString().trim();
    if (raw == null || raw.isEmpty) continue;
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
  }
  return null;
}

String _formatTime(DateTime? time) {
  if (time == null) return '';
  final now = DateTime.now();
  final sameDay = now.year == time.year && now.month == time.month && now.day == time.day;
  if (sameDay) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  final y = time.year.toString().padLeft(4, '0');
  final m = time.month.toString().padLeft(2, '0');
  final d = time.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String _initials(String emailOrName) {
  final trimmed = emailOrName.trim();
  if (trimmed.isEmpty) return '?';
  final base = trimmed.contains('@') ? trimmed.split('@').first : trimmed;
  final letter = base.isEmpty ? trimmed : base;
  final first = letter.substring(0, 1).toUpperCase();
  final isLetter = RegExp(r'[A-Z]').hasMatch(first);
  final isDigit = RegExp(r'[0-9]').hasMatch(first);
  if (isLetter || isDigit) return first;
  return '#';
}

Color _pastelColorFromString(String input, {required ColorScheme colors}) {
  final seed = input.isEmpty ? 'cloudmail' : input;
  var hash = 0;
  for (final codeUnit in seed.codeUnits) {
    hash = 0x1fffffff & (hash + codeUnit);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    hash ^= (hash >> 6);
  }
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash ^= (hash >> 11);
  hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  final hue = (hash % 360).toDouble();
  final hsl = HSLColor.fromAHSL(1, hue, 0.55, 0.52);
  final base = hsl.toColor();
  // 略向主题色靠拢，保证在暗黑模式也不突兀
  return Color.lerp(base, colors.primary, 0.12) ?? base;
}

class _MailPreviewPanel extends StatelessWidget {
  const _MailPreviewPanel({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final subject = item['subject']?.toString() ?? '(无主题)';
    final from = item['fromEmail']?.toString() ?? item['sendEmail']?.toString() ?? '';
    final to = item['toEmail']?.toString() ?? '';
    final content = item['content']?.toString() ?? item['text']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subject, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text('发件人: $from'),
              Text('收件人: $to'),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    content.isEmpty ? '请选择一封邮件查看详情（双栏预览模式）' : content,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InboxAccountSwitcherInline extends ConsumerWidget {
  const InboxAccountSwitcherInline({super.key, this.width = 220, this.includeAllMail = false});
  final double width;
  final bool includeAllMail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(mailAccountListProvider);
    final selectedAccountId = ref.watch(selectedMailAccountIdProvider);
    return SizedBox(
      width: width,
      child: accountState.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return const Text('暂无邮箱', style: TextStyle(fontSize: 12));
          }
          final canQueryAllMail = ref.watch(adminAccessProvider).maybeWhen(data: (v) => v, orElse: () => false);
          final fallback = (accounts.first['accountId'] as int?);
          final base = selectedAccountId ?? ((includeAllMail && canQueryAllMail) ? allMailAccountId : fallback);
          final current = (!includeAllMail && base == allMailAccountId) ? fallback : base;
          final menuItems = <EmailMenuItem>[];
          if (includeAllMail && canQueryAllMail) {
            menuItems.add(const EmailMenuItem(value: allMailAccountId, label: '全部邮件'));
          }
          for (final a in accounts) {
            final id = a['accountId'] as int? ?? 0;
            final label = a['email']?.toString() ?? '';
            if (id > 0 && label.isNotEmpty) {
              menuItems.add(EmailMenuItem(value: id, label: label));
            }
          }
          return Align(
            alignment: Alignment.centerRight,
            child: EmailDropdownMenu(
              width: width,
              items: menuItems,
              selectedValue: current,
              onSelect: (value) {
                ref.read(selectedMailAccountIdProvider.notifier).state = value;
                ref.invalidate(mailListProvider(0));
                ref.invalidate(mailListProvider(1));
              },
            ),
          );
        },
        loading: () => const SizedBox(
          height: 28,
          child: Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
        error: (e, _) => const Text('加载失败', style: TextStyle(fontSize: 12)),
      ),
    );
  }
}

class StarPage extends ConsumerWidget {
  const StarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(starsProvider);
    return asyncValue.when(
      data: (data) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(starsProvider);
            await ref.read(starsProvider.future);
          },
          child: ScrollConfiguration(
            behavior: const _DesktopDragScrollBehavior(),
            child: data.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      AppEmptyView(message: '暂无星标邮件'),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: data.length,
                    itemBuilder: (_, index) {
                      final item = data[index];
                      return _MailListCard(
                        item: item,
                        selected: false,
                      onStar: () async {
                        final emailId = item['emailId'] as int? ?? 0;
                        if (emailId <= 0) return;
                        final active = (item['isStar'] as int? ?? 0) == 1;
                        await ref.read(mailRepositoryProvider).star(emailId, !active);
                        ref.invalidate(starsProvider);
                        ref.invalidate(mailListProvider(0));
                        ref.invalidate(mailListProvider(1));
                      },
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MailDetailPage(
                              item: item,
                              type: (item['type'] as int?) ?? 0,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
      loading: () => const _MailSkeletonList(),
      error: (e, _) => AppErrorView(message: '$e', onRetry: () => ref.invalidate(starsProvider)),
    );
  }
}

class DraftPage extends ConsumerWidget {
  const DraftPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(draftListProvider);
    return asyncValue.when(
      data: (data) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(draftListProvider);
            await ref.read(draftListProvider.future);
          },
          child: ScrollConfiguration(
            behavior: const _DesktopDragScrollBehavior(),
            child: data.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      AppEmptyView(message: '暂无草稿'),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: data.length,
                    itemBuilder: (_, index) {
                      final item = data[index];
                      return Dismissible(
                        key: ValueKey('draft-${item['emailId'] ?? index}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                        confirmDismiss: (_) async {
                          return _showDeleteConfirmDialog(
                            context,
                            message: '确定删除这条草稿吗？',
                          );
                        },
                        onDismissed: (_) async {
                          await ref.read(storageReadyProvider).clearDraft();
                          ref.invalidate(draftListProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('草稿已删除')));
                          }
                        },
                        child: _MailListCard(
                          item: item,
                          selected: false,
                          onStar: () {},
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ComposePage()),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
      loading: () => const _MailSkeletonList(),
      error: (e, _) => AppErrorView(message: '草稿加载失败：$e', onRetry: () => ref.invalidate(draftListProvider)),
    );
  }
}

class MailDetailPage extends ConsumerStatefulWidget {
  const MailDetailPage({super.key, required this.item, required this.type});
  final Map<String, dynamic> item;
  final int type;

  @override
  ConsumerState<MailDetailPage> createState() => _MailDetailPageState();
}

class _MailDetailPageState extends ConsumerState<MailDetailPage> {
  late Future<Map<String, dynamic>> _detailFuture;
  late final ScrollController _scrollController;
  bool _showTopBar = true;
  bool _isStarred = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _detailFuture = _loadDetail();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _onDetailScroll(ScrollNotification notification) {
    final shouldShow = notification.metrics.extentBefore <= 0.5;
    if (shouldShow != _showTopBar) {
      setState(() => _showTopBar = shouldShow);
    }
    return false;
  }

  Future<Map<String, dynamic>> _loadDetail() async {
    try {
      final selected = ref.read(selectedMailAccountIdProvider);
      final accountId = selected ?? (widget.item['accountId'] as int? ?? 1);
      final emailId = widget.item['emailId'] as int? ?? 0;
      final fetched = await ref
          .read(mailRepositoryProvider)
          .fetchDetail(
            accountId: accountId,
            type: widget.type,
            emailId: emailId,
          )
          .timeout(const Duration(seconds: 8));
      final result = fetched ?? widget.item;
      _isStarred = (result['isStar'] as int? ?? 0) == 1;
      widget.item['isStar'] = result['isStar'];
      return result;
    } catch (_) {
      // 避免详情页长时间转圈，失败时回退到列表项数据。
      _isStarred = (widget.item['isStar'] as int? ?? 0) == 1;
      return widget.item;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: _showTopBar ? _detailTopBarHeight : 0,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _showTopBar
                      ? EmailAppBar(
                          isStarred: _isStarred,
                          onToggleStar: _toggleStar,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _detailFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('加载失败: ${snapshot.error}'));
                  }
                  final item = snapshot.data ?? widget.item;
                  final body = _extractBody(item);
                  final htmlContent = _prepareHtmlForRender(body.$1);
                  final textContent = body.$2;
                  final sender = _senderName(item);
                  final senderEmail = _senderEmail(item);
                  final toEmail = item['toEmail']?.toString() ?? '';
                  final timeLabel = _formatTime(_tryParseTime(item));
                  final otp = _detectOtpCode(htmlContent, textContent);
                  final isStarred = (item['isStar'] as int? ?? 0) == 1;
                  if (isStarred != _isStarred) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() => _isStarred = isStarred);
                    });
                  }
                  return NotificationListener<ScrollNotification>(
                    onNotification: _onDetailScroll,
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      children: [
                        EmailHeader(title: item['subject']?.toString() ?? '(无主题)'),
                        const SizedBox(height: 12),
                        EmailSenderInfo(
                          senderName: sender,
                          senderEmail: senderEmail,
                          receiverText: toEmail,
                          timeText: timeLabel,
                        ),
                        const SizedBox(height: 14),
                        EmailContent(
                          html: htmlContent,
                          text: textContent,
                          otpCode: otp,
                          onCopyOtp: otp == null
                              ? null
                              : () async {
                                  await Clipboard.setData(ClipboardData(text: otp));
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('验证码已复制')));
                                },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _senderName(Map<String, dynamic> item) {
    final name = item['fromName']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
    return _senderEmail(item);
  }

  String _senderEmail(Map<String, dynamic> item) {
    final from = item['fromEmail']?.toString().trim() ?? '';
    if (from.isNotEmpty) return from;
    final send = item['sendEmail']?.toString().trim() ?? '';
    if (send.isNotEmpty) return send;
    return '未知发件人';
  }

  String? _detectOtpCode(String htmlContent, String textContent) {
    final plain = textContent.trim().isNotEmpty ? textContent : html_parser.parse(htmlContent).body?.text ?? '';
    final match = RegExp(r'(?<!\d)(\d{4,8})(?!\d)').firstMatch(plain);
    return match?.group(1);
  }

  Future<void> _toggleStar() async {
    final current = await _detailFuture;
    final id = current['emailId'] as int? ?? 0;
    if (id <= 0 || !mounted) return;
    final active = (current['isStar'] as int? ?? 0) == 1;
    try {
      await ref.read(mailRepositoryProvider).star(id, !active);
      current['isStar'] = active ? 0 : 1;
      widget.item['isStar'] = current['isStar'];
      _isStarred = (current['isStar'] as int? ?? 0) == 1;
      setState(() {
        _detailFuture = Future.value(current);
      });
      ref.invalidate(starsProvider);
      ref.invalidate(mailListProvider(widget.type));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(active ? '已取消星标' : '已加入星标')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败：$e')));
    }
  }

  // 右上角三点菜单已移除：删除/查看原始邮件入口暂不在详情页提供

  (String, String) _extractBody(Map<String, dynamic> item) {
    final htmlCandidates = [
      item['content'],
      item['html'],
      item['htmlContent'],
      item['bodyHtml'],
      item['messageHtml'],
    ];
    for (final candidate in htmlCandidates) {
      final normalized = _normalizeBody(candidate);
      if (normalized.isNotEmpty) {
        return (normalized, '');
      }
    }

    final textCandidates = [
      item['text'],
      item['body'],
      item['bodyText'],
      item['message'],
      item['rawContent'],
    ];
    for (final candidate in textCandidates) {
      final normalized = _normalizeBody(candidate);
      if (normalized.isEmpty) continue;
      if (_looksLikeHtml(normalized)) {
        return (normalized, '');
      }
      return ('', normalized);
    }
    return ('', '');
  }

  String _prepareHtmlForRender(String html) {
    if (html.trim().isEmpty) return '';
    var value = html;
    // 清理 Outlook 条件注释，避免 flutter_html 在复杂注释块下丢失正文。
    value = value.replaceAll(RegExp(r'<!--\[if[\s\S]*?<!\[endif\]-->', multiLine: true), '');
    final doc = html_parser.parse(value);
    final bodyInner = doc.body?.innerHtml.trim() ?? '';
    final rootInner = doc.documentElement?.innerHtml.trim() ?? '';
    final candidate = bodyInner.isNotEmpty ? bodyInner : rootInner;
    // 移除预览隐藏块（display:none），避免正文顶部出现大量空白。
    return candidate.replaceAll(
      RegExp(r'<div[^>]*display:\s*none[^>]*>[\s\S]*?</div>', caseSensitive: false),
      '',
    );
  }

  String _normalizeBody(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return '';
    final trimmed = raw.trim();
    if (trimmed == 'null' || trimmed == 'undefined') return '';
    if (trimmed.startsWith('"') && trimmed.endsWith('"') && trimmed.length > 1) {
      try {
        final decoded = jsonDecode(trimmed);
        return decoded?.toString().trim() ?? '';
      } catch (_) {
        return trimmed.substring(1, trimmed.length - 1).replaceAll(r'\"', '"').replaceAll(r'\n', '\n');
      }
    }
    if (trimmed.contains(r'\u003c') || trimmed.contains(r'\u003e')) {
      try {
        final decoded = jsonDecode('"${trimmed.replaceAll('"', r'\"')}"');
        return decoded?.toString().trim() ?? trimmed;
      } catch (_) {
        return trimmed.replaceAll(r'\u003c', '<').replaceAll(r'\u003e', '>');
      }
    }
    return trimmed;
  }

  bool _looksLikeHtml(String content) {
    if (content.contains('<html') || content.contains('<body') || content.contains('<div') || content.contains('<p')) {
      return true;
    }
    final doc = html_parser.parse(content);
    final hasElement = doc.body?.children.isNotEmpty ?? false;
    return hasElement;
  }

  // 原始邮件导出能力已从详情页入口移除，如需可在后续加回专用入口。
}

class EmailAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const EmailAppBar({
    super.key,
    required this.isStarred,
    required this.onToggleStar,
  });

  final bool isStarred;
  final Future<void> Function() onToggleStar;

  @override
  Size get preferredSize => const Size.fromHeight(_detailTopBarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      scrolledUnderElevation: 0,
      elevation: 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      leading: IconButton(
        tooltip: '返回',
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      actions: [
        IconButton(
          tooltip: '星标',
          onPressed: onToggleStar,
          icon: Icon(isStarred ? Icons.star_rounded : Icons.star_outline_rounded),
        ),
      ],
    );
  }
}

class EmailHeader extends StatelessWidget {
  const EmailHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
    );
  }
}

class EmailSenderInfo extends StatelessWidget {
  const EmailSenderInfo({
    super.key,
    required this.senderName,
    required this.senderEmail,
    required this.receiverText,
    required this.timeText,
  });

  final String senderName;
  final String senderEmail;
  final String receiverText;
  final String timeText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: _pastelColorFromString(senderName, colors: theme.colorScheme),
          child: Text(
            _initials(senderName),
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                senderName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                senderEmail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (receiverText.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  '收件人：$receiverText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          timeText,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class EmailContent extends StatelessWidget {
  const EmailContent({
    super.key,
    required this.html,
    required this.text,
    this.otpCode,
    this.onCopyOtp,
  });

  final String html;
  final String text;
  final String? otpCode;
  final Future<void> Function()? onCopyOtp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasHtml = html.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (otpCode != null && otpCode!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.password_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '验证码：$otpCode',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: onCopyOtp == null ? null : () => onCopyOtp!.call(),
                  child: const Text('复制'),
                ),
              ],
            ),
          ),
        if (hasHtml)
          _HtmlBodyView(html: html)
        else if (text.trim().isNotEmpty)
          SelectableText(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.75,
              color: theme.colorScheme.onSurface,
            ),
          )
        else
          Text(
            '该邮件没有可展示的正文内容',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _HtmlBodyView extends StatelessWidget {
  const _HtmlBodyView({required this.html});
  final String html;

  String _hex(Color color) {
    final v = color.toARGB32() & 0x00FFFFFF;
    return '#${v.toRadixString(16).padLeft(6, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkColor = _hex(theme.colorScheme.primary);
    return HtmlWidget(
      html,
      textStyle: theme.textTheme.bodyMedium?.copyWith(
        height: 1.75,
        color: theme.colorScheme.onSurface,
      ),
      customStylesBuilder: (element) {
        final tag = element.localName?.toLowerCase();
        if (tag == 'p') return {'margin': '0 0 10px 0'};
        if (tag == 'a') return {'color': linkColor, 'text-decoration': 'underline'};
        if (tag == 'img') return {'max-width': '100%', 'height': 'auto'};
        if (tag == 'pre' || tag == 'code') return {'white-space': 'pre-wrap', 'word-break': 'break-word'};
        return {'word-break': 'break-word'};
      },
      onTapUrl: (_) => false,
    );
  }
}

class ComposePage extends ConsumerStatefulWidget {
  const ComposePage({super.key, this.replyEmailId});
  final int? replyEmailId;

  @override
  ConsumerState<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends ConsumerState<ComposePage> {
  final _toController = TextEditingController();
  final _subjectController = TextEditingController();
  final _contentController = TextEditingController();
  bool _sending = false;
  double _uploadProgress = 0;
  bool _previewMode = false;
  int? _composeAccountId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final draftRaw = ref.read(storageReadyProvider).draft;
      if (draftRaw == null) return;
      final map = Map<String, dynamic>.from(jsonDecode(draftRaw) as Map<String, dynamic>);
      _toController.text = map['to']?.toString() ?? '';
      _subjectController.text = map['subject']?.toString() ?? '';
      _contentController.text = map['content']?.toString() ?? '';
      if (mounted && map.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已恢复本地草稿')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(mailAccountListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('写邮件'),
        actions: [
          TextButton(
            onPressed: _sending ? null : _saveDraft,
            child: const Text('存草稿'),
          ),
          TextButton(
            onPressed: _sending ? null : _send,
            child: _sending ? const Text('发送中...') : const Text('发送'),
          ),
          IconButton(
            tooltip: _previewMode ? '编辑模式' : '预览模式',
            onPressed: () => setState(() => _previewMode = !_previewMode),
            icon: Icon(_previewMode ? Icons.edit : Icons.preview),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          accountAsync.when(
            data: (accounts) {
              if (accounts.isEmpty) {
                return const Text('暂无可用发件邮箱，请先在账户管理中添加。');
              }
              _composeAccountId ??= ref.read(selectedMailAccountIdProvider) ?? (accounts.first['accountId'] as int?);
              final current = _composeAccountId ?? (accounts.first['accountId'] as int? ?? 0);
              final currentEmail = accounts
                      .firstWhere((e) => (e['accountId'] as int? ?? 0) == current, orElse: () => accounts.first)['email']
                      ?.toString() ??
                  '请选择发件邮箱';
              final menuItems = accounts
                  .map((e) => EmailMenuItem(value: e['accountId'] as int? ?? 0, label: e['email']?.toString() ?? ''))
                  .where((e) => e.value > 0 && e.label.isNotEmpty)
                  .toList();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        currentEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    EmailDropdownMenu(
                      width: 260,
                      items: menuItems,
                      selectedValue: current,
                      onSelect: (value) => setState(() => _composeAccountId = value),
                    ),
                  ],
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('加载发件邮箱失败: $e'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _toController, decoration: const InputDecoration(labelText: '收件人，逗号分隔')),
          const SizedBox(height: 12),
          TextField(controller: _subjectController, decoration: const InputDecoration(labelText: '主题')),
          const SizedBox(height: 12),
          if (_previewMode)
            Container(
              constraints: const BoxConstraints(minHeight: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: HtmlWidget(_contentController.text.trim().isEmpty ? '<p>暂无内容</p>' : _contentController.text),
            )
          else
            TextField(
              controller: _contentController,
              minLines: 12,
              maxLines: 24,
              decoration: const InputDecoration(
                labelText: '邮件内容（支持 HTML）',
                alignLabelWithHint: true,
                hintText: '<p>请输入 HTML 或纯文本内容</p>',
              ),
            ),
          if (_sending) LinearProgressIndicator(value: _uploadProgress == 0 ? null : _uploadProgress),
        ],
      ),
    );
  }

  Future<void> _saveDraft() async {
    final html = _contentController.text;
    await ref.read(storageReadyProvider).setDraft({
      'to': _toController.text,
      'subject': _subjectController.text,
      'content': html,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('草稿已保存')));
  }

  Future<void> _send() async {
    final messenger = ScaffoldMessenger.of(context);
    final accountId = _composeAccountId ?? ref.read(selectedMailAccountIdProvider) ?? 0;
    if (accountId <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('请选择发件邮箱')));
      return;
    }
    final receivers = _toController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (receivers.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('请至少填写一个收件人')));
      return;
    }
    setState(() => _sending = true);
    try {
      final html = _contentController.text;
      final result = await ref.read(mailRepositoryProvider).send(
            accountId: accountId,
            receiveEmail: receivers,
            subject: _subjectController.text,
            content: html,
            sendType: widget.replyEmailId == null ? null : 'reply',
            emailId: widget.replyEmailId,
            attachments: const [],
            onSendProgress: (sent, total) {
              if (!mounted || total <= 0) return;
              setState(() => _uploadProgress = sent / total);
            },
          );
      if (result.isEmpty) {
        throw Exception('服务端未返回发送记录，请检查发件权限或参数');
      }
      await ref.read(storageReadyProvider).clearDraft();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('发送成功')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('发送失败: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
