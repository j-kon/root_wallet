import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/theme/app_theme.dart';
import 'package:root_wallet/core/platform/share_service.dart';
import 'package:root_wallet/core/platform/url_launcher_service.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/features/wallet/presentation/pages/transaction_details_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('transaction details opens explorer with the launcher service', (
    WidgetTester tester,
  ) async {
    final launcher = _FakeUrlLauncherService();

    await _pumpTransactionDetailsPage(
      tester,
      shareService: _FakeShareService(),
      urlLauncherService: launcher,
    );

    final openExplorerButton = find.widgetWithText(
      FilledButton,
      'Open explorer',
    );
    await tester.scrollUntilVisible(openExplorerButton, 300);
    await tester.tap(openExplorerButton);
    await tester.pumpAndSettle();

    expect(
      launcher.openedUris.single.toString(),
      'https://mempool.space/testnet/tx/test_txid_1234567890',
    );
  });

  testWidgets('transaction details shares tx metadata through share service', (
    WidgetTester tester,
  ) async {
    final shareService = _FakeShareService();

    await _pumpTransactionDetailsPage(
      tester,
      shareService: shareService,
      urlLauncherService: _FakeUrlLauncherService(),
    );

    final shareButton = find.widgetWithText(FilledButton, 'Share transaction');
    await tester.scrollUntilVisible(shareButton, 300);
    await tester.tap(shareButton);
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
    expect(shareService.subjects, ['Root Wallet transaction']);
  });
}

Future<void> _pumpTransactionDetailsPage(
  WidgetTester tester, {
  required ShareService shareService,
  required UrlLauncherService urlLauncherService,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await tester.binding.setSurfaceSize(const Size(375, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shareServiceProvider.overrideWithValue(shareService),
        urlLauncherServiceProvider.overrideWithValue(urlLauncherService),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: RouteSettings(
              arguments: TxItem(
                txId: 'test_txid_1234567890',
                amountSats: 12000,
                timestamp: DateTime(2026, 3, 31, 9, 30),
                isIncoming: false,
                status: TxItemStatus.pending,
                feeSats: 500,
                confirmations: 0,
              ),
            ),
            builder: (_) => const TransactionDetailsPage(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
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
