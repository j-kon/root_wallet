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
