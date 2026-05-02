import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cloudmail/src/features/auth/login_page.dart';

void main() {
  testWidgets('登录页渲染关键输入项', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: LoginPage())));

    expect(find.byKey(const Key('siteUrlInput')), findsOneWidget);
    expect(find.byKey(const Key('emailInput')), findsOneWidget);
    expect(find.byKey(const Key('passwordInput')), findsOneWidget);
    expect(find.byKey(const Key('loginButton')), findsOneWidget);
  });
}
