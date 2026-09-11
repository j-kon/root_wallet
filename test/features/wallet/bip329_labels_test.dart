import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_label_store.dart';
import 'package:root_wallet/features/wallet/data/services/bip329_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BIP-329 Labels & Scoped Storage Hardening Tests', () {
    late SharedPreferences prefs;
    late WalletLabelStore primaryStore;
    const bip329Service = Bip329Service();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      primaryStore = WalletLabelStore(prefs, scope: 'primary');
    });

    group('Wallet Scoping & Deterministic v1 Migration', () {
      test('isolates labels between primary, decoy, and watch-only scopes', () async {
        final decoyStore = WalletLabelStore(prefs, scope: 'decoy');
        final watchOnlyStore = WalletLabelStore(prefs, scope: 'watch_only_73c5da0a');

        await primaryStore.setAddressLabel('tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx', 'Primary Wallet Label');
        await decoyStore.setAddressLabel('tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx', 'Decoy Wallet Label');
        await watchOnlyStore.setAddressLabel('tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx', 'Watch Only Label');

        expect(primaryStore.read().addressLabel('tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx'), equals('Primary Wallet Label'));
        expect(decoyStore.read().addressLabel('tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx'), equals('Decoy Wallet Label'));
        expect(watchOnlyStore.read().addressLabel('tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx'), equals('Watch Only Label'));

        // Verify storage keys in SharedPreferences
        expect(prefs.containsKey('wallet.local_labels.v3.primary'), isTrue);
        expect(prefs.containsKey('wallet.local_labels.v3.decoy'), isTrue);
        expect(prefs.containsKey('wallet.local_labels.v3.watch_only_73c5da0a'), isTrue);
      });

      test('deterministically migrates legacy v1 labels to v3.primary without loss', () async {
        const legacyJson = '{"transactions":{"0000000000000000000000000000000000000000000000000000000000000001":{"label":"Old Tx","note":""}},"addresses":{"tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx":"Old Addr"}}';
        await prefs.setString('wallet.local_labels.v1', legacyJson);

        // Reading primary store migrates v1 into v3.primary
        final migrated = primaryStore.read();
        expect(migrated.transactionMetadata['0000000000000000000000000000000000000000000000000000000000000001']?.label, equals('Old Tx'));
        expect(migrated.addressLabels['tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx'], equals('Old Addr'));
        expect(prefs.containsKey('wallet.local_labels.v3.primary'), isTrue);
      });

      test('deterministically migrates legacy v2 labels to v3 without loss', () async {
        const v2Json = '{"transactions":{"0000000000000000000000000000000000000000000000000000000000000002":{"label":"V2 Tx","note":""}},"addresses":{"tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx":"V2 Addr"}}';
        await prefs.setString('wallet.local_labels.v2.primary', v2Json);

        final migrated = primaryStore.read();
        expect(migrated.transactionMetadata['0000000000000000000000000000000000000000000000000000000000000002']?.label, equals('V2 Tx'));
        expect(migrated.addressLabels['tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx'], equals('V2 Addr'));
        expect(prefs.containsKey('wallet.local_labels.v3.primary'), isTrue);
      });

      test('strictly prevents migrating v1 labels into decoy or watch-only wallets', () async {
        const legacyJson = '{"transactions":{},"addresses":{"tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx":"Secret Primary Label"}}';
        await prefs.setString('wallet.local_labels.v1', legacyJson);

        final decoyStore = WalletLabelStore(prefs, scope: 'decoy');
        final watchOnlyStore = WalletLabelStore(prefs, scope: 'watch_only_test');

        expect(decoyStore.read().addressLabels, isEmpty);
        expect(watchOnlyStore.read().addressLabels, isEmpty);
        expect(prefs.containsKey('wallet.local_labels.v3.decoy'), isFalse);
        expect(prefs.containsKey('wallet.local_labels.v3.watch_only_test'), isFalse);
      });
    });

    group('Hardened BIP-329 Parsing & Field Type Safety', () {
      test('skips records with malformed field types without crashing import', () {
        const malformedLines = '''
{"type":"tx","ref":"0000000000000000000000000000000000000000000000000000000000000001","label":12345}
{"type":"tx","ref":"0000000000000000000000000000000000000000000000000000000000000002","label":{"nested":"object"}}
{"type":"tx","ref":"0000000000000000000000000000000000000000000000000000000000000003","note":["array","note"],"label":"Valid"}
{"type":null,"ref":"0000000000000000000000000000000000000000000000000000000000000004","label":"Null type"}
{"type":"tx","ref":null,"label":"Null ref"}
{"type":"tx","ref":"0000000000000000000000000000000000000000000000000000000000000005","label":null,"note":null}
{"invalid json...
{"type":"tx","ref":"0000000000000000000000000000000000000000000000000000000000000006","label":"Valid Record"}
''';

        final result = bip329Service.parseJsonl(malformedLines);

        // Only line 6 with valid label should be imported
        expect(result.importedCount, equals(1));
        expect(result.skippedCount, equals(7));
        expect(
          result.snapshot.transactionMetadata['0000000000000000000000000000000000000000000000000000000000000006']?.label,
          equals('Valid Record'),
        );
      });

      test('applies normalization and clips oversized label and note values', () {
        final longLabel = 'A' * 120;
        final longNote = 'B' * 400;
        final jsonl = '{"type":"tx","ref":"0000000000000000000000000000000000000000000000000000000000000001","label":"$longLabel","note":"$longNote"}';

        final result = bip329Service.parseJsonl(jsonl);
        expect(result.importedCount, equals(1));

        final meta = result.snapshot.transactionMetadata['0000000000000000000000000000000000000000000000000000000000000001'];
        expect(meta?.label.length, equals(80));
        expect(meta?.note.length, equals(280));
      });

      test('resolves duplicate records with latest valid record winning', () {
        const jsonl = '''
{"type":"tx","ref":"0000000000000000000000000000000000000000000000000000000000000001","label":"First"}
{"type":"tx","ref":"0000000000000000000000000000000000000000000000000000000000000001","label":"Updated Label"}
''';

        final result = bip329Service.parseJsonl(jsonl);
        expect(
          result.snapshot.transactionMetadata['0000000000000000000000000000000000000000000000000000000000000001']?.label,
          equals('Updated Label'),
        );
      });

      test('validates Bitcoin Testnet address syntax via BDK', () {
        const validAddr = 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';
        const invalidAddr = 'invalid_testnet_address_xyz';
        const mainnetAddr = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';

        const jsonl = '''
{"type":"addr","ref":"$validAddr","label":"Valid Testnet"}
{"type":"addr","ref":"$invalidAddr","label":"Invalid Syntax"}
{"type":"addr","ref":"$mainnetAddr","label":"Mainnet Address"}
''';

        final result = bip329Service.parseJsonl(jsonl);
        expect(result.importedCount, equals(1));
        expect(result.skippedCount, equals(2));
        expect(result.snapshot.addressLabels[validAddr], equals('Valid Testnet'));
        expect(result.snapshot.addressLabels.containsKey(invalidAddr), isFalse);
        expect(result.snapshot.addressLabels.containsKey(mainnetAddr), isFalse);
      });

      test('enforces UTF-8 byte length limit', () {
        // Multi-byte characters take more than 1 byte per char in UTF-8
        final multiByteChar = '€'; // 3 bytes in UTF-8
        final charCount = (2 * 1024 * 1024 / 3).ceil() + 100;
        final hugeContent = multiByteChar * charCount;

        expect(
          () => bip329Service.parseJsonl(hugeContent),
          throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('2 MB'))),
        );
      });
    });
  });
}
