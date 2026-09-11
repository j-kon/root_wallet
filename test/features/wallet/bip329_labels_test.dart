import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_label_store.dart';
import 'package:root_wallet/features/wallet/data/services/bip329_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BIP-329 Label Import / Export & Storage Tests', () {
    late SharedPreferences prefs;
    late WalletLabelStore store;
    const bip329Service = Bip329Service();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      store = WalletLabelStore(prefs);
    });

    test('exports current labels into valid BIP-329 JSONL records', () async {
      await store.write(
        const WalletLabelsSnapshot(
          transactionMetadata: {
            '0000000000000000000000000000000000000000000000000000000000000001':
                WalletTransactionMetadata(label: 'Salary'),
            '0000000000000000000000000000000000000000000000000000000000000002':
                WalletTransactionMetadata(label: 'Coffee'),
          },
          addressLabels: {
            'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx': 'Donations',
          },
          outputLabels: {
            '0000000000000000000000000000000000000000000000000000000000000001:0': 'Change UTXO',
            '0000000000000000000000000000000000000000000000000000000000000002:1': 'Mining pool',
          },
        ),
      );

      final snapshot = store.read();
      final jsonl = bip329Service.exportJsonl(snapshot);
      final lines = const LineSplitter().convert(jsonl);
      expect(lines.length, equals(5));

      final records = lines.map((l) => jsonDecode(l) as Map<String, dynamic>).toList();

      final txRecords = records.where((r) => r['type'] == 'tx').toList();
      expect(txRecords.length, equals(2));
      expect(
        txRecords.any(
          (r) =>
              r['ref'] == '0000000000000000000000000000000000000000000000000000000000000001' &&
              r['label'] == 'Salary',
        ),
        isTrue,
      );

      final addrRecords = records.where((r) => r['type'] == 'addr').toList();
      expect(addrRecords.length, equals(1));
      expect(addrRecords.first['ref'], equals('tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx'));
      expect(addrRecords.first['label'], equals('Donations'));

      final outRecords = records.where((r) => r['type'] == 'output').toList();
      expect(outRecords.length, equals(2));
      expect(
        outRecords.any(
          (r) =>
              r['ref'] == '0000000000000000000000000000000000000000000000000000000000000001:0' &&
              r['label'] == 'Change UTXO',
        ),
        isTrue,
      );
    });

    test('imports BIP-329 JSONL records with tx, addr, and output types', () async {
      const inputJsonl = '''
{"type":"tx","ref":"00000000000000000000000000000000000000000000000000000000000000a1","label":"Incoming testnet fund"}
{"type":"addr","ref":"tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx","label":"Cold storage receive"}
{"type":"output","ref":"00000000000000000000000000000000000000000000000000000000000000a1:0","label":"Reserved for fees"}
{"type":"unknown_type","ref":"ignored_ref","label":"Should be ignored"}
{"invalid json line...}
''';

      final result = bip329Service.parseJsonl(inputJsonl, existingSnapshot: store.read());

      expect(result.importedCount, equals(3));
      expect(result.skippedCount, equals(2)); // unknown_type + invalid json

      await store.write(result.snapshot);
      final snapshot = store.read();
      expect(
        snapshot.transactionMetadata['00000000000000000000000000000000000000000000000000000000000000a1']?.label,
        equals('Incoming testnet fund'),
      );
      expect(
        snapshot.addressLabels['tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx'],
        equals('Cold storage receive'),
      );
      expect(
        snapshot.outputLabels['00000000000000000000000000000000000000000000000000000000000000a1:0'],
        equals('Reserved for fees'),
      );
    });

    test('rejects payloads exceeding size limits', () {
      // Exceed 2MB limit
      final hugePayload = 'a' * (2 * 1024 * 1024 + 10);
      expect(
        () => bip329Service.parseJsonl(hugePayload),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('size'))),
      );

      // Exceed line limit
      final manyLines = List.generate(
        10005,
        (i) => '{"type":"tx","ref":"0000000000000000000000000000000000000000000000000000000000000001","label":"L$i"}',
      ).join('\n');
      expect(
        () => bip329Service.parseJsonl(manyLines),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('10,000'))),
      );
    });

    test('preserves backward compatibility with legacy v1 storage format', () async {
      // Legacy format only stored transactions and addresses
      const legacyJson = '{"transactions":{"tx_old":{"label":"Old Tx","note":""}},"addresses":{"addr_old":"Old Addr"}}';
      await prefs.setString('wallet.local_labels.v1', legacyJson);

      final loaded = store.read();
      expect(loaded.transactionMetadata['tx_old']?.label, equals('Old Tx'));
      expect(loaded.addressLabels['addr_old'], equals('Old Addr'));
      expect(loaded.outputLabels, isEmpty);

      // Now save with output and ensure roundtrip
      final updated = loaded.copyWith(
        outputLabels: {'tx_old:0': 'New Output Label'},
      );
      await store.write(updated);

      final reloaded = store.read();
      expect(reloaded.outputLabels['tx_old:0'], equals('New Output Label'));
      expect(reloaded.transactionMetadata['tx_old']?.label, equals('Old Tx'));
    });
  });
}
