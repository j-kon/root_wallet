import 'package:flutter/material.dart';

/// Official Root Wallet typography definitions based on tokens.json.
abstract final class RootBrandTypography {
  static const brandFamily = 'Inter Display';
  static const uiFamily = 'Inter';

  static const display = TextStyle(
    fontFamily: brandFamily,
    fontSize: 40,
    fontWeight: FontWeight.w600,
    height: 48 / 40,
    letterSpacing: -1.2,
  );

  static const h1 = TextStyle(
    fontFamily: uiFamily,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 40 / 32,
    letterSpacing: -0.9,
  );

  static const h2 = TextStyle(
    fontFamily: uiFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 32 / 24,
    letterSpacing: -0.6,
  );

  static const h3 = TextStyle(
    fontFamily: uiFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 28 / 20,
    letterSpacing: -0.4,
  );

  static const body = TextStyle(
    fontFamily: uiFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
  );

  static const label = TextStyle(
    fontFamily: uiFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
    letterSpacing: 0.1,
  );

  static const caption = TextStyle(
    fontFamily: uiFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
  );

  static const walletAmount = TextStyle(
    fontFamily: uiFamily,
    fontSize: 36,
    fontWeight: FontWeight.w600,
    height: 42 / 36,
    letterSpacing: -1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const wordmark = TextStyle(
    fontFamily: brandFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 3.5,
  );
}
