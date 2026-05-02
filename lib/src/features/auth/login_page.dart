import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../core/config/server_url_formatter.dart';
import '../../core/theme/theme_tokens.dart';
import '../../core/providers.dart';
import 'auth_repository.dart';
import 'login_widgets.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _siteController = TextEditingController();
  final _emailController = TextEditingController();
  final _pwdController = TextEditingController();
  bool _rememberMe = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final session = ref.read(sessionProvider);
      if (session.siteUrl.isNotEmpty || session.email.isNotEmpty) {
        _siteController.text = session.siteUrl;
        _emailController.text = session.email;
        _rememberMe = session.rememberMe || _rememberMe;
      } else {
        try {
          final storage = ref.read(storageReadyProvider);
          if (storage.rememberMe) {
            _siteController.text = storage.siteUrl;
            _emailController.text = storage.email;
            _rememberMe = true;
          }
        } catch (_) {
          // widget test场景下 storage 可能未初始化，保持页面可渲染。
        }
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth >= 760 ? 460.0 : double.infinity;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 0.98, end: 1.0),
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - value) * 20),
                        child: child,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        const LoginHeader(),
                        const SizedBox(height: AppSpacing.xl),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: colors.surface.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                          ),
                          child: LoginForm(
                            formKey: _formKey,
                            siteController: _siteController,
                            emailController: _emailController,
                            passwordController: _pwdController,
                            rememberMe: _rememberMe,
                            loading: _loading,
                            onRememberChanged: (v) => setState(() => _rememberMe = v),
                            onSubmit: _onLogin,
                            siteValidator: (v) {
                              try {
                                ServerUrlFormatter.normalize(v ?? '');
                                return null;
                              } catch (e) {
                                return e.toString();
                              }
                            },
                            emailValidator: (v) => (v == null || !v.contains('@')) ? '请输入有效邮箱' : null,
                            passwordValidator: (v) => (v == null || v.length < 6) ? '密码至少6位' : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _siteController.dispose();
    _emailController.dispose();
    _pwdController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final baseUrl = ServerUrlFormatter.toApiBaseUrl(_siteController.text);
      final repo = ref.read(authRepositoryProvider);
      final token = await repo.login(baseUrl: baseUrl, email: _emailController.text.trim(), password: _pwdController.text);
      await ref.read(sessionProvider.notifier).saveLogin(
            siteUrl: _siteController.text,
            email: _emailController.text.trim(),
            token: token,
            rememberMe: _rememberMe,
            permKeys: const [],
          );
      try {
        final info = await repo.loginUserInfo();
        final perms = ((info['permKeys'] as List?) ?? const []).map((e) => e.toString()).toList();
        ref.read(sessionProvider.notifier).updatePermKeys(perms);
      } catch (_) {
        // 已拿到 token 时不应显示“登录失败”，用户可继续进入首页。
      }
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('登录成功')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_friendlyLoginError(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyLoginError(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 404) {
        return '登录失败：站点地址可能不正确（请确认是否输入了正确站点，且不要重复带 /api）';
      }
      if (status == 401) {
        return '登录失败：邮箱或密码错误';
      }
      if (status == 403) {
        return '登录失败：当前账号无权限访问';
      }
      return '登录失败：网络请求异常 (${status ?? 'unknown'})';
    }
    return '登录失败：$e';
  }
}
