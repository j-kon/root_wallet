import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/layout.dart';

extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;

  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;
  EdgeInsets get viewPadding => MediaQuery.viewPaddingOf(this);

  bool get isCompactWidth => screenWidth < 390;
  bool get isVeryCompactWidth => screenWidth < 360;
  bool get isRegularWidth => screenWidth >= 680;
  bool get isShortHeight => screenHeight < 760;

  double get pageHorizontalPadding =>
      isCompactWidth ? AppSpacing.sm : AppSpacing.md;

  double get pageContentMaxWidth {
    if (screenWidth >= 1120) {
      return 860;
    }
    if (screenWidth >= 720) {
      return 720;
    }
    return screenWidth;
  }

  double get navBarBottomSpacing =>
      (viewPadding.bottom > 0 ? 6 : AppSpacing.xs);

  double get contentBottomSpacing =>
      108 +
      viewPadding.bottom +
      (isShortHeight ? AppSpacing.sm : AppSpacing.md);
}
