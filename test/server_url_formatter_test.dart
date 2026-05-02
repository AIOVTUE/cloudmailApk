import 'package:cloudmail/src/core/config/server_url_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server url formatter normalizes host and protocol', () {
    expect(ServerUrlFormatter.normalize(' example.com/ '), 'https://example.com');
    expect(ServerUrlFormatter.toApiBaseUrl('http://foo.com/'), 'http://foo.com/api');
  });

  test('invalid url throws format exception', () {
    expect(() => ServerUrlFormatter.normalize(''), throwsFormatException);
  });
}
