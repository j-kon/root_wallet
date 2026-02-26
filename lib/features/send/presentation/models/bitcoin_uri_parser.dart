import 'package:root_wallet/features/send/presentation/models/scanned_btc_uri.dart';

class BitcoinUriParser {
  static ScannedBtcUri? parse(String rawValue) {
    final raw = rawValue.trim();
    if (raw.isEmpty) {
      return null;
    }

    if (_isLikelyBitcoinAddress(raw)) {
      return ScannedBtcUri(address: raw);
    }

    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme.toLowerCase() != 'bitcoin') {
      return null;
    }

    final address = uri.path.isNotEmpty ? uri.path : uri.host;
    if (!_isLikelyBitcoinAddress(address)) {
      return null;
    }

    final amountText = uri.queryParameters['amount']?.trim();
    final amount = amountText == null || amountText.isEmpty
        ? null
        : double.tryParse(amountText);
    final normalizedAmount = amount != null && amount > 0 ? amount : null;

    return ScannedBtcUri(address: address, amountBtc: normalizedAmount);
  }

  static bool _isLikelyBitcoinAddress(String candidate) {
    final value = candidate.trim();
    if (value.isEmpty) {
      return false;
    }

    final normalized = value.toLowerCase();
    if (normalized.startsWith('tb1')) {
      return value.length >= 14;
    }

    final legacyPattern = RegExp(r'^[mn2][a-km-zA-HJ-NP-Z1-9]{25,34}$');
    return legacyPattern.hasMatch(value);
  }
}
