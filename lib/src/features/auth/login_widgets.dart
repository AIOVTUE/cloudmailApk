import 'package:flutter/material.dart';

import '../../core/theme/theme_tokens.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [colors.primary, colors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(Icons.mark_email_unread_outlined, size: 34, color: colors.onPrimary),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'CloudMail',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class LoginInputField extends StatelessWidget {
  const LoginInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.fieldKey,
    this.hintText,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Key? fieldKey;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class LoginButton extends StatelessWidget {
  const LoginButton({
    super.key,
    required this.loading,
    required this.onPressed,
  });

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.md),
        gradient: LinearGradient(
          colors: [colors.primary, colors.secondary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: FilledButton(
        key: const Key('loginButton'),
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(46),
        ),
        child: AnimatedSwitcher(
          duration: AppMotion.fast,
          child: loading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  '登录',
                  key: ValueKey('text'),
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}

class LoginForm extends StatelessWidget {
  const LoginForm({
    super.key,
    required this.formKey,
    required this.siteController,
    required this.emailController,
    required this.passwordController,
    required this.rememberMe,
    required this.loading,
    required this.onRememberChanged,
    required this.onSubmit,
    required this.siteValidator,
    required this.emailValidator,
    required this.passwordValidator,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController siteController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool rememberMe;
  final bool loading;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onSubmit;
  final String? Function(String?) siteValidator;
  final String? Function(String?) emailValidator;
  final String? Function(String?) passwordValidator;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          LoginInputField(
            fieldKey: const Key('siteUrlInput'),
            controller: siteController,
            label: '站点地址',
            icon: Icons.language_rounded,
            hintText: 'https://example.com',
            validator: siteValidator,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: AppSpacing.sm),
          LoginInputField(
            fieldKey: const Key('emailInput'),
            controller: emailController,
            label: '邮箱地址',
            icon: Icons.alternate_email_rounded,
            hintText: 'name@example.com',
            validator: emailValidator,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.sm),
          LoginInputField(
            fieldKey: const Key('passwordInput'),
            controller: passwordController,
            label: '密码',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
            validator: passwordValidator,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Checkbox(
                value: rememberMe,
                onChanged: (v) => onRememberChanged(v ?? false),
              ),
              const Text('记住登录信息'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LoginButton(
            loading: loading,
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}

