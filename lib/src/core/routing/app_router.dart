import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_page.dart';
import '../../features/mail/mail_pages.dart';
import '../../features/profile/profile_page.dart';
import '../providers.dart';

const double _compactTopBarHeight = 48;
const double _topBarHideScrollThreshold = 56;

final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => session.isLoggedIn ? const HomeShellPage() : const LoginPage()),
      GoRoute(path: '/compose', builder: (context, state) => const ComposePage()),
    ],
  );
});

class HomeShellPage extends ConsumerStatefulWidget {
  const HomeShellPage({super.key});

  @override
  ConsumerState<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends ConsumerState<HomeShellPage> {
  String _selectedTabId = 'inbox';
  bool _topBarVisible = true;

  @override
  Widget build(BuildContext context) {
    final navConfig = ref.watch(navVisibilityProvider);
    final tabs = <({
      String id,
      String title,
      Widget page,
      NavigationDestination destination,
      bool hideTopBar,
      bool showCompose,
      bool showSwitcher,
      bool includeAllMail
    })>[
      (
        id: 'inbox',
        title: '收件箱',
        page: const MailListPage(inbox: true),
        destination: const NavigationDestination(icon: Icon(Icons.inbox_outlined), label: '收件箱'),
        hideTopBar: true,
        showCompose: false,
        showSwitcher: true,
        includeAllMail: true,
      ),
      if (navConfig.showSent)
        (
          id: 'sent',
          title: '发件箱',
          page: const MailListPage(inbox: false),
          destination: const NavigationDestination(icon: Icon(Icons.send_outlined), label: '发件箱'),
          hideTopBar: true,
          showCompose: true,
          showSwitcher: true,
          includeAllMail: false,
        ),
      if (navConfig.showDraft)
        (
          id: 'draft',
          title: '草稿箱',
          page: const DraftPage(),
          destination: const NavigationDestination(icon: Icon(Icons.drafts_outlined), label: '草稿箱'),
          hideTopBar: true,
          showCompose: false,
          showSwitcher: false,
          includeAllMail: false,
        ),
      if (navConfig.showStar)
        (
          id: 'star',
          title: '星标',
          page: const StarPage(),
          destination: const NavigationDestination(icon: Icon(Icons.star_border), label: '星标'),
          hideTopBar: true,
          showCompose: false,
          showSwitcher: false,
          includeAllMail: false,
        ),
      (
        id: 'settings',
        title: '设置',
        page: const ProfilePage(),
        destination: const NavigationDestination(icon: Icon(Icons.settings_outlined), label: '设置'),
        hideTopBar: false,
        showCompose: false,
        showSwitcher: false,
        includeAllMail: false,
      ),
    ];
    final selectedIndex = tabs.indexWhere((e) => e.id == _selectedTabId);
    final safeIndex = selectedIndex >= 0 ? selectedIndex : 0;
    if (selectedIndex < 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedTabId = tabs.first.id);
      });
    }
    final current = tabs[safeIndex];
    final canAutoHideTopBar = current.hideTopBar;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: canAutoHideTopBar && !_topBarVisible ? 0 : _compactTopBarHeight,
        title: Text(current.title),
        actions: [
          if (current.showSwitcher)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8, right: 6),
              child: InboxAccountSwitcherInline(width: 150, includeAllMail: current.includeAllMail),
            ),
        ],
      ),
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (!canAutoHideTopBar) return false;
          final metrics = notification.metrics;
          final canScroll = metrics.maxScrollExtent > 0;
          if (!canScroll) {
            if (!_topBarVisible) setState(() => _topBarVisible = true);
            return false;
          }
          // 规则：下滑隐藏；只有回到顶部（pixels<=0）才显示（避免“上滑就出现”）。
          if (metrics.pixels <= 0) {
            if (!_topBarVisible) setState(() => _topBarVisible = true);
            return false;
          }
          if (notification.direction == ScrollDirection.reverse &&
              _topBarVisible &&
              metrics.pixels >= _topBarHideScrollThreshold) {
            setState(() => _topBarVisible = false);
          }
          return false;
        },
        child: tabs[safeIndex].page,
      ),
      floatingActionButton: current.showCompose
          ? FloatingActionButton(
              onPressed: () => context.push('/compose'),
              child: const Icon(Icons.edit),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        height: 56,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        selectedIndex: safeIndex,
        onDestinationSelected: (index) => setState(() {
          _selectedTabId = tabs[index].id;
          _topBarVisible = true;
        }),
        destinations: tabs.map((e) => e.destination).toList(),
      ),
    );
  }
}
