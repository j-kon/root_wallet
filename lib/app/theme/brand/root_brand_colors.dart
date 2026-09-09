import 'package:flutter/material.dart';

/// Official Root Wallet color system.
///
/// RULE: Solid colors only. Gradients, glowing orbs, and glassmorphic blurs
/// are prohibited in Root Wallet product UI.
abstract final class RootBrandColors {
  // Core palette
  static const charcoalPine = Color(0xFF101917);
  static const pineGreen = Color(0xFF2AAE7F);
  static const warmIvory = Color(0xFFF4F5F1);
  static const amberAccent = Color(0xFFE89A22);

  // Extended darks
  static const deepForest = Color(0xFF0C2A25);
  static const nightPine = Color(0xFF0E1F1B);
  static const slatePine = Color(0xFF1F2E2A);
  static const borderPine = Color(0xFF29403A);

  // Supporting
  static const mutedSage = Color(0xFFA7B3AE);
  static const error = Color(0xFFE45555);
  static const pureWhite = Color(0xFFFFFFFF);
  static const pureBlack = Color(0xFF000000);
}
