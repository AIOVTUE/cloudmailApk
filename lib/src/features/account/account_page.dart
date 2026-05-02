import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

final accountListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ref.read(dioProvider).get('/account/list', queryParameters: {'accountId': 0, 'size': 30});
  final data = ref.read(parserProvider).parse<List<Map<String, dynamic>>>(response.data as Map<String, dynamic>, (d) {
    return ((d as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  });
  return data;
});

class AccountManagePage extends ConsumerWidget {
  const AccountManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(accountListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('邮箱账户管理')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAdd(context, ref),
        child: const Icon(Icons.add),
      ),
      body: value.when(
        data: (list) => ListView(
          children: list
              .map(
                (e) => ListTile(
                  title: Text(e['email']?.toString() ?? ''),
                  subtitle: Text(e['name']?.toString() ?? ''),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('确认删除'),
                              content: Text('确定删除邮箱 ${e['email'] ?? ''} 吗？'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await ref.read(dioProvider).delete('/account/delete', queryParameters: {'accountId': e['accountId']});
                            ref.invalidate(accountListProvider);
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败 $e')),
      ),
    );
  }

  Future<void> _showAdd(BuildContext context, WidgetRef ref) async {
    final localPartController = TextEditingController();
    final domainList = await _fetchDomainSuffixes(ref);
    if (!context.mounted) return;
    String? selectedDomain = domainList.isNotEmpty ? domainList.first : null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
        title: const Text('新增账户'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (domainList.isNotEmpty) ...[
                TextField(
                  controller: localPartController,
                  decoration: const InputDecoration(labelText: '邮箱前缀'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedDomain,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '域名后缀'),
                  items: domainList
                      .map(
                        (domain) => DropdownMenuItem<String>(
                          value: domain,
                          child: Text(
                            '@$domain',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => selectedDomain = value),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认')),
        ],
      )),
    );
    if (ok == true) {
      final localPart = localPartController.text.trim();
      final email = (localPart.isNotEmpty && selectedDomain != null) ? '$localPart@$selectedDomain' : '';
      if (email.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写邮箱地址')));
        }
        return;
      }
      await ref.read(dioProvider).post('/account/add', data: {'email': email});
      ref.invalidate(accountListProvider);
    }
  }

  Future<List<String>> _fetchDomainSuffixes(WidgetRef ref) async {
    try {
      final response = await ref.read(dioProvider).get('/setting/websiteConfig');
      final data = ref.read(parserProvider).parse<Map<String, dynamic>>(response.data as Map<String, dynamic>, (d) {
        return Map<String, dynamic>.from(d as Map);
      });
      final dynamic rawDomains = data['domainList'] ?? data['domain'] ?? data['domains'] ?? data['emailDomains'];
      if (rawDomains is List) {
        return rawDomains.map((e) => _normalizeDomainSuffix(e.toString())).where((e) => e.isNotEmpty).toList();
      }
      if (rawDomains is String && rawDomains.isNotEmpty) {
        return rawDomains.split(',').map(_normalizeDomainSuffix).where((e) => e.isNotEmpty).toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  String _normalizeDomainSuffix(String raw) {
    var value = raw.trim();
    if (value.startsWith('@')) value = value.substring(1);
    return value;
  }
}
