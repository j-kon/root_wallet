import 'package:root_wallet/core/constants/app_constants.dart';

abstract final class AppFormatters {
  static String maskAddress(String address) {
    if (address.length <= 12) {
      return address;
    }

    final start = address.substring(0, 6);
    final end = address.substring(address.length - 6);
    return '$start...$end';
  }

  static String sats(int value) => '${_groupInt(value)} sats';

  static String btc(double value) => '${value.toStringAsFixed(8)} BTC';

  static String btcFromSats(int value) =>
      btc(value / AppConstants.satoshisPerBitcoin);

  static String ngn(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    return 'NGN ${_groupIntString(parts[0])}.${parts[1]}';
  }

  static String ngnCompact(double value) {
    final absolute = value.abs();
    final sign = value.isNegative ? '-' : '';

    if (absolute >= 1000000000) {
      return 'NGN $sign${_trimCompact(absolute / 1000000000)}B';
    }
    if (absolute >= 1000000) {
      return 'NGN $sign${_trimCompact(absolute / 1000000)}M';
    }
    if (absolute >= 1000) {
      return 'NGN $sign${_trimCompact(absolute / 1000)}K';
    }
    return ngn(value);
  }

  static String obscuredBtc() => '•••••••• BTC';

  static String obscuredNgn() => 'NGN ••••••';

  static String obscuredSats() => '•••• sats';

  static String _groupInt(int value) => _groupIntString(value.toString());

  static String _groupIntString(String digits) {
    return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  static String _trimCompact(double value) {
    final precision = value >= 100 ? 1 : 2;
    final fixed = value.toStringAsFixed(precision);
    return fixed.endsWith('.00')
        ? fixed.substring(0, fixed.length - 3)
        : fixed.endsWith('0')
        ? fixed.substring(0, fixed.length - 1)
        : fixed;
  }
}
