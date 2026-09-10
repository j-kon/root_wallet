import 'dart:io';
import 'package:bdk_dart/bdk_dart.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/core/network/bitcoin_network_environment.dart';

void main() {
  group('Address Validation & Network Isolation Tests', () {
    const validTestnetP2wpkh = 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';
    const validTestnetP2pkh = 'mipcBbFg9gMiCh81Kj8tqqdgoZub1ZJRfn';
    const validTestnetTaproot = 'tb1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0';
    const validMainnetP2wpkh = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
    const validMainnetLegacy = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';

    test('Valid testnet addresses parse correctly under testnet network', () async {
      final p2wpkh = bdk.Address(
        address: validTestnetP2wpkh,
        network: bdk.Network.testnet,
      );
      expect(p2wpkh.toString(), equals(validTestnetP2wpkh));

      final p2pkh = bdk.Address(
        address: validTestnetP2pkh,
        network: bdk.Network.testnet,
      );
      expect(p2pkh.toString(), equals(validTestnetP2pkh));

      // Derive valid taproot address from descriptor
      final mnemonic = bdk.Mnemonic(wordCount: bdk.WordCount.words12);
      final secretKey = bdk.DescriptorSecretKey(
        networkKind: bdk.NetworkKind.test,
        mnemonic: mnemonic,
        password: null,
      );
      final externalDescriptor = bdk.Descriptor.newBip86(
        secretKey: secretKey,
        keychainKind: bdk.KeychainKind.external_,
        networkKind: bdk.NetworkKind.test,
      );
      final internalDescriptor = bdk.Descriptor.newBip86(
        secretKey: secretKey,
        keychainKind: bdk.KeychainKind.internal,
        networkKind: bdk.NetworkKind.test,
      );
      final tempDir = await Directory.systemTemp.createTemp('tr_test_');
      final persister = bdk.Persister.newSqlite(
        path: '${tempDir.path}/tr_wallet.sqlite',
      );
      final wallet = bdk.Wallet(
        descriptor: externalDescriptor,
        changeDescriptor: internalDescriptor,
        network: bdk.Network.testnet,
        persister: persister,
        lookahead: 20,
      );
      final addressInfo = wallet.revealNextAddress(
        keychain: bdk.KeychainKind.external_,
      );
      final trAddress = addressInfo.address.toString();
      expect(trAddress.startsWith('tb1p'), isTrue);

      final parsed = bdk.Address(
        address: trAddress,
        network: bdk.Network.testnet,
      );
      expect(parsed.toString(), equals(trAddress));
      await tempDir.delete(recursive: true);
    });

    test('Wrong network address is strictly rejected by BDK Address validator', () {
      // Trying to parse mainnet address on testnet must fail
      expect(
        () => bdk.Address(
          address: validMainnetP2wpkh,
          network: bdk.Network.testnet,
        ),
        throwsException,
      );

      expect(
        () => bdk.Address(
          address: validMainnetLegacy,
          network: bdk.Network.testnet,
        ),
        throwsException,
      );
    });

    test('Corrupted address checksum is strictly rejected', () {
      // Alter the last character of a valid testnet bech32 address
      final corrupted = validTestnetP2wpkh.substring(0, validTestnetP2wpkh.length - 1) + 'q';
      expect(
        () => bdk.Address(
          address: corrupted,
          network: bdk.Network.testnet,
        ),
        throwsException,
      );
    });

    test('BitcoinNetworkEnvironment prefix guards distinguish mainnet and testnet', () {
      const testnetEnv = BitcoinNetworkEnvironment.testnet;
      const mainnetEnv = BitcoinNetworkEnvironment.mainnet;

      expect(testnetEnv.isValidAddressPrefix(validTestnetP2wpkh), isTrue);
      expect(testnetEnv.isValidAddressPrefix(validTestnetP2pkh), isTrue);
      expect(testnetEnv.isValidAddressPrefix(validTestnetTaproot), isTrue);
      expect(testnetEnv.isValidAddressPrefix(validMainnetP2wpkh), isFalse);
      expect(testnetEnv.isValidAddressPrefix(validMainnetLegacy), isFalse);

      expect(mainnetEnv.isValidAddressPrefix(validMainnetP2wpkh), isTrue);
      expect(mainnetEnv.isValidAddressPrefix(validMainnetLegacy), isTrue);
      expect(mainnetEnv.isValidAddressPrefix(validTestnetP2wpkh), isFalse);
    });
  });
}
