import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:gps_camera/app/app.dart';
import 'package:gps_camera/app/background_services.dart';
import 'package:gps_camera/app/bindings/initial_binding.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/features/onboarding/onboarding_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  // Read before any service runs, so only the user's own settings count.
  final hasSettings = GetStorage().getKeys<Iterable<String>>().isNotEmpty;
  InitialBinding().dependencies();
  await OnboardingGate.skipForExistingUsers(
    Get.find<StorageService>(),
    Get.find<PhotoStorageService>(),
    hasSettings: hasSettings,
  );
  runApp(const GpsCameraApp());
  await BackgroundServices.start();
}
