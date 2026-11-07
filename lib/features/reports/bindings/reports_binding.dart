import 'package:get/get.dart';
import 'package:gps_camera/features/reports/controllers/reports_controller.dart';
import 'package:gps_camera/features/reports/services/report_service.dart';

class ReportsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ReportsController(Get.find<ReportService>()));
  }
}
