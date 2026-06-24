import 'package:flutter/services.dart';

class HapticsService {
  HapticsService._();

  /// A quick, light selection tick, ideal for PIN pads and keys.
  static Future<void> lightTick() async {
    await HapticFeedback.selectionClick();
  }

  /// A rhythmic triple pulse to confirm a successful action (e.g. broadcast).
  static Future<void> successPulse() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.mediumImpact();
  }

  /// A heavy warning rumble sequence for errors and lockouts.
  static Future<void> errorRumble() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    await HapticFeedback.heavyImpact();
  }
}
