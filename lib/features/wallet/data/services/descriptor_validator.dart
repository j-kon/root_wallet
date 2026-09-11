import 'package:bdk_dart/bdk_dart.dart' as bdk;
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';

class DescriptorValidationException implements Exception {
  const DescriptorValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ValidatedDescriptorResult {
  const ValidatedDescriptorResult({
    required this.externalDescriptor,
    this.internalDescriptor,
    required this.scriptType,
    this.fingerprint,
  });

  final String externalDescriptor;
  final String? internalDescriptor;
  final WalletScriptType scriptType;
  final String? fingerprint;
}

abstract final class DescriptorValidator {
  static final RegExp _privateKeyPattern = RegExp(
    r'\b(?:[tuvxyz]prv[0-9a-zA-Z]{100,115}|[5KLc9][1-9A-HJ-NP-Za-km-z]{50,51})\b|prv',
    caseSensitive: false,
  );

  static final RegExp _mainnetKeyPattern = RegExp(
    r'\b(?:xpub|ypub|zpub)[0-9a-zA-Z]{100,115}\b',
    caseSensitive: false,
  );

  static final RegExp _tpubPattern = RegExp(
    r'^[tuv]pub[0-9a-zA-Z]{100,115}$',
    caseSensitive: false,
  );

  static final RegExp _terminalExternalDerivation = RegExp(r'/0/\*\)$');

  /// Validates and normalizes descriptors for watch-only wallet import.
  ///
  /// Rejects private keys, mainnet keys, unsupported descriptor types,
  /// and invalid descriptor miniscript fail-closed.
  static ValidatedDescriptorResult validate({
    required String externalInput,
    String? internalInput,
  }) {
    final cleanExt = externalInput.trim();
    String? cleanInt = internalInput?.trim();

    if (cleanExt.isEmpty) {
      throw const DescriptorValidationException(
        'Please enter a public descriptor or extended public key.',
      );
    }

    // 1. Check for private material in both inputs
    _assertNoPrivateMaterial(cleanExt, 'external descriptor');
    if (cleanInt != null && cleanInt.isNotEmpty) {
      _assertNoPrivateMaterial(cleanInt, 'internal descriptor');
    }

    // 2. Check for mainnet material
    _assertNoMainnetMaterial(cleanExt, 'external descriptor');
    if (cleanInt != null && cleanInt.isNotEmpty) {
      _assertNoMainnetMaterial(cleanInt, 'internal descriptor');
    }

    // 3. Handle raw extended public key (tpub/vpub/upub) convenience import
    if (_tpubPattern.hasMatch(cleanExt)) {
      return _deriveDescriptorsFromTpub(cleanExt);
    }

    // 4. Validate external descriptor with BDK
    final externalDescObj = _parseBdkDescriptor(cleanExt, 'External');
    WalletScriptType scriptType;
    String? fingerprint;

    try {
      if (!externalDescObj.hasWildcard()) {
        throw const DescriptorValidationException(
          'External descriptor must contain a wildcard derivation step (e.g. /0/*).',
        );
      }

      scriptType = _inferScriptType(externalDescObj);
      fingerprint = _extractFingerprint(cleanExt);
    } finally {
      externalDescObj.dispose();
    }

    // 5. Validate internal descriptor if provided
    if (cleanInt != null && cleanInt.isNotEmpty) {
      final internalDescObj = _parseBdkDescriptor(cleanInt, 'Internal');
      try {
        if (!internalDescObj.hasWildcard()) {
          throw const DescriptorValidationException(
            'Internal (change) descriptor must contain a wildcard derivation step (e.g. /1/*).',
          );
        }
        final intScriptType = _inferScriptType(internalDescObj);
        if (intScriptType != scriptType) {
          throw DescriptorValidationException(
            'Descriptor script type mismatch: External is ${scriptType.displayName} '
            'but Internal is ${intScriptType.displayName}. Both must match.',
          );
        }

        // Verify key lineage if fingerprint is present in both
        final intFingerprint = _extractFingerprint(cleanInt);
        if (fingerprint != null &&
            intFingerprint != null &&
            fingerprint != intFingerprint) {
          throw DescriptorValidationException(
            'Key lineage mismatch: External descriptor master fingerprint ($fingerprint) '
            'does not match internal descriptor master fingerprint ($intFingerprint).',
          );
        }
      } finally {
        internalDescObj.dispose();
      }
    } else if (_terminalExternalDerivation.hasMatch(cleanExt)) {
      // Safe terminal substitution only for standard single-key paths
      final candidate = cleanExt.replaceFirst(_terminalExternalDerivation, '/1/*)');
      try {
        final candObj = _parseBdkDescriptor(candidate, 'Internal');
        candObj.dispose();
        cleanInt = candidate;
      } catch (_) {
        // Keep null if derivation fails
      }
    }

    return ValidatedDescriptorResult(
      externalDescriptor: cleanExt,
      internalDescriptor: cleanInt?.isEmpty ?? true ? null : cleanInt,
      scriptType: scriptType,
      fingerprint: fingerprint,
    );
  }

