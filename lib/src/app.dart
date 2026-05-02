import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

class CloudMailApp extends ConsumerWidget {
  const CloudMailApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(startupProvider);
    final router = ref.watch(appRouterProvider);
    final themeConfig = ref.watch(themeConfigProvider);
    final palette = themeConfig.resolvePalette();
    return MaterialApp.router(
      title: 'Cloud Mail',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(palette),
      darkTheme: AppTheme.dark(palette),
      themeMode: themeConfig.themeMode,
      routerConfig: router,
      builder: (context, child) {
        if (bootstrap.isLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return child ?? const SizedBox.shrink();
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],
    );
  }
}
