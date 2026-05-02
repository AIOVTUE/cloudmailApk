import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_response_parser.dart';
import '../../core/theme/theme_tokens.dart';
import '../../core/providers.dart';
import '../profile/settings_widgets.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key, required this.perms});
  final Set<String> perms;

  @override
  Widget build(BuildContext context) {
    final items = <({String title, Widget page, String perm})>[
      (title: '用户管理', page: const UserAdminPage(), perm: 'user:query'),
      (title: '角色管理', page: const RoleAdminPage(), perm: 'role:query'),
      (title: '全局邮件', page: const GlobalMailAdminPage(), perm: 'all-email:query'),
      (title: '系统设置', page: const SettingAdminPage(), perm: 'setting:query'),
      (title: '注册码管理', page: const RegKeyAdminPage(), perm: 'reg-key:query'),
      (title: '分析看板', page: const AnalysisPage(), perm: 'analysis:query'),
    ];
    final availableItems = items.where((it) => perms.contains(it.perm)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('管理中心')),
      body: availableItems.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('当前账号没有管理中心权限，请联系管理员分配权限后重试。'),
              ),
            )
          : ListView(
              children: availableItems
                  .map((it) => ListTile(
                        title: Text(it.title),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => it.page)),
                      ))
                  .toList(),
            ),
    );
  }
}

class UserAdminPage extends ConsumerWidget {
  const UserAdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SimpleCrudPage(
      title: '用户管理',
      load: () async => ref.read(dioProvider).get('/user/list', queryParameters: {'num': 1, 'size': 20}),
      parser: ref.read(parserProvider),
      addAction: () => ref.read(dioProvider).post('/user/add', data: {'email': 'new@example.com', 'password': '123456', 'type': 1}),
      deleteAction: (id) => ref.read(dioProvider).delete('/user/delete', queryParameters: {'userId': id}),
      resetAction: (id) => ref.read(dioProvider).put('/user/resetSendCount', data: {'userId': id}),
      idField: 'userId',
      subtitleField: 'email',
    );
  }
}

class RoleAdminPage extends ConsumerWidget {
  const RoleAdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SimpleCrudPage(
      title: '角色管理',
      load: () async => ref.read(dioProvider).get('/role/list'),
      parser: ref.read(parserProvider),
      addAction: () => ref.read(dioProvider).post('/role/add', data: {'name': 'mobile-role', 'permIds': [], 'banEmail': []}),
      deleteAction: (id) => ref.read(dioProvider).delete('/role/delete', queryParameters: {'roleId': id}),
      idField: 'roleId',
      subtitleField: 'name',
    );
  }
}

class GlobalMailAdminPage extends ConsumerWidget {
  const GlobalMailAdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SimpleCrudPage(
      title: '全局邮件',
      load: () async => ref.read(dioProvider).get('/allEmail/list', queryParameters: {'emailId': 0, 'size': 20}),
      parser: ref.read(parserProvider),
      addAction: null,
      deleteAction: (id) => ref.read(dioProvider).delete('/allEmail/delete', queryParameters: {'emailIds': '$id'}),
      idField: 'emailId',
      subtitleField: 'subject',
    );
  }
}

class SettingAdminPage extends ConsumerStatefulWidget {
  const SettingAdminPage({super.key});

  @override
  ConsumerState<SettingAdminPage> createState() => _SettingAdminPageState();
}

