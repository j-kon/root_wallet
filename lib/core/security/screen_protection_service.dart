import 'package:flutter/services.dart';

class ScreenProtectionService {
  const ScreenProtectionService();

  static const _channel = MethodChannel('root_wallet/screen_protection');

  Future<bool> setProtected(bool enabled) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setProtected',
        <String, Object?>{'enabled': enabled},
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