  static void _assertNoPrivateMaterial(String input, String fieldName) {
    if (_privateKeyPattern.hasMatch(input)) {
      throw DescriptorValidationException(
        'Private key material (e.g. xprv/tprv/WIF) detected in $fieldName! '
        'Watch-only wallets strictly prohibit private keys for security. '
        'Please provide a public descriptor or tpub.',
      );
    }
  }

  static void _assertNoMainnetMaterial(String input, String fieldName) {
    if (_mainnetKeyPattern.hasMatch(input)) {
      throw DescriptorValidationException(
        'Mainnet key detected in $fieldName! '
        'Root Wallet is configured for Bitcoin Testnet only.',
      );
    }
  }

  static ValidatedDescriptorResult _deriveDescriptorsFromTpub(String tpub) {
    // Validate tpub using BDK DescriptorPublicKey
    bdk.DescriptorPublicKey? pubKey;
    try {
      pubKey = bdk.DescriptorPublicKey.fromString(publicKey: tpub);
    } catch (e) {
      throw DescriptorValidationException('Invalid extended public key: $e');
    } finally {
      pubKey?.dispose();
    }

    // Default to BIP-84 (Native SegWit / wpkh) for raw tpub import
    final ext = 'wpkh($tpub/0/*)';
    final internal = 'wpkh($tpub/1/*)';

    // Verify constructed descriptors with BDK
    final extDesc = _parseBdkDescriptor(ext, 'External tpub');
    final intDesc = _parseBdkDescriptor(internal, 'Internal tpub');
    extDesc.dispose();
    intDesc.dispose();

    return ValidatedDescriptorResult(
      externalDescriptor: ext,
      internalDescriptor: internal,
      scriptType: WalletScriptType.nativeSegwit,
    );
  }

  static bdk.Descriptor _parseBdkDescriptor(String descriptorStr, String label) {
    try {
      final desc = bdk.Descriptor(
        descriptor: descriptorStr,
        networkKind: bdk.NetworkKind.test,
      );
      desc.sanityCheck();
      return desc;
    } catch (e) {
      throw DescriptorValidationException(
        '$label descriptor is invalid or unsupported: ${e.toString().replaceAll(RegExp(r'\s+'), ' ')}',
      );
    }
  }

  static WalletScriptType _inferScriptType(bdk.Descriptor descriptor) {
    final typeName = descriptor.descType().name.toLowerCase();
    final str = descriptor.toString().toLowerCase();

    // Explicitly reject unsupported descriptor types fail-closed
    if (str.startsWith('wsh(') ||
        typeName.contains('wsh') ||
        str.contains('multi(') ||
        str.contains('sortedmulti(')) {
      throw const DescriptorValidationException(
        'Multisig and complex Miniscript (wsh) descriptors are currently unsupported. '
        'Root Wallet supports standard single-sig descriptors: pkh, sh(wpkh), wpkh, and tr.',
      );
    }

    if (typeName.contains('bip86') || str.startsWith('tr(')) {
      return WalletScriptType.taproot;
    }
    if (typeName.contains('bip84') || str.startsWith('wpkh(')) {
      return WalletScriptType.nativeSegwit;
    }
    if (typeName.contains('bip49') || str.startsWith('sh(wpkh(')) {
      return WalletScriptType.nestedSegwit;
    }
    if (typeName.contains('bip44') || str.startsWith('pkh(')) {
      return WalletScriptType.legacy;
    }

    throw DescriptorValidationException(
      'Unsupported descriptor script type "${descriptor.descType().name}". '
      'Root Wallet supports standard single-sig descriptors: pkh, sh(wpkh), wpkh, and tr.',
    );
  }

  static String? _extractFingerprint(String descriptor) {
    final match = RegExp(r'\[([0-9a-fA-F]{8})').firstMatch(descriptor);
    return match?.group(1)?.toLowerCase();
  }
}
