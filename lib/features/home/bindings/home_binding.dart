import 'package:get/get.dart';
import 'package:gps_camera/features/home/controllers/home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(HomeController.new);
}
