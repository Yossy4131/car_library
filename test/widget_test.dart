import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:car_library/features/auth/screens/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders required fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    expect(find.text('ログイン'), findsAtLeastNWidgets(1));
    expect(find.text('ユーザーID'), findsOneWidget);
    expect(find.text('パスワード'), findsAtLeastNWidgets(1));
  });
}
