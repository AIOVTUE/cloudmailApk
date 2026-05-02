import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/admin_guard.dart';
import '../../core/providers.dart';
import '../../core/theme/theme_tokens.dart';
import '../../core/widgets/state_views.dart';
import '../admin/admin_pages.dart';
import '../mail/mail_pages.dart';
import 'settings_widgets.dart';

final myInfoProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final response = await ref.read(dioProvider).get('/my/loginUserInfo');
  return ref.read(parserProvider).parse<Map<String, dynamic>>(response.data as Map<String, dynamic>, (d) => d as Map<String, dynamic>);
});

final myAccountsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ref.read(dioProvider).get('/account/list', queryParameters: {'accountId': 0, 'size': 30});
  return ref.read(parserProvider).parse<List<Map<String, dynamic>>>(response.data as Map<String, dynamic>, (d) {
    return ((d as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  });
});

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myInfoProvider);
    return state.when(
      data: (data) {
        final perms = ((data['permKeys'] as List?) ?? const []).map((e) => e.toString()).toSet();
        final isAdmin = isAdminFromUserInfo(data) || hasAdminPerm(perms);
        final themeConfig = ref.watch(themeConfigProvider);
        final selectedAccountId = ref.watch(selectedMailAccountIdProvider);
        final userEmail = data['email']?.toString() ?? '';
        final accountAsync = ref.watch(myAccountsProvider);
        final isDark = themeConfig.themeMode == ThemeMode.dark ||
            (themeConfig.themeMode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const SectionTitle(title: '账号'),
            SettingsGroup(
              children: [
                AccountItem(
                  email: userEmail,
                  subtitle: '当前登录账号',
                  onTap: () => _pushFromRight(context, _AccountSecurityPage(ref: ref, canDeleteAccount: perms.contains('my:delete'))),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionTitle(title: '邮箱选择'),
            accountAsync.when(
              data: (accounts) {
                if (accounts.isEmpty) {
                  return const SettingsGroup(
                    children: [
                      SettingsItem(
                        icon: Icons.mark_email_unread_outlined,
                        title: '暂无邮箱账号',
                        subtitle: '点击上方“添加账号”开始使用',
                        trailing: SizedBox.shrink(),
                      ),
                    ],
                  );
                }
                final fallback = (accounts.first['accountId'] as int?) ?? 0;
                final current = selectedAccountId ?? fallback;
                return SettingsGroup(
                  children: accounts
                      .map(
                        (a) {
                          final accountId = a['accountId'] as int? ?? 0;
                          final selected = accountId == current;
                          return AccountItem(
                            email: a['email']?.toString() ?? '',
                            subtitle: a['name']?.toString().isNotEmpty == true ? a['name']?.toString() : '邮箱账户',
                            trailing: selected
                                ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary, size: 20)
                                : Icon(Icons.radio_button_unchecked_rounded,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant, size: 18),
                            onTap: () {
                              ref.read(selectedMailAccountIdProvider.notifier).state = accountId;
                              ref.invalidate(mailListProvider(0));
                              ref.invalidate(mailListProvider(1));
                              ref.invalidate(starsProvider);
                            },
                          );
                        },
                      )
                      .toList(),
                );
              },
              loading: () => const SettingsGroup(
                children: [
                  SettingsItem(
                    icon: Icons.hourglass_empty_outlined,
                    title: '加载邮箱中...',
                    trailing: SizedBox.shrink(),
                  ),
                ],
              ),
              error: (e, _) => SettingsGroup(
                children: [
                  SettingsItem(
                    icon: Icons.error_outline,
                    title: '邮箱加载失败',
                    subtitle: '$e',
                    onTap: () => ref.invalidate(myAccountsProvider),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionTitle(title: '显示'),
            SettingsGroup(
              children: [
                SettingsSwitchItem(
                  icon: Icons.dark_mode_outlined,
                  title: '深色模式',
                  subtitle: isDark ? '已开启' : '已关闭',
                  value: isDark,
                  onChanged: (v) {
                    ref.read(themeConfigProvider.notifier).updateThemeMode(v ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
                SettingsSwitchItem(
                  icon: Icons.send_outlined,
                  title: '显示发件箱',
                  subtitle: '底部导航展示发件箱页面',
                  value: ref.watch(navVisibilityProvider).showSent,
                  onChanged: (v) => ref.read(navVisibilityProvider.notifier).setShowSent(v),
                ),
                SettingsSwitchItem(
                  icon: Icons.drafts_outlined,
                  title: '显示草稿箱',
                  subtitle: '底部导航展示草稿箱页面',
                  value: ref.watch(navVisibilityProvider).showDraft,
                  onChanged: (v) => ref.read(navVisibilityProvider.notifier).setShowDraft(v),
                ),
                SettingsSwitchItem(
                  icon: Icons.star_border,
                  title: '显示星标页',
                  subtitle: '底部导航展示星标页面',
                  value: ref.watch(navVisibilityProvider).showStar,
                  onChanged: (v) => ref.read(navVisibilityProvider.notifier).setShowStar(v),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionTitle(title: '安全与会话'),
            SettingsGroup(
              children: [
                if (perms.contains('my:delete'))
                  SettingsItem(
                    icon: Icons.person_remove_outlined,
                    title: '注销账号',
                    onTap: () async => ref.read(dioProvider).delete('/my/delete'),
                  ),
              ],
            ),
            if (isAdmin) ...[
              const SizedBox(height: AppSpacing.lg),
              const SectionTitle(title: '管理'),
              SettingsGroup(
                children: [
                  SettingsItem(
                    icon: Icons.language_outlined,
                    title: '网站设置',
                    subtitle: '站点标题、注册开关、多号模式',
                    onTap: () => _pushFromRight(context, const SettingAdminPage()),
                  ),
                ],
              ),
            ],
          ],
        );
      },
      loading: () => const AppLoadingView(),
      error: (e, _) => AppErrorView(message: '$e', onRetry: () => ref.invalidate(myInfoProvider)),
    );
  }

  Future<void> _pushFromRight(BuildContext context, Widget page) {
    return Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final offsetTween = Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero);
          return SlideTransition(
            position: animation.drive(CurveTween(curve: Curves.easeOutCubic)).drive(offsetTween),
            child: child,
          );
        },
      ),
    );
  }
}

class _AccountSecurityPage extends StatelessWidget {
  const _AccountSecurityPage({required this.ref, required this.canDeleteAccount});

  final WidgetRef ref;
  final bool canDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账号与安全')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SectionTitle(title: '账号操作'),
          SettingsGroup(
            children: [
              SettingsItem(
                icon: Icons.lock_outline,
                title: '修改密码',
                onTap: () => _resetPasswordInPage(context),
              ),
              SettingsItem(
                icon: Icons.delete_sweep_outlined,
                title: '清除本地数据',
                onTap: () async {
                  await ref.read(sessionProvider.notifier).logout(clearAll: true);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('本地数据已清理')));
                  }
                },
              ),
              SettingsItem(
                icon: Icons.logout,
                title: '退出登录',
                onTap: () async => ref.read(sessionProvider.notifier).logout(),
              ),
              if (canDeleteAccount)
                SettingsItem(
                  icon: Icons.person_remove_outlined,
                  title: '注销账号',
                  onTap: () async => ref.read(dioProvider).delete('/my/delete'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _resetPasswordInPage(BuildContext context) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('修改密码'),
        content: TextField(controller: c, obscureText: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(dioProvider).put('/my/resetPassword', data: {'password': c.text});
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('修改成功')));
    }
  }
}
