abstract final class AppFormatters {
  static String maskAddress(String address) {
    if (address.length <= 12) {
      return address;
    }

    final start = address.substring(0, 6);
    final end = address.substring(address.length - 6);
    return '$start...$end';
  }

  static String sats(int value) => '$value sats';

  static String btc(double value) => '${value.toStringAsFixed(8)} BTC';

  static String ngn(double value) => 'NGN ${value.toStringAsFixed(2)}';
}
