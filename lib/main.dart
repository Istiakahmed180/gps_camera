import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:gps_camera/app/app.dart';
import 'package:gps_camera/app/background_services.dart';
import 'package:gps_camera/app/bindings/initial_binding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  InitialBinding().dependencies();
  runApp(const GpsCameraApp());
  await BackgroundServices.start();
}
