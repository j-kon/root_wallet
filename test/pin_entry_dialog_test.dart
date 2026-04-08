import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/theme/app_theme.dart';
import 'package:root_wallet/core/widgets/pin_entry_dialog.dart';

void main() {
  testWidgets('pin entry dialog keeps confirm disabled until 6 digits', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        home: const _PinDialogHarness(),
      ),
    );

    await tester.tap(find.text('Open PIN dialog'));
    await tester.pumpAndSettle();

    final confirmFinder = find.widgetWithText(FilledButton, 'Verify');
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '123');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNotNull);

    await tester.tap(confirmFinder);
    await tester.pumpAndSettle();

    expect(find.text('Result: 123456'), findsOneWidget);
  });
}

class _PinDialogHarness extends StatefulWidget {
  const _PinDialogHarness();

  @override
  State<_PinDialogHarness> createState() => _PinDialogHarnessState();
}

class _PinDialogHarnessState extends State<_PinDialogHarness> {
  String? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () async {
                final result = await showPinEntryDialog(
                  context,
                  title: 'Enter PIN',
                  subtitle: 'Use your wallet PIN to continue.',
                  confirmLabel: 'Verify',
                );
                if (!mounted) {
                  return;
                }
                setState(() {
                  _result = result;
                });
              },
              child: const Text('Open PIN dialog'),
            ),
            if (_result != null) Text('Result: $_result'),
          ],
        ),
      ),
    );
  }
}
