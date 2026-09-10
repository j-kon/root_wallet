import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/core/security/clipboard_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClipboardService Security Tests', () {
    late String clipboardState;
    late ClipboardService clipboardService;

    setUp(() {
      clipboardState = '';
      clipboardService = ClipboardService(
        defaultSensitiveTimeout: const Duration(milliseconds: 50),
        setDataHandler: (data) async {
          clipboardState = data.text ?? '';
        },
        getDataHandler: (format) async {
          return ClipboardData(text: clipboardState);
        },
      );
    });

    tearDown(() {
      clipboardService.dispose();
    });

    test('copySensitive copies to clipboard and auto-clears after timeout', () async {
      const sensitivePhrase = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

      await clipboardService.copySensitive(
        sensitivePhrase,
        timeout: const Duration(milliseconds: 30),
      );

      expect(clipboardState, equals(sensitivePhrase));

      // Wait for timer to expire
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(clipboardState, equals(''));
    });

    test('copySensitive does not overwrite clipboard if user copied something else in between', () async {
      const sensitivePhrase = 'secret words list';
      const userNewCopy = 'tb1qpublicaddress';

      await clipboardService.copySensitive(
        sensitivePhrase,
        timeout: const Duration(milliseconds: 40),
      );

      expect(clipboardState, equals(sensitivePhrase));

      // Simulate user copying something else before timer fires
      clipboardState = userNewCopy;

      await Future<void>.delayed(const Duration(milliseconds: 60));

      // Must remain userNewCopy, NOT cleared!
      expect(clipboardState, equals(userNewCopy));
    });

    test('copyPublic does not auto-clear', () async {
      const publicAddress = 'tb1q999999999999';

      await clipboardService.copyPublic(publicAddress);
      expect(clipboardState, equals(publicAddress));

      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(clipboardState, equals(publicAddress));
    });

    test('clearClipboard unconditionally empties clipboard', () async {
      clipboardState = 'residual text';
      await clipboardService.clearClipboard();
      expect(clipboardState, equals(''));
    });
  });
}
