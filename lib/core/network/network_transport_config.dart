import 'package:meta/meta.dart';

/// Exception thrown when persisted network transport configuration is invalid or corrupted.
class NetworkConfigurationException implements Exception {
  const NetworkConfigurationException(this.message);

  final String message;

  @override
  String toString() => 'NetworkConfigurationException: $message';
}

/// Supported network transport modes for Bitcoin backend traffic.
enum NetworkTransportMode {
  direct,
  socks5;

  /// Strict persisted parser.
  ///
  /// - `null` (absent key on genuine fresh install) -> [NetworkTransportMode.direct].
  /// - `'direct'` -> [NetworkTransportMode.direct].
  /// - `'socks5'` -> [NetworkTransportMode.socks5].
  /// - Any other string -> throws [NetworkConfigurationException].
  static NetworkTransportMode parsePersisted(String? value) {
    if (value == null) {
      return NetworkTransportMode.direct;
    }
    switch (value) {
      case 'direct':
        return NetworkTransportMode.direct;
      case 'socks5':
        return NetworkTransportMode.socks5;
      default:
        throw NetworkConfigurationException(
          'Invalid persisted transport mode "$value". Expected "direct" or "socks5".',
        );
    }
  }

  /// Backward-compatible strict parser.
  static NetworkTransportMode fromString(String? value) => parsePersisted(value);

  String get storageValue => name;

  String get displayName {
    switch (this) {
      case NetworkTransportMode.direct:
        return 'Direct';
      case NetworkTransportMode.socks5:
        return 'SOCKS5 Proxy';
    }
  }
}

/// Validated SOCKS5 proxy configuration.
///
/// NOTE: The underlying BDK FFI layer exposes address-only SOCKS5 via [bdk.ElectrumClient].
/// Proxy credentials are not supported by the pinned BDK FFI binding and are not collected.
@immutable
class Socks5ProxyConfig {
  Socks5ProxyConfig({
    required String host,
    required int port,
  })  : host = _normalizeHost(host),
        port = _validatePort(port) {
    _validateNormalizedHost(this.host);
  }

  final String host;
  final int port;

  /// True if the host is an IPv6 address.
  bool get isIpv6 => host.contains(':');

  /// Tor v3 .onion regex: exactly 56 base32 characters [a-z2-7] followed by '.onion'.
  static final RegExp _torV3Pattern = RegExp(
    r'^[a-z2-7]{56}\.onion$',
    caseSensitive: false,
  );

  /// Validates whether a target hostname is a valid Tor v3 .onion address.
  static bool isValidTorV3Onion(String targetHost) {
    return _torV3Pattern.hasMatch(targetHost.trim());
  }

  /// Validates an Electrum target endpoint URL (e.g. tcp://host:port or ssl://host:port).
  ///
  /// Delegates to the canonical [ElectrumEndpointValidator].
  static void validateElectrumEndpoint(String url) {
    ElectrumEndpointValidator.validate(url);
  }

  static String _normalizeHost(String rawHost) {
    var trimmed = rawHost.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Proxy host cannot be empty.');
    }
    // Remove protocol schemes if accidentally provided (e.g. socks5://)
    final schemeMatch = RegExp(r'^[a-zA-Z0-9+.-]+:\/\/').firstMatch(trimmed);
    if (schemeMatch != null) {
      trimmed = trimmed.substring(schemeMatch.end);
    }
    // Remove trailing slashes or path
    final slashIndex = trimmed.indexOf('/');
    if (slashIndex != -1) {
      trimmed = trimmed.substring(0, slashIndex);
    }
    // Handle bracketed IPv6 with port e.g. [::1]:9050
    if (trimmed.startsWith('[') && trimmed.contains(']:')) {
      final closingBracket = trimmed.indexOf(']:');
      trimmed = trimmed.substring(0, closingBracket + 1);
    } else if (!trimmed.contains(':')) {
      // Standard hostname or IPv4 without port
    } else if (trimmed.contains(':') && !trimmed.contains('[')) {
      // If there is exactly one colon, it's host:port (e.g. 127.0.0.1:9050)
      final colonCount = ':'.allMatches(trimmed).length;
      if (colonCount == 1) {
        final colonIndex = trimmed.lastIndexOf(':');
        trimmed = trimmed.substring(0, colonIndex);
      }
      // If colonCount > 1, it's an unbracketed IPv6 address (e.g. ::1). Do not strip!
    }
    // Unbracket [::1] to ::1 for normalized host storage
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      trimmed = trimmed.substring(1, trimmed.length - 1);
    }
    return trimmed;
  }

  static void _validateNormalizedHost(String host) {
    if (host.isEmpty) {
      throw const FormatException('Proxy host cannot be empty.');
    }
    if (host.length > 255) {
      throw const FormatException('Proxy host exceeds maximum length of 255 characters.');
    }
    if (RegExp(r'\s').hasMatch(host)) {
      throw const FormatException('Proxy host cannot contain whitespace.');
    }
    if (host.toLowerCase().endsWith('.onion')) {
      throw const FormatException(
        'Proxy host cannot be a .onion address. SOCKS proxy must be a local or network endpoint (e.g. 127.0.0.1 or localhost). Enter .onion addresses in your custom Electrum server configuration.',
      );
    }

    // IPv6 validation
    if (host.contains(':')) {
      try {
        Uri.parseIPv6Address(host);
        return;
      } catch (_) {
        throw FormatException('Invalid IPv6 proxy host "$host".');
      }
    }

    // IPv4 validation
    final ipv4Pattern = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (ipv4Pattern.hasMatch(host)) {
      final parts = host.split('.').map(int.tryParse).toList();
      if (parts.any((p) => p == null || p < 0 || p > 255)) {
        throw FormatException('Invalid IPv4 proxy host "$host".');
      }
      return;
    }

    // FQDN or single-label local hostname (e.g. localhost)
    final fqdnPattern = RegExp(
      r'^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z0-9]{2,}$',
      caseSensitive: false,
    );
    final singleLabelPattern = RegExp(
      r'^[a-zA-Z0-9_]{1,63}$',
      caseSensitive: false,
    );

    if (fqdnPattern.hasMatch(host) || singleLabelPattern.hasMatch(host)) {
      return;
    }

    throw FormatException('Invalid proxy host format "$host".');
  }

  static int _validatePort(int port) {
    if (port < 1 || port > 65535) {
      throw const FormatException('Proxy port must be between 1 and 65535.');
    }
    return port;
  }

  /// Address formatted as `host:port` (or `[host]:port` for IPv6) for passing directly to BDK ElectrumClient.
  String get address => isIpv6 ? '[$host]:$port' : '$host:$port';

  /// Safe string representation for UI and diagnostics.
  String get displayAddress => address;

  @override
  String toString() => 'Socks5ProxyConfig(host: $host, port: $port)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Socks5ProxyConfig &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          port == other.port;

  @override
  int get hashCode => Object.hash(host, port);
}

