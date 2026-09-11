import 'package:meta/meta.dart';

/// Supported network transport modes for Bitcoin backend traffic.
enum NetworkTransportMode {
  direct,
  socks5;

  static NetworkTransportMode fromString(String? value) {
    if (value == 'socks5') {
      return NetworkTransportMode.socks5;
    }
    return NetworkTransportMode.direct;
  }

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
/// NOTE: The underlying BDK FFI layer currently exposes unauthenticated
/// SOCKS5 via [bdk.ElectrumClient]. SOCKS5 authentication is reserved for
/// upstream support and is strictly redacted from logs and diagnostics.
@immutable
class Socks5ProxyConfig {
  Socks5ProxyConfig({
    required String host,
    required int port,
    this.username,
    this.password,
  })  : host = _normalizeHost(host),
        port = _validatePort(port) {
    _validateNormalizedHost(this.host);
  }

  final String host;
  final int port;
  final String? username;
  final String? password;

  static String _normalizeHost(String rawHost) {
    var trimmed = rawHost.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Proxy host cannot be empty.');
    }
    // Remove protocol schemes if the user typed them accidentally
    final schemeMatch = RegExp(r'^[a-zA-Z0-9+.-]+:\/\/').firstMatch(trimmed);
    if (schemeMatch != null) {
      trimmed = trimmed.substring(schemeMatch.end);
    }
    // Remove trailing slashes or path
    final slashIndex = trimmed.indexOf('/');
    if (slashIndex != -1) {
      trimmed = trimmed.substring(0, slashIndex);
    }
    // Remove port if user typed host:port in the host box
    final colonIndex = trimmed.lastIndexOf(':');
    if (colonIndex != -1 && !trimmed.contains(']')) {
      // IPv4 or hostname with port
      trimmed = trimmed.substring(0, colonIndex);
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
    // Reject whitespace or invalid characters
    if (RegExp(r'\s').hasMatch(host)) {
      throw const FormatException('Proxy host cannot contain whitespace.');
    }
    // Validate general hostname, IPv4, IPv6, or .onion address
    final validHostPattern = RegExp(
      r'^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z0-9]{2,}$' // FQDN
      r'|^([a-zA-Z0-9_]{1,63})$' // Single-label local name e.g. localhost
      r'|^(\d{1,3}\.){3}\d{1,3}$' // IPv4
      r'|^\[?[a-fA-F0-9:]+\]?$' // IPv6
      r'|^[a-z2-7]{16,56}\.onion$', // Tor v2 / v3 onion address
      caseSensitive: false,
    );
    if (!validHostPattern.hasMatch(host)) {
      throw FormatException('Invalid proxy host format "$host".');
    }
  }

  static int _validatePort(int port) {
    if (port < 1 || port > 65535) {
      throw const FormatException('Proxy port must be between 1 and 65535.');
    }
    return port;
  }

  /// True if the proxy host points to a Tor onion service (.onion).
  bool get isOnion => host.toLowerCase().endsWith('.onion');

  /// Address formatted as `host:port` for passing directly to BDK ElectrumClient.
  String get address => '$host:$port';

  /// Safe, non-secret string representation for UI and diagnostics.
  String get displayAddress => '$host:$port';

  @override
  String toString() {
    return 'Socks5ProxyConfig(host: $host, port: $port, '
        'hasUsername: ${username != null && username!.isNotEmpty}, '
        'hasPassword: ${password != null && password!.isNotEmpty})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Socks5ProxyConfig &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          port == other.port &&
          username == other.username &&
          password == other.password;

  @override
  int get hashCode => Object.hash(host, port, username, password);
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

  /// Returns the SOCKS5 address `host:port` if SOCKS5 transport is active, otherwise null.
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
