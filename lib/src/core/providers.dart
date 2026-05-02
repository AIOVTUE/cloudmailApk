import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/session_state.dart';
import 'config/server_url_formatter.dart';
import 'logging/app_logger.dart';
import 'network/api_response_parser.dart';
import 'storage/app_storage.dart';
import 'theme/theme_config.dart';

final appLoggerProvider = Provider<AppLogger>((_) => ConsoleLogger());
final parserProvider = Provider((_) => const ApiResponseParser());
final appStorageProvider = Provider<AppStorage>((_) => throw UnimplementedError());

final appBootstrapProvider = FutureProvider<void>((ref) async {
  final storage = await AppStorage.build();
  ref.read(_appStorageHolderProvider.notifier).state = storage;
});
final startupProvider = FutureProvider<void>((ref) async {
  await ref.watch(appBootstrapProvider.future);
  await ref.read(themeConfigProvider.notifier).load();
  await ref.read(sessionProvider.notifier).loadFromLocal();
});

final _appStorageHolderProvider = StateProvider<AppStorage?>((_) => null);

final storageReadyProvider = Provider<AppStorage>((ref) {
  final value = ref.watch(_appStorageHolderProvider);
  if (value == null) throw StateError('storage not initialized');
  return value;
});

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier(this.ref) : super(SessionState.empty);

  final Ref ref;

  Dio buildDio() {
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (state.token.isNotEmpty) {
          options.headers['Authorization'] = state.token;
        }
        if (state.apiBaseUrl.isNotEmpty) {
          options.baseUrl = state.apiBaseUrl;
        }
        options.extra['start'] = DateTime.now().millisecondsSinceEpoch;
        handler.next(options);
      },
      onResponse: (response, handler) async {
        final logger = ref.read(appLoggerProvider);
        final start = response.requestOptions.extra['start'] as int?;
        if (start != null) {
          logger.info('HTTP ${response.requestOptions.method} ${response.requestOptions.path}',
              extra: {'costMs': DateTime.now().millisecondsSinceEpoch - start});
        }
        final payload = response.data;
        if (payload is Map<String, dynamic>) {
          final code = payload['code'];
          if (code == 401) {
            await logout();
          }
        }
        handler.next(response);
      },
      onError: (err, handler) {
        final logger = ref.read(appLoggerProvider);
        logger.error('network error', error: err, extra: {'path': err.requestOptions.path});
        handler.next(err);
      },
    ));
    return dio;
  }

  Future<void> loadFromLocal() async {
    final storage = ref.read(storageReadyProvider);
    final remember = storage.rememberMe;
    final token = await storage.readToken() ?? '';
    final site = storage.siteUrl;
    final email = storage.email;
    if (remember && site.isNotEmpty) {
      state = SessionState(
        siteUrl: site,
        apiBaseUrl: ServerUrlFormatter.toApiBaseUrl(site),
        email: email,
        token: token.isNotEmpty ? token : '',
        rememberMe: true,
      );
    }
  }

  Future<void> saveLogin({
    required String siteUrl,
    required String email,
    required String token,
    required bool rememberMe,
    required List<String> permKeys,
  }) async {
    final normalizedSite = ServerUrlFormatter.normalize(siteUrl);
    state = SessionState(
      siteUrl: normalizedSite,
      apiBaseUrl: ServerUrlFormatter.toApiBaseUrl(normalizedSite),
      email: email,
      token: token,
      rememberMe: rememberMe,
      permKeys: permKeys,
    );
    final storage = ref.read(storageReadyProvider);
    await storage.saveToken(token);
    await storage.setRememberMe(rememberMe);
    if (rememberMe) {
      await storage.setSiteUrl(normalizedSite);
      await storage.setEmail(email);
    } else {
      await storage.setSiteUrl('');
      await storage.setEmail('');
    }
  }

  void updatePermKeys(List<String> permKeys) {
    state = state.copyWith(permKeys: permKeys);
  }

  Future<void> logout({bool clearAll = false}) async {
    final storage = ref.read(storageReadyProvider);
    if (clearAll) {
      await storage.clearAllLocalData();
    } else {
      await storage.clearToken();
    }
    state = SessionState.empty;
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) => SessionNotifier(ref));

