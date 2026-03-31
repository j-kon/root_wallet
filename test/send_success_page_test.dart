import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/features/send/presentation/pages/send_success_page.dart';
import 'package:root_wallet/features/wallet/presentation/pages/transaction_details_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('send success page opens transaction details', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.transactionDetails) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const TransactionDetailsPage(),
              );
            }
            return null;
          },
          home: _SuccessHarness(
            args: SendSuccessPageArgs(
              txId: 'test_txid_1234567890',
              amountSats: 12000,
              feeSats: 500,
              sentAt: DateTime(2026, 3, 31, 9, 30),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Transfer sent'), findsOneWidget);
    expect(find.text('View transaction'), findsOneWidget);

    await tester.tap(find.text('View transaction'));
    await tester.pumpAndSettle();

    expect(find.text('Transaction'), findsOneWidget);
    expect(find.text('Pending'), findsWidgets);
  });
}

class _SuccessHarness extends StatefulWidget {
  const _SuccessHarness({required this.args});

  final SendSuccessPageArgs args;

  @override
  State<_SuccessHarness> createState() => _SuccessHarnessState();
}

class _SuccessHarnessState extends State<_SuccessHarness> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: RouteSettings(arguments: widget.args),
          builder: (_) => const SendSuccessPage(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
