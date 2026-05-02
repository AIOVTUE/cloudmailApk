class SessionState {
  const SessionState({
    required this.siteUrl,
    required this.apiBaseUrl,
    required this.email,
    required this.token,
    required this.rememberMe,
    this.permKeys = const <String>[],
  });

  final String siteUrl;
  final String apiBaseUrl;
  final String email;
  final String token;
  final bool rememberMe;
  final List<String> permKeys;

  bool hasPerm(String key) => permKeys.contains(key);
  bool get isLoggedIn => token.isNotEmpty && apiBaseUrl.isNotEmpty;

  SessionState copyWith({
    String? siteUrl,
    String? apiBaseUrl,
    String? email,
    String? token,
    bool? rememberMe,
    List<String>? permKeys,
  }) {
    return SessionState(
      siteUrl: siteUrl ?? this.siteUrl,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      email: email ?? this.email,
      token: token ?? this.token,
      rememberMe: rememberMe ?? this.rememberMe,
      permKeys: permKeys ?? this.permKeys,
    );
  }

  static const empty = SessionState(siteUrl: '', apiBaseUrl: '', email: '', token: '', rememberMe: false);
}