final dioProvider = Provider<Dio>((ref) {
  final notifier = ref.read(sessionProvider.notifier);
  return notifier.buildDio();
});

class ThemeConfigNotifier extends StateNotifier<ThemeConfig> {
  ThemeConfigNotifier(this.ref) : super(const ThemeConfig());

  final Ref ref;

  Future<void> load() async {
    final storage = ref.read(storageReadyProvider);
    final json = storage.themeConfig;
    if (json != null) {
      state = ThemeConfig.fromJson(json);
      return;
    }
    final mode = storage.themeMode;
    state = ThemeConfig.fromJson({'themeMode': mode});
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _save();
  }

  Future<void> updatePreset(AppThemePreset preset) async {
    state = state.copyWith(preset: preset, useCustomPalette: false);
    await _save();
  }

  Future<void> updateCustomPalette({
    required bool enable,
    Color? primary,
    Color? secondary,
    Color? tertiary,
  }) async {
    state = state.copyWith(
      useCustomPalette: enable,
      customPrimary: primary,
      customSecondary: secondary,
      customTertiary: tertiary,
    );
    await _save();
  }

  Future<void> _save() async {
    final mode = switch (state.themeMode) { ThemeMode.light => 'light', ThemeMode.dark => 'dark', _ => 'system' };
    final storage = ref.read(storageReadyProvider);
    await storage.setThemeMode(mode);
    await storage.setThemeConfig(state.toJson());
  }
}

final themeConfigProvider = StateNotifierProvider<ThemeConfigNotifier, ThemeConfig>((ref) => ThemeConfigNotifier(ref));

class NavVisibilityConfig {
  const NavVisibilityConfig({
    this.showSent = true,
    this.showDraft = true,
    this.showStar = true,
  });

  final bool showSent;
  final bool showDraft;
  final bool showStar;

  NavVisibilityConfig copyWith({
    bool? showSent,
    bool? showDraft,
    bool? showStar,
  }) {
    return NavVisibilityConfig(
      showSent: showSent ?? this.showSent,
      showDraft: showDraft ?? this.showDraft,
      showStar: showStar ?? this.showStar,
    );
  }

  Map<String, dynamic> toJson() => {
        'showSent': showSent,
        'showDraft': showDraft,
        'showStar': showStar,
      };

  factory NavVisibilityConfig.fromJson(Map<String, dynamic> json) {
    return NavVisibilityConfig(
      showSent: json['showSent'] as bool? ?? true,
      showDraft: json['showDraft'] as bool? ?? true,
      showStar: json['showStar'] as bool? ?? true,
    );
  }
}

class NavVisibilityNotifier extends StateNotifier<NavVisibilityConfig> {
  NavVisibilityNotifier(this.ref) : super(_loadInitial(ref));

  final Ref ref;

  static NavVisibilityConfig _loadInitial(Ref ref) {
    try {
      final raw = ref.read(storageReadyProvider).navVisibility;
      if (raw != null) return NavVisibilityConfig.fromJson(raw);
    } catch (_) {
      // storage 尚未初始化时使用默认值
    }
    return const NavVisibilityConfig();
  }

  Future<void> setShowSent(bool value) async {
    state = state.copyWith(showSent: value);
    await _save();
  }

  Future<void> setShowDraft(bool value) async {
    state = state.copyWith(showDraft: value);
    await _save();
  }

  Future<void> setShowStar(bool value) async {
    state = state.copyWith(showStar: value);
    await _save();
  }

  Future<void> _save() async {
    await ref.read(storageReadyProvider).setNavVisibility(state.toJson());
  }
}

final navVisibilityProvider =
    StateNotifierProvider<NavVisibilityNotifier, NavVisibilityConfig>((ref) => NavVisibilityNotifier(ref));