/// Immutable snapshot of global network transport configuration.
@immutable
class NetworkConfiguration {
  const NetworkConfiguration({
    this.transportMode = NetworkTransportMode.direct,
    this.proxyConfig,
    this.isProxyVerified = false,
    this.lastProxyTestError,
  });

  final NetworkTransportMode transportMode;
  final Socks5ProxyConfig? proxyConfig;
  final bool isProxyVerified;
  final String? lastProxyTestError;

  bool get isSocks5 => transportMode == NetworkTransportMode.socks5;
  bool get isDirect => transportMode == NetworkTransportMode.direct;

  /// Returns the SOCKS5 address `host:port` (or `[host]:port` for IPv6) if SOCKS5 transport is active, otherwise null.
  String? get activeSocks5Address {
    if (!isSocks5 || proxyConfig == null) {
      return null;
    }
    return proxyConfig!.address;
  }

  /// High-level honest status indicator for UI.
  String get statusDescription {
    if (isDirect) {
      return 'Direct connection';
    }
    if (lastProxyTestError != null) {
      return 'SOCKS5 unavailable';
    }
    if (isProxyVerified) {
      return 'SOCKS5 connected';
    }
    return 'SOCKS5 configured';
  }

  NetworkConfiguration copyWith({
    NetworkTransportMode? transportMode,
    Socks5ProxyConfig? proxyConfig,
    bool? isProxyVerified,
    String? lastProxyTestError,
    bool clearProxyTestError = false,
  }) {
    return NetworkConfiguration(
      transportMode: transportMode ?? this.transportMode,
      proxyConfig: proxyConfig ?? this.proxyConfig,
      isProxyVerified: isProxyVerified ?? this.isProxyVerified,
      lastProxyTestError: clearProxyTestError
          ? null
          : (lastProxyTestError ?? this.lastProxyTestError),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkConfiguration &&
          runtimeType == other.runtimeType &&
          transportMode == other.transportMode &&
          proxyConfig == other.proxyConfig &&
          isProxyVerified == other.isProxyVerified &&
          lastProxyTestError == other.lastProxyTestError;

  @override
  int get hashCode => Object.hash(
        transportMode,
        proxyConfig,
        isProxyVerified,
        lastProxyTestError,
      );
}

/// Canonical validator for Electrum endpoints across Root Wallet.
///
/// Enforces:
/// - Non-empty, valid URI format
/// - Allowed schemes: strictly `tcp://` and `ssl://` (no `tls://`, `http://`, etc.)
/// - Valid port between 1 and 65535 (missing port is rejected)
/// - If target host ends with `.onion`, strictly enforces Tor v3 (56 lowercase base32 characters)
///   and rejects Tor v2 (16-char) or malformed onion addresses.
class ElectrumEndpointValidator {
  const ElectrumEndpointValidator._();

  /// Canonical validation and normalization.
  /// Returns the trimmed URL if valid, or throws [FormatException].
  static String validateAndNormalize(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Electrum endpoint cannot be empty.');
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const FormatException(
        'Enter a valid Electrum URL (e.g. tcp://host:port or ssl://host:port).',
      );
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'tcp' && scheme != 'ssl') {
      throw FormatException(
        'Unsupported Electrum scheme "$scheme". Only tcp:// or ssl:// protocols are supported.',
      );
    }
    if (!uri.hasPort || uri.port < 1 || uri.port > 65535) {
      throw const FormatException(
        'Electrum endpoint must specify a valid port (1-65535).',
      );
    }
    if (uri.host.toLowerCase().endsWith('.onion')) {
      if (!Socks5ProxyConfig.isValidTorV3Onion(uri.host)) {
        throw FormatException(
          'Invalid Tor onion endpoint "${uri.host}". Only Tor v3 onion addresses (56 base32 characters) are supported.',
        );
      }
    }
    return trimmed;
  }

  /// Convenience validation method.
  static void validate(String url) => validateAndNormalize(url);
}
