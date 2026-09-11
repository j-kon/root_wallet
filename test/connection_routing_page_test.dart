import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/theme/app_theme.dart';
import 'package:root_wallet/core/network/network_storage_keys.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/settings/presentation/pages/connection_routing_page.dart';
import 'package:root_wallet/features/settings/presentation/providers/network_transport_providers.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ConnectionRoutingPage Widget Tests', () {
    late SharedPreferences prefs;
    late InMemorySecureStorage secureStorage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      secureStorage = InMemorySecureStorage();
    });

    Widget buildTestWidget({
      ProxyConnectionTester? customTester,
    }) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
          secureStorageProvider.overrideWithValue(secureStorage),
          if (customTester != null)
            proxyConnectionTesterProvider.overrideWithValue(customTester),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const ConnectionRoutingPage(),
        ),
      );
    }

    testWidgets('renders transport modes and default direct connection state', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Connection Routing'), findsOneWidget);
      expect(find.text('Direct Connection (Default)'), findsOneWidget);
      expect(find.text('SOCKS5 Proxy (Tor-Compatible)'), findsOneWidget);
      expect(find.text('Direct connection'), findsOneWidget);
    });

    testWidgets('switching to SOCKS5 displays proxy form without unsupported credentials', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap SOCKS5 mode tile
      await tester.tap(find.text('SOCKS5 Proxy (Tor-Compatible)'));
      await tester.pumpAndSettle();

      // Proxy form fields appear
      expect(find.text('Proxy Host or IP'), findsOneWidget);
      expect(find.text('Proxy Port'), findsOneWidget);
      expect(find.text('Username (Optional)'), findsNothing);
      expect(find.text('Password (Optional)'), findsNothing);
      expect(find.text('Test Proxy'), findsOneWidget);
      expect(find.text('Save (Unverified)'), findsOneWidget);

      // Honest disclosures are visible
      expect(find.text('Privacy & Network Model'), findsOneWidget);
      expect(
        find.textContaining('SOCKS5 routing applies to Electrum backends only'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('Fail-closed routing guarantee:'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('validates port, empty host, and rejects .onion in proxy host', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('SOCKS5 Proxy (Tor-Compatible)'));
      await tester.pumpAndSettle();

      final hostField = find.byType(TextField).at(0);
      final portField = find.byType(TextField).at(1);

      // Enter invalid port
      await tester.enterText(portField, '999999');
      await tester.tap(find.text('Save (Unverified)'));
      await tester.pumpAndSettle();

      expect(
        find.text('Proxy port must be an integer between 1 and 65535.'),
        findsOneWidget,
      );

      // Reset valid port, enter empty host
      await tester.enterText(portField, '9050');
      await tester.enterText(hostField, '');
      await tester.tap(find.text('Save (Unverified)'));
      await tester.pumpAndSettle();

      expect(find.text('Proxy host cannot be empty.'), findsOneWidget);

      // Enter .onion in host
      await tester.enterText(hostField, 'myonionservice.onion');
      await tester.tap(find.text('Save (Unverified)'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Proxy host cannot be a .onion address'),
        findsOneWidget,
      );
    });

    testWidgets('testing proxy displays test results banner and activates Save & Activate', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool testerCalled = false;
      final mockTester = ({
        required String electrumUrl,
        required String socks5Address,
        int timeoutSeconds = 5,
      }) async {
        testerCalled = true;
        return true;
      };

      await tester.pumpWidget(buildTestWidget(customTester: mockTester));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SOCKS5 Proxy (Tor-Compatible)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test Proxy'));
      await tester.pumpAndSettle();

      expect(testerCalled, isTrue);
      expect(
        find.textContaining('Connected to Electrum node via SOCKS5'),
        findsOneWidget,
      );
      expect(find.text('Save & Activate'), findsOneWidget);
    });

    testWidgets('editing host or port after successful test invalidates verified status and reverts to Save (Unverified)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockTester = ({
        required String electrumUrl,
        required String socks5Address,
        int timeoutSeconds = 5,
      }) async {
        return true;
      };

      await tester.pumpWidget(buildTestWidget(customTester: mockTester));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SOCKS5 Proxy (Tor-Compatible)'));
      await tester.pumpAndSettle();

      // Test passes
      await tester.tap(find.text('Test Proxy'));
      await tester.pumpAndSettle();

      expect(find.text('Save & Activate'), findsOneWidget);
      expect(
        find.textContaining('Connected to Electrum node via SOCKS5'),
        findsOneWidget,
      );

      // Now edit port
      final portField = find.byType(TextField).at(1);
      await tester.enterText(portField, '9051');
      await tester.pumpAndSettle();

      // Verified badge and Save & Activate must be invalidated
      expect(find.text('Save (Unverified)'), findsOneWidget);
      expect(find.text('Save & Activate'), findsNothing);
      expect(
        find.textContaining('Connected to Electrum node via SOCKS5'),
        findsNothing,
      );
    });

    testWidgets('testing proxy probes custom Electrum endpoint when configured in preferences', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final validV3Onion = 'ssl://${'a' * 56}.onion:50002';
      await prefs.setString(
        NetworkStorageKeys.customElectrumUrl,
        validV3Onion,
      );

      String? probedElectrumUrl;
      final mockTester = ({
        required String electrumUrl,
        required String socks5Address,
        int timeoutSeconds = 5,
      }) async {
        probedElectrumUrl = electrumUrl;
        return true;
      };

      await tester.pumpWidget(buildTestWidget(customTester: mockTester));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SOCKS5 Proxy (Tor-Compatible)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test Proxy'));
      await tester.pumpAndSettle();

      expect(probedElectrumUrl, equals(validV3Onion));
    });

    testWidgets('testing proxy displays error banner on failure', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockTester = ({
        required String electrumUrl,
        required String socks5Address,
        int timeoutSeconds = 5,
      }) async {
        return false;
      };

      await tester.pumpWidget(buildTestWidget(customTester: mockTester));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SOCKS5 Proxy (Tor-Compatible)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test Proxy'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('SOCKS5 proxy is unavailable'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Root Wallet will not fall back to a direct connection'),
        findsOneWidget,
      );
    });

    testWidgets('saving proxy configuration updates transport mode and stores state', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockTester = ({
        required String electrumUrl,
        required String socks5Address,
        int timeoutSeconds = 5,
      }) async {
        return true;
      };

      await tester.pumpWidget(buildTestWidget(customTester: mockTester));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SOCKS5 Proxy (Tor-Compatible)'));
      await tester.pumpAndSettle();

      // Test first so button becomes Save & Activate
      await tester.tap(find.text('Test Proxy'));
      await tester.pumpAndSettle();

      // Save & Activate
      await tester.tap(find.text('Save & Activate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(prefs.getString(NetworkStorageKeys.transportMode), equals('socks5'));
      expect(prefs.getString(NetworkStorageKeys.proxyHost), equals('127.0.0.1'));
      expect(prefs.getInt(NetworkStorageKeys.proxyPort), equals(9050));
    });

    testWidgets('renders SOCKS5 configuration invalid status honestly when host is missing', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await prefs.setString(NetworkStorageKeys.transportMode, 'socks5');
      await prefs.remove(NetworkStorageKeys.proxyHost);
      await prefs.setInt(NetworkStorageKeys.proxyPort, 9050);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('SOCKS5 configuration invalid'), findsOneWidget);
      expect(find.text('SOCKS5 configured'), findsNothing);
      expect(
        find.textContaining('SOCKS5 configuration is invalid or missing'),
        findsOneWidget,
      );
    });

    testWidgets('renders SOCKS5 configuration invalid status honestly when host is malformed', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await prefs.setString(NetworkStorageKeys.transportMode, 'socks5');
      await prefs.setString(NetworkStorageKeys.proxyHost, 'invalid host with spaces');
      await prefs.setInt(NetworkStorageKeys.proxyPort, 9050);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('SOCKS5 configuration invalid'), findsOneWidget);
      expect(find.text('SOCKS5 configured'), findsNothing);
      expect(
        find.textContaining('SOCKS5 configuration is invalid or missing'),
        findsOneWidget,
      );
    });

    testWidgets('renders SOCKS5 configuration invalid status honestly when port is invalid', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await prefs.setString(NetworkStorageKeys.transportMode, 'socks5');
      await prefs.setString(NetworkStorageKeys.proxyHost, '127.0.0.1');
      await prefs.setInt(NetworkStorageKeys.proxyPort, 0);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('SOCKS5 configuration invalid'), findsOneWidget);
      expect(find.text('SOCKS5 configured'), findsNothing);
      expect(
        find.textContaining('SOCKS5 configuration is invalid or missing'),
        findsOneWidget,
      );
    });
  });
}
