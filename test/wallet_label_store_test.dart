import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_label_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('WalletLabelStore saves and removes address labels', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final store = WalletLabelStore(prefs);

    await store.setAddressLabel('tb1qaddress', '  Faucet payout  ');
    expect(store.read().addressLabel('tb1qaddress'), 'Faucet payout');

    await store.setAddressLabel('tb1qaddress', '');
    expect(store.read().addressLabel('tb1qaddress'), isEmpty);
  });

  test('WalletLabelStore saves and removes transaction metadata', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final store = WalletLabelStore(prefs);

    await store.setTransactionMetadata(
      txId: 'txid',
      label: '  Test send  ',
      note: '  Paid test recipient  ',
    );

    var metadata = store.read().transactionMeta('txid');
    expect(metadata.label, 'Test send');
    expect(metadata.note, 'Paid test recipient');

    await store.setTransactionMetadata(txId: 'txid', label: '', note: '');
    metadata = store.read().transactionMeta('txid');
    expect(metadata.isEmpty, isTrue);
  });
}
