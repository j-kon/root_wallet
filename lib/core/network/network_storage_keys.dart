/// Centralized keys for network transport configuration and secret storage.
abstract final class NetworkStorageKeys {
  /// Transport mode key in [SharedPreferences] ('direct' or 'socks5').
  static const transportMode = 'settings.network.transport_mode';

  /// SOCKS5 proxy host in [SharedPreferences].
  static const proxyHost = 'settings.network.proxy_host';

  /// SOCKS5 proxy port in [SharedPreferences].
  static const proxyPort = 'settings.network.proxy_port';

  /// Optional SOCKS5 proxy username in [SharedPreferences].
  static const proxyUsername = 'settings.network.proxy_username';

  /// Optional SOCKS5 proxy password in [SecureStorage] ONLY.
  /// NEVER store in SharedPreferences, logs, or diagnostics.
  static const proxyPassword = 'secure.settings.network.proxy_password';

  /// Custom Electrum URL in [SharedPreferences].
  static const customElectrumUrl = 'settings.custom_electrum_url';

  /// Custom Esplora URL in [SharedPreferences].
  static const customEsploraEndpoint = 'settings.custom_esplora_endpoint';
}
