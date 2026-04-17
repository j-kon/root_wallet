import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/theme/app_theme.dart';
import 'package:root_wallet/core/platform/share_service.dart';
import 'package:root_wallet/core/platform/url_launcher_service.dart';
import 'package:root_wallet/features/receive/presentation/pages/receive_page.dart';
import 'package:root_wallet/features/wallet/domain/entities/balance.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('receive share options shares the raw address', (
    WidgetTester tester,
  ) async {
    final shareService = _FakeShareService();

    await _pumpReceivePage(
      tester,
      shareService: shareService,
      urlLauncherService: _FakeUrlLauncherService(),
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share address').last);
    await tester.pumpAndSettle();

    expect(shareService.sharedTexts, ['tb1qreceiveaddress']);
    expect(shareService.subjects, ['Root Wallet testnet4 address']);
  });

  testWidgets('receive share options shares the payment request URI', (
    WidgetTester tester,
  ) async {
    final shareService = _FakeShareService();

    await _pumpReceivePage(
      tester,
      shareService: shareService,
      urlLauncherService: _FakeUrlLauncherService(),
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share payment request'));
    await tester.pumpAndSettle();

    expect(shareService.sharedTexts, ['bitcoin:tb1qreceiveaddress']);
    expect(shareService.subjects, ['Root Wallet payment request']);
  });
}

Future<void> _pumpReceivePage(
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
        walletHomeControllerProvider.overrideWith(
          () => _FakeWalletHomeController(
            WalletHomeState(
              balance: const Balance(confirmedSats: 50000),
              transactions: const [],
              receiveAddress: 'tb1qreceiveaddress',
              lastSyncedAt: DateTime(2026, 3, 31, 12),
              isOffline: false,
              isSyncing: false,
            ),
          ),
        ),
        shareServiceProvider.overrideWithValue(shareService),
        urlLauncherServiceProvider.overrideWithValue(urlLauncherService),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        home: const ReceivePage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeWalletHomeController extends WalletHomeController {
  _FakeWalletHomeController(this._state);

  final WalletHomeState _state;

  @override
  Future<WalletHomeState> build() async => _state;
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
  @override
  Future<bool> openExternalUrl(Uri uri) async => true;
}
