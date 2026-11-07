import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/routes/app_pages.dart';
import 'package:gps_camera/app/theme/app_theme.dart';
import 'package:gps_camera/core/constants/app_constants.dart';
import 'package:gps_camera/core/services/theme_service.dart';

class GpsCameraApp extends StatelessWidget {
  const GpsCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Get.find<ThemeService>();

    return GetMaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeService.themeMode.value,
      initialRoute: AppPages.initial,
      getPages: AppPages.pages,
      defaultTransition: Transition.native,
    );
  }
}
