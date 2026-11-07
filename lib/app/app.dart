import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/routes/app_pages.dart';
import 'package:gps_camera/app/routes/app_routes.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/features/onboarding/onboarding_gate.dart';
import 'package:gps_camera/app/theme/app_theme.dart';
import 'package:gps_camera/core/constants/app_constants.dart';
import 'package:gps_camera/core/services/theme_service.dart';

/// Shows messages from outside any screen, e.g. after a restart.
final GlobalKey<ScaffoldMessengerState> appMessenger =
    GlobalKey<ScaffoldMessengerState>();

class GpsCameraApp extends StatelessWidget {
  const GpsCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Get.find<ThemeService>();

    return GetMaterialApp(
      scaffoldMessengerKey: appMessenger,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeService.themeMode.value,
      initialRoute: OnboardingGate.isDone(Get.find<StorageService>())
          ? AppPages.initial
          : AppRoutes.onboarding,
      getPages: AppPages.pages,
      defaultTransition: Transition.native,
    );
  }
}
