import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_parchis/config/env.dart';

void main() {
  test('httpBaseUrl swaps the scheme and strips the /ws path', () {
    final base = Env.httpBaseUrl;
    expect(base.startsWith('http'), isTrue);
    expect(base.endsWith('/ws'), isFalse);
    expect(Env.serverUrl, startsWith(base.replaceFirst('http', 'ws')));
  });
}
