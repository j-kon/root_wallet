import 'dart:math';

import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';

enum WalletType {
  signing,
  watchOnly;

  String get displayName => switch (this) {
    WalletType.signing => 'Signing',
    WalletType.watchOnly => 'Watch Only',
  };

  bool get isWatchOnly => this == WalletType.watchOnly;
  bool get isSigning => this == WalletType.signing;

  String get storageValue => name;

  static WalletType fromStorageValue(String? value) {
    if (value == 'watchOnly' || value == 'watch_only') {
      return WalletType.watchOnly;
    }
    return WalletType.signing;
  }
}

/// Explicit, non-secret record representing a wallet managed by Root Wallet.
///
/// Contains ONLY public metadata:
/// - [id]: stable, non-secret identifier (e.g. `w_8f9c1d2e-...`).
/// - [name]: user-friendly display name (e.g. "Main Wallet", "Cold Storage").
/// - [type]: operational capability ([WalletType.signing] vs [WalletType.watchOnly]).
/// - [scriptType]: Bitcoin address script type.
/// - [network]: Bitcoin network name (e.g. "testnet").
/// - [createdAt]: wallet registration timestamp.
/// - [fingerprint]: master key fingerprint or descriptor key origin fingerprint.
/// - [isActive]: convenience flag indicating active status in the registry.
///
/// Private keys, mnemonics, and sensitive descriptor secrets are NEVER stored here.
class WalletRecord {
  const WalletRecord({
    required this.id,
    required this.name,
    required this.type,
    required this.scriptType,
    required this.network,
    required this.createdAt,
    this.fingerprint,
    this.isActive = false,
  });

  final String id;
  final String name;
  final WalletType type;
  final WalletScriptType scriptType;
  final String network;
  final DateTime createdAt;
  final String? fingerprint;
  final bool isActive;

  bool get isWatchOnly => type.isWatchOnly;
  bool get isSigning => type.isSigning;
  bool get hasFingerprint =>
      fingerprint != null && fingerprint!.trim().isNotEmpty;

  /// Validates a user-supplied wallet name (1-32 characters, non-empty trimmed).
  static bool isValidName(String name) =>
      name.trim().isNotEmpty && name.trim().length <= 32;

  /// Generates a cryptographically secure 128-bit random identifier formatted as a UUID.
  static String generateId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    // Set UUID v4 variant & version bits
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'w_${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  WalletRecord copyWith({
    String? id,
    String? name,
    WalletType? type,
    WalletScriptType? scriptType,
    String? network,
    DateTime? createdAt,
    String? fingerprint,
    bool? isActive,
  }) {
    return WalletRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      scriptType: scriptType ?? this.scriptType,
      network: network ?? this.network,
      createdAt: createdAt ?? this.createdAt,
      fingerprint: fingerprint ?? this.fingerprint,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'type': type.storageValue,
      'scriptType': scriptType.storageValue,
      'network': network,
      'createdAt': createdAt.toIso8601String(),
      'fingerprint': fingerprint,
      'isActive': isActive,
    };
  }

  static final RegExp _fingerprintRegex = RegExp(r'^[0-9A-Fa-f]{8}$');

  /// Strict factory for parsing persistent [WalletRegistry] entries.
  ///
  /// Fails closed (throws [FormatException]) on missing/unknown fields,
  /// disallowed types/networks, malformed timestamps, or invalid fingerprints.
  factory WalletRecord.fromRegistryJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Missing or empty wallet "id".');
    }

    final name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Missing or empty wallet "name".');
    }

    final rawType = json['type'];
    if (rawType is! String || rawType.trim().isEmpty) {
      throw const FormatException('Missing or empty wallet "type".');
    }
    final WalletType type;
    switch (rawType.trim()) {
      case 'signing':
        type = WalletType.signing;
        break;
      case 'watchOnly':
      case 'watch_only':
        type = WalletType.watchOnly;
        break;
      default:
        throw FormatException('Unknown or invalid wallet type "$rawType".');
    }

    final rawScript = json['scriptType'];
    if (rawScript is! String || rawScript.trim().isEmpty) {
      throw const FormatException('Missing or empty wallet "scriptType".');
    }
    final WalletScriptType scriptType;
    switch (rawScript.trim()) {
      case 'native_segwit':
      case 'nativeSegwit':
        scriptType = WalletScriptType.nativeSegwit;
        break;
      case 'taproot':
        scriptType = WalletScriptType.taproot;
        break;
      case 'nested_segwit':
      case 'nestedSegwit':
        scriptType = WalletScriptType.nestedSegwit;
        break;
      case 'legacy':
        scriptType = WalletScriptType.legacy;
        break;
      default:
        throw FormatException('Unknown or invalid script type "$rawScript".');
    }

    final network = json['network'];
    if (network is! String || network.trim().isEmpty) {
      throw const FormatException('Missing or empty wallet "network".');
    }
    if (network.trim().toLowerCase() != 'testnet') {
      throw FormatException(
        'Unsupported network "$network" in registry. Only "testnet" is permitted.',
      );
    }

    final rawCreatedAt = json['createdAt'];
    if (rawCreatedAt is! String || rawCreatedAt.trim().isEmpty) {
      throw const FormatException('Missing or empty wallet "createdAt".');
    }
    final createdAt = DateTime.tryParse(rawCreatedAt);
    if (createdAt == null) {
      throw FormatException('Malformed createdAt timestamp "$rawCreatedAt".');
    }

    final rawFingerprint = json['fingerprint'];
    String? fingerprint;
    if (rawFingerprint != null) {
      if (rawFingerprint is! String || rawFingerprint.trim().isEmpty) {
        throw const FormatException('Invalid fingerprint: expected non-empty string.');
      }
      final trimmedFp = rawFingerprint.trim();
      if (!_fingerprintRegex.hasMatch(trimmedFp)) {
        throw FormatException(
          'Invalid fingerprint "$trimmedFp". Expected 8-character hex string.',
        );
      }
      fingerprint = trimmedFp.toUpperCase();
    }

    final isActive = json['isActive'] as bool? ?? false;

    return WalletRecord(
      id: id.trim(),
      name: name.trim(),
      type: type,
      scriptType: scriptType,
      network: network.trim(),
      createdAt: createdAt,
      fingerprint: fingerprint,
      isActive: isActive,
    );
  }

  factory WalletRecord.fromJson(Map<String, dynamic> json) {
    return WalletRecord(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Wallet',
      type: WalletType.fromStorageValue(json['type'] as String?),
      scriptType: WalletScriptType.fromStorageValue(
        json['scriptType'] as String?,
      ),
      network: json['network'] as String? ?? 'testnet',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      fingerprint: json['fingerprint'] != null &&
              (json['fingerprint'] as String).trim().isNotEmpty
          ? (json['fingerprint'] as String).trim().toUpperCase()
          : null,
      isActive: json['isActive'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WalletRecord &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        other.scriptType == scriptType &&
        other.network == network &&
        other.fingerprint == fingerprint &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    scriptType,
    network,
    fingerprint,
    isActive,
  );

  @override
  String toString() =>
      'WalletRecord(id: $id, name: $name, type: ${type.displayName}, script: ${scriptType.displayName}, net: $network, active: $isActive)';
}