class _SettingAdminPageState extends ConsumerState<SettingAdminPage> {
  final TextEditingController _titleController = TextEditingController();
  bool _allowRegister = false;
  bool _allowAddEmail = false;
  bool _allowManyEmail = false;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSettings());
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final dio = ref.read(dioProvider);
    final parser = ref.read(parserProvider);
    final queryFuture = dio.get('/setting/query');
    final websiteFuture = dio.get('/setting/websiteConfig');
    final responses = await Future.wait([queryFuture, websiteFuture]);
    final queryData = parser.parse<Map<String, dynamic>>(
      responses[0].data as Map<String, dynamic>,
      (d) => d as Map<String, dynamic>,
    );
    final websiteData = parser.parse<Map<String, dynamic>>(
      responses[1].data as Map<String, dynamic>,
      (d) => d as Map<String, dynamic>,
    );
    if (!mounted) return;
    setState(() {
      _titleController.text = _pickSettingValue(websiteData, queryData, ['title']);
      // 这三个字段在后端返回值语义与开关显示语义相反，读取时需要翻转，避免“显示状态反过来”。
      _allowRegister = !_toEnabled(_pickSettingRawValue(websiteData, queryData, ['register']));
      _allowAddEmail = !_toEnabled(_pickSettingRawValue(websiteData, queryData, ['addEmail']));
      _allowManyEmail = !_toEnabled(_pickSettingRawValue(websiteData, queryData, ['manyEmail']));
      _loaded = true;
    });
  }

  dynamic _pickSettingRawValue(Map<String, dynamic> websiteData, Map<String, dynamic> queryData, List<String> keys) {
    for (final key in keys) {
      if (websiteData.containsKey(key) && websiteData[key] != null) return websiteData[key];
    }
    for (final key in keys) {
      if (queryData.containsKey(key) && queryData[key] != null) return queryData[key];
    }
    return null;
  }

  String _pickSettingValue(Map<String, dynamic> websiteData, Map<String, dynamic> queryData, List<String> keys) {
    final value = _pickSettingRawValue(websiteData, queryData, keys);
    return value?.toString() ?? '';
  }

  bool _toEnabled(dynamic value) {
    if (value is num) return value == 1;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'open';
  }

  int _toFlag(bool enabled) => enabled ? 1 : 0;

  Future<void> _saveSettings() async {
    if (_saving) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(dioProvider).put(
            '/setting/set',
            data: {
              'title': _titleController.text.trim(),
              'register': _toFlag(_allowRegister),
              'addEmail': _toFlag(_allowAddEmail),
              'manyEmail': _toFlag(_allowManyEmail),
            },
          );
      await _loadSettings();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('网站设置已保存')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmAndClean() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认物理清空数据'),
        content: const Text('该操作会级联清理已删除邮件、账户和用户数据，是否继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认清理')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(dioProvider).delete('/setting/physicsDeleteAll');
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('已执行物理清空')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('执行失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('网站设置'),
        actions: [
          TextButton(
            onPressed: _saving || !_loaded ? null : _saveSettings,
            child: _saving ? const Text('保存中...') : const Text('保存'),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                const SectionTitle(title: '站点信息'),
                SettingsGroup(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: '网站标题',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionTitle(title: '功能开关'),
                SettingsGroup(
                  children: [
                    SettingsSwitchItem(
                      icon: Icons.app_registration_outlined,
                      title: '用户注册',
                      subtitle: _allowRegister ? '允许' : '不允许',
                      value: _allowRegister,
                      onChanged: (v) => setState(() => _allowRegister = v),
                    ),
                    SettingsSwitchItem(
                      icon: Icons.alternate_email_outlined,
                      title: '添加邮箱',
                      subtitle: _allowAddEmail ? '允许' : '不允许',
                      value: _allowAddEmail,
                      onChanged: (v) => setState(() => _allowAddEmail = v),
                    ),
                    SettingsSwitchItem(
                      icon: Icons.group_work_outlined,
                      title: '多号模式',
                      subtitle: _allowManyEmail ? '允许' : '不允许',
                      value: _allowManyEmail,
                      onChanged: (v) => setState(() => _allowManyEmail = v),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionTitle(title: '数据维护'),
                SettingsGroup(
                  children: [
                    SettingsItem(
                      icon: Icons.delete_forever_outlined,
                      title: '物理清空数据',
                      subtitle: '级联清理已删除邮件、账户与用户数据',
                      onTap: _confirmAndClean,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class RegKeyAdminPage extends ConsumerWidget {
  const RegKeyAdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SimpleCrudPage(
      title: '注册码管理',
      load: () async => ref.read(dioProvider).get('/regKey/list'),
      parser: ref.read(parserProvider),
      addAction: () => ref.read(dioProvider).post('/regKey/add', data: {
        'code': 'MOBILE2026',
        'roleId': 1,
        'count': 1,
        'expireTime': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      }),
      deleteAction: (id) => ref.read(dioProvider).delete('/regKey/delete', queryParameters: {'regKeyIds': '$id'}),
      idField: 'regKeyId',
      subtitleField: 'code',
    );
  }
}

class AnalysisPage extends ConsumerWidget {
  const AnalysisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(dioProvider).get('/analysis/echarts', queryParameters: {'timeZone': 'Asia/Shanghai'}),
      builder: (_, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final payload = ref
            .read(parserProvider)
            .parse<Map<String, dynamic>>((snapshot.data as dynamic).data as Map<String, dynamic>, (d) => d as Map<String, dynamic>);
        final points = ((payload['userDayCount']?['list'] as List?) ?? const []).asMap().entries.map((e) {
          final y = (e.value['count'] as num?)?.toDouble() ?? 0;
          return FlSpot(e.key.toDouble(), y);
        }).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('分析看板')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: LineChart(LineChartData(lineBarsData: [LineChartBarData(spots: points.isEmpty ? [const FlSpot(0, 0)] : points)])),
          ),
        );
      },
    );
  }
}

class _SimpleCrudPage extends StatefulWidget {
  const _SimpleCrudPage({
    required this.title,
    required this.load,
    required this.parser,
    required this.idField,
    required this.subtitleField,
    this.addAction,
    this.deleteAction,
    this.resetAction,
  });

  final String title;
  final Future<dynamic> Function() load;
  final ApiResponseParser parser;
  final Future<void> Function()? addAction;
  final Future<void> Function(int id)? deleteAction;
  final Future<void> Function(int id)? resetAction;
  final String idField;
  final String subtitleField;

  @override
  State<_SimpleCrudPage> createState() => _SimpleCrudPageState();
}

class _SimpleCrudPageState extends State<_SimpleCrudPage> {
  late Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final resp = await widget.load();
    final data = widget.parser.parse<dynamic>(resp.data as Map<String, dynamic>, (d) => d);
    final list = data is Map<String, dynamic> ? data['list'] : data;
    return ((list as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.addAction != null)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                await widget.addAction!.call();
                setState(() => _future = _load());
              },
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() => _future = _load())),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (_, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final list = snapshot.data!;
          return ListView(
            children: list
                .map(
                  (e) => ListTile(
                    title: Text('${e[widget.subtitleField] ?? ''}'),
                    subtitle: Text('ID: ${e[widget.idField] ?? ''}'),
                    trailing: Wrap(
                      children: [
                        if (widget.resetAction != null)
                          IconButton(
                            icon: const Icon(Icons.restart_alt),
                            onPressed: () async {
                              await widget.resetAction!.call(e[widget.idField] as int? ?? 0);
                            },
                          ),
                        if (widget.deleteAction != null)
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await widget.deleteAction!.call(e[widget.idField] as int? ?? 0);
                              setState(() => _future = _load());
                            },
                          ),
                      ],
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}
