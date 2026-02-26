import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/bootstrap.dart';

void main() {
  testWidgets('renders wallet home shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RootWalletApp()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
