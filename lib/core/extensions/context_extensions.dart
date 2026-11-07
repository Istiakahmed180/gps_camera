import 'package:flutter/material.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';

extension AppContextX on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;

  TextTheme get text => Theme.of(this).textTheme;

  bool get isCompactWidth =>
      MediaQuery.sizeOf(this).width < AppBreakpoints.compact;
}
