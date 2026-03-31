import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/core/platform/share_service.dart';
import 'package:root_wallet/core/platform/url_launcher_service.dart';
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
        overrides: [
          shareServiceProvider.overrideWithValue(_FakeShareService()),
          urlLauncherServiceProvider.overrideWithValue(
            _FakeUrlLauncherService(),
          ),
        ],
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

  testWidgets('send success page opens explorer with launcher service', (
    WidgetTester tester,
  ) async {
    final launcher = _FakeUrlLauncherService();

    await _pumpSuccessPage(
      tester,
      shareService: _FakeShareService(),
      urlLauncherService: launcher,
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();

    await tester.tap(find.text('View explorer'));
    await tester.pumpAndSettle();

    expect(
      launcher.openedUris.single.toString(),
      'https://mempool.space/testnet/tx/test_txid_1234567890',
    );
  });

  testWidgets('send success page shares the tracking link', (
    WidgetTester tester,
  ) async {
    final shareService = _FakeShareService();

    await _pumpSuccessPage(
      tester,
      shareService: shareService,
      urlLauncherService: _FakeUrlLauncherService(),
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.share_outlined));
    await tester.pumpAndSettle();

    expect(shareService.sharedTexts, hasLength(1));
    expect(
      shareService.sharedTexts.single,
      contains('TXID: test_txid_1234567890'),
    );
    expect(
      shareService.sharedTexts.single,
      contains('https://mempool.space/testnet/tx/test_txid_1234567890'),
    );
    expect(shareService.subjects, ['Root Wallet transfer']);
  });
}

Future<void> _pumpSuccessPage(
  WidgetTester tester, {
  required ShareService shareService,
  required UrlLauncherService urlLauncherService,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await tester.binding.setSurfaceSize(const Size(375, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shareServiceProvider.overrideWithValue(shareService),
        urlLauncherServiceProvider.overrideWithValue(urlLauncherService),
      ],
      child: MaterialApp(
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

class _FakeShareService implements ShareService {
  final List<String> sharedTexts = <String>[];
  final List<String?> subjects = <String?>[];

  @override
  Future<bool> shareText(String text, {String? subject}) async {
    sharedTexts.add(text);
    subjects.add(subject);
    return true;
  }
}

class _FakeUrlLauncherService implements UrlLauncherService {
  final List<Uri> openedUris = <Uri>[];

  @override
  Future<bool> openExternalUrl(Uri uri) async {
    openedUris.add(uri);
    return true;
  }
}
