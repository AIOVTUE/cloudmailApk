class ServerUrlFormatter {
  static String normalize(String input) {
    var value = input.trim();
    if (value.isEmpty) {
      throw const FormatException('站点地址不能为空');
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      throw const FormatException('站点地址格式错误');
    }
    final segments = <String>[
      ...uri.pathSegments.where((s) => s.isNotEmpty),
    ];
    if (segments.isNotEmpty && segments.last.toLowerCase() == 'api') {
      segments.removeLast();
    }
    final path = segments.isEmpty ? '' : '/${segments.join('/')}';
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}$path';
  }

  static String toApiBaseUrl(String input) => '${normalize(input)}/api';
}
